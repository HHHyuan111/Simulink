function report = compare_native_smo(label)
base=fileparts(fileparts(mfilename('fullpath')));folder=fullfile(base,'runs',['SMO_closed_' label]);
a=load(fullfile(base,'runs','SMO_closed_final_a','signals.mat'));b=load(fullfile(folder,'signals.mat'));
c=jsondecode(fileread(fullfile(base,'closed_loop','native_smo_acceptance.json')));
run=jsondecode(fileread(fullfile(folder,'report.json')));names=fieldnames(a);
report=struct('passed',run.passed,'same_log_names',isequal(names,fieldnames(b)),'log_count',numel(names),'logs',struct);
report.passed=report.passed&&report.same_log_names&&numel(names)==c.log_count;
for k=1:numel(names)
    key=names{k};x=a.(key);y=b.(key);u=teach_values(x);v=teach_values(y);delta=abs(u-v);
    tolerance=c.numeric_absolute_tolerance+c.numeric_relative_tolerance*abs(u);
    if islogical(x.Data)||contains(key,{'_stage','_state','_valid','_reset','_saturated','_permit','_deny_reason'}),tolerance=0;end
    r=struct('time_equal',isequal(x.Time,y.Time),'dimensions_equal',isequal(size(x.Data),size(y.Data)), ...
        'exact',isequal(x.Data,y.Data),'max_abs_difference',max(delta,[],'all'),'passed',false);
    r.passed=r.time_equal&&r.dimensions_equal&&all(isfinite(v),'all')&&all(delta<=tolerance,'all');
    report.logs.(key)=r;report.passed=report.passed&&r.passed;
end
teach_writejson(fullfile(folder,'native_smo_comparison.json'),report);
assert(report.passed,'sensorless:NativeSMORegression','Native SMO closed-loop regression failed.');
end
