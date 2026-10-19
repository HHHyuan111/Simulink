function report = compare_sensorless_modules(label, baselineLabel)
% Physical trajectory regression after an equation-preserving implementation change.
if nargin<2,baselineLabel='final_a';end
base=fileparts(fileparts(mfilename('fullpath')));
folder=fullfile(base,'runs',['SMO_closed_' label]);
baseline=fullfile(base,'runs',['SMO_closed_' baselineLabel]);
a=load(fullfile(baseline,'signals.mat'));b=load(fullfile(folder,'signals.mat'));
limits=jsondecode(fileread(fullfile(base,'closed_loop','modules_acceptance.json')));
current=jsondecode(fileread(fullfile(folder,'report.json')));
report=struct('baseline',baselineLabel,'candidate',label,'same_log_names',isequal(fieldnames(a),fieldnames(b)), ...
    'log_count',numel(fieldnames(b)),'candidate_acceptance_passed',current.passed,'logs',struct,'passed',false);
names=fieldnames(a);allPassed=report.same_log_names&&report.log_count==limits.closed_loop.log_count;
for k=1:numel(names)
    name=names{k};x=a.(name);y=b.(name);u=teach_values(x);v=teach_values(y);
    item=struct('time_equal',isequal(x.Time,y.Time),'dimensions_equal',isequal(size(x.Data),size(y.Data)), ...
        'exact',isequal(x.Data,y.Data),'max_abs_difference',0,'passed',false,'criterion','');
    if ~isequal(size(u),size(v)),item.criterion='shape mismatch';report.logs.(name)=item;allPassed=false;continue;end
    delta=abs(u-v);tol=limits.closed_loop.other_numeric_absolute_tolerance+limits.closed_loop.other_numeric_relative_tolerance*abs(u);
    item.criterion='absolute + relative';
    if contains(name,{'_theta','_truth_theta'}) && ~contains(name,'phase_guard')
        delta=abs(atan2(sin(u-v),cos(u-v)));tol=limits.closed_loop.angle_difference_max_electrical_deg*pi/180;
        item.criterion='wrapped electrical angle [rad]';
    elseif contains(name,{'_current_ABC','_input_i','_i_hat','_i_residual','_iabc','_id_ref','_iq_ref'})
        tol=limits.closed_loop.current_difference_max_A;item.criterion='current [A]';
    elseif contains(name,{'_speed','_truth_speed'}) && ~contains(name,'pi')
        tol=limits.closed_loop.speed_difference_max_rpm;item.criterion='mechanical speed [rpm]';
    elseif contains(name,'omega')
        tol=limits.closed_loop.speed_difference_max_rpm*5*2*pi/60;item.criterion='electrical speed [rad/s]';
    elseif contains(name,{'_input_v','_injection','_emf'}) && ~contains(name,'front')
        tol=limits.closed_loop.voltage_difference_max_V;item.criterion='voltage [V]';
    end
    if islogical(x.Data)||contains(name,{'_stage','_state','_valid','_reset','_saturated','_permit','_deny_reason'})
        tol=0;item.criterion='exact discrete state';
    end
    item.max_abs_difference=max(delta,[],'all');
    item.passed=item.time_equal&&item.dimensions_equal&&all(isfinite(v),'all')&&all(delta<=tol,'all');
    report.logs.(name)=item;allPassed=allPassed&&item.passed;
end
before=jsondecode(fileread(fullfile(baseline,'metrics.json')));after=jsondecode(fileread(fullfile(folder,'metrics.json')));
report.handover_difference_s=abs(before.takeover_complete_s-after.takeover_complete_s);
report.passed=allPassed&&report.candidate_acceptance_passed&&report.handover_difference_s<=limits.closed_loop.handover_time_difference_max_s;
teach_writejson(fullfile(folder,'modules_comparison.json'),report);
assert(report.passed,'sensorless:PhysicalRegression','Module version differs beyond the predefined limits.');
end
