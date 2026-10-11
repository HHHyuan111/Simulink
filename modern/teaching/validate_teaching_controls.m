function report=validate_teaching_controls(baseline)
% Validate actual blocks against independent physical / timing expectations.
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);mdl='PMSM_FOC_R2026a';
if ~bdIsLoaded(mdl),load_system(fullfile(root,[mdl '.slx']));end
if nargin==0
 cache=fullfile(root,'.build','teaching_stage1','before.mat');
 if isfile(cache),data=load(cache,'baseline');baseline=data.baseline;else,baseline=[];end
end
report=struct('matlab',version,'baseline_available',~isempty(baseline));
fprintf('TEACH_TEST_DEFAULT_OFF\n');
in=Simulink.SimulationInput(mdl);in=setModelParameter(in,'StopTime','0.12');off=sim(in);
signals=struct('name',{},'samples',{},'max_abs_error',{},'identical',{});
if ~isempty(baseline)
 names=baseline.who;
 for index=1:numel(names)
  name=names{index};old=baseline.get(name);if ~isa(old,'timeseries'),continue;end
  new=off.get(name);same=isequaln(old.Time,new.Time)&&isequaln(old.Data,new.Data);
  assert(same,'Disabled effects changed original signal: %s',name);
  signals(end+1)=struct('name',name,'samples',numel(old.Time),'max_abs_error',0,'identical',same); %#ok<AGROW>
 end
 assert(numel(signals)==12);
end
report.disabled_comparison=signals;
fprintf('TEACH_TEST_COMPONENTS\n');
mw=get_param(mdl,'ModelWorkspace');dt=getVariable(mw,'dt');N=800;
t=(0:N-1)'*dt;
x=[3*sin(2*pi*137*t)+0.173, 2*cos(2*pi*193*t)-0.231, -sin(2*pi*89*t)+0.347];
cases=struct('name',{},'samples',{},'max_abs_error',{},'passed',{});

o=harness(mdl,'采样设置',t,x,{},{});cases(end+1)=check('current_bypass',o.log_iabc_meas.Data,x,0);
bias=[0.05 -0.03 0];
o=harness(mdl,'采样设置',t,x,{'bias_on','on'},{});
cases(end+1)=check('current_offset_A',o.log_iabc_meas.Data,x+bias,1e-13);
g=[1.01 0.99 1];
o=harness(mdl,'采样设置',t,x,{'gain_on','on'},{});
cases(end+1)=check('phase_gain',o.log_iabc_meas.Data,x.*g,1e-13);

span=20;bits=12;lsb=2*span/2^bits;
xq=x*20;codes=min(2^bits-1,max(0,round(xq/lsb)+2^(bits-1)));
o=harness(mdl,'采样设置',t,xq,{'adc_on','on'},{});
cases(end+1)=check('adc_codes_and_clipping',o.log_iabc_meas.Data,(codes-2^(bits-1))*lsb,1e-12);
assert(any(codes(:)==0)&&any(codes(:)==2^bits-1));

step=repmat([1 -2 0.5],N,1);fc=500;
o=harness(mdl,'采样设置',t,step,{'filter_on','on'},{});
expected=(1-exp(-2*pi*fc*dt*(1:N)'))*[1 -2 0.5];
cases(end+1)=check('digital_filter_step_response',o.log_iabc_meas.Data,expected,1e-12);

o=harness(mdl,'采样设置',t,x,{'delay_on','on';'delay_cycles','3'},{});
cases(end+1)=check('adc_delivery_3_cycles',o.log_iabc_meas.Data,[zeros(3,3);x(1:end-3,:)],1e-13);

noise1=harness(mdl,'采样设置',t,x,{'noise_on','on'},{});
noise2=harness(mdl,'采样设置',t,x,{'noise_on','on'},{});
cases(end+1)=check('noise_seed_repeatability',noise1.log_iabc_noise.Data,noise2.log_iabc_noise.Data,0);
cases(end+1)=check('noise_injected_into_measurement',noise1.log_iabc_meas.Data-x,noise1.log_iabc_noise.Data,1e-12);
nr=sqrt(mean(double(noise1.log_iabc_noise.Data).^2,1));
assert(all(nr>0.017&nr<0.023),'Noise RMS outside a conservative finite-record interval.');
report.noise_rms_A=nr;
noise3=harness(mdl,'采样设置',t,x,{'noise_on','on';'noise_seed','9475'},{});
assert(~isequaln(noise1.log_iabc_noise.Data,noise3.log_iabc_noise.Data),'Different seed produced identical noise.');

theta=mod(0.37+(0:N-1)'*0.17,2*pi);
o=harness(mdl,'角度设置',t,theta,{},{});cases(end+1)=check('angle_bypass',o.log_theta_meas.Data,theta,0);
o=harness(mdl,'角度设置',t,theta,{'bias_on','on'},{});
cases(end+1)=check('angle_bias_electrical_deg',o.log_theta_meas.Data,mod(theta+2*pi/180,2*pi),1e-12);
delta=0.1*pi/180;
o=harness(mdl,'角度设置',t,theta,{'quant_on','on'},{});
cases(end+1)=check('angle_quantization_and_wrap',o.log_theta_meas.Data,mod(round(theta/delta)*delta,2*pi),1e-12);
o=harness(mdl,'角度设置',t,theta,{'delay_on','on';'delay_cycles','2'},{});
cases(end+1)=check('angle_delivery_2_cycles',o.log_theta_meas.Data,[zeros(2,1);theta(1:end-2)],1e-12);

thresholds=dt/4+(dt/8)*[sin(2*pi*137*t),cos(2*pi*193*t),sin(2*pi*89*t)];
o=harness(mdl,'输出延迟',t,thresholds,{}, {'teach_pwm_on',0;'teach_pwm_cycles',2});
cases(end+1)=check('pwm_delay_bypass',o.log_Tcm_applied.Data,thresholds,0);
o=harness(mdl,'输出延迟',t,thresholds,{}, {'teach_pwm_on',1;'teach_pwm_cycles',2});
cases(end+1)=check('pwm_delivery_2_cycles',o.log_Tcm_applied.Data,[zeros(2,3);thresholds(1:end-2,:)],1e-13);
report.components=cases;

fprintf('TEACH_TEST_CLOSED_LOOP\n');
specs={ 'speed_divider_20',{'时序设置','speed_on','on';'时序设置','speed_divider','20'}; ...
 'pwm_delay_1_cycle',{'时序设置','pwm_on','on'}; ...
 'measured_feedback',{'采样设置','noise_on','on';'采样设置','adc_on','on';'角度设置','bias_on','on';'角度设置','quant_on','on'}};
closed=struct('name',{},'speed_final_rpm',{},'speed_peak_rpm',{},'iq_peak_A',{},'feedback_error_A',{},'passed',{});
outs=cell(1,size(specs,1));
for k=1:size(specs,1)
 input=Simulink.SimulationInput(mdl);input=setModelParameter(input,'StopTime','0.12');cfg=specs{k,2};
 for j=1:size(cfg,1),input=setBlockParameter(input,[mdl '/' cfg{j,1}],cfg{j,2},cfg{j,3});end
 outs{k}=sim(input);o=outs{k};
 assert(all(isfinite([o.log_speed.Data(:);o.log_id.Data(:);o.log_iq.Data(:);o.log_Tcm.Data(:)])));
 gates=reshape(double(o.log_SW.Data),[],6);
 assert(all(gates(:,1)+gates(:,2)==1&gates(:,3)+gates(:,4)==1&gates(:,5)+gates(:,6)==1));
 assert(all(o.log_Tcm.Data(:)>=-1e-12&o.log_Tcm.Data(:)<=dt/2+1e-12));
 err=feedbackError(o);assert(err<1e-10,'Controller used a different current/angle path from its logged measurements.');
 closed(end+1)=struct('name',specs{k,1},'speed_final_rpm',double(o.log_speed.Data(end)), ...
  'speed_peak_rpm',max(double(o.log_speed.Data)),'iq_peak_A',max(abs(double(o.log_iq.Data))), ...
  'feedback_error_A',err,'passed',true); %#ok<AGROW>
end
assertCloseDelayed(outs{2}.log_Tcm_requested,outs{2}.log_Tcm_applied,1);
report.closed_loop=closed;

% Inspect actual compiled execution periods, not only parameter strings.
timing=[mdl '/时序设置'];old=get_param(timing,'speed_on');set_param(timing,'speed_on','on');
cleanup=onCleanup(@()set_param(timing,'speed_on',old));
set_param(mdl,'SimulationCommand','update');feval(mdl,[],[],[],'compile');
try
 periods=zeros(1,3);ids={'190','438','164'};
 for j=1:3
  st=get_param(Simulink.ID.getHandle([mdl ':' ids{j}]),'CompiledSampleTime');
  if iscell(st),st=vertcat(st{:});end
  rate=unique(st(isfinite(st(:,1))&st(:,1)>0,1));assert(isscalar(rate));periods(j)=rate;
 end
 assert(all(abs(periods-20*dt)<1e-12));
catch err
 feval(mdl,[],[],[],'term');rethrow(err);
end
feval(mdl,[],[],[],'term');clear cleanup;
report.speed_periods_with_divider20_s=periods;
set_param(mdl,'SimulationCommand','update');
unresolved=find_system(mdl,'LookUnderMasks','all','FollowLinks','off','LinkStatus','unresolved');assert(isempty(unresolved));
report.unresolved_links=0;
report.all_passed=all([cases.passed])&&all([closed.passed]);
report.scope='Component semantics and finite 120 ms closed-loop runs; no tuning or hardware validation.';
makePlot(off,outs,folder);
save(fullfile(folder,'teaching_runs.mat'),'off','outs','-v7');
teach_writejson(fullfile(folder,'teaching_validation.json'),report);
fprintf('TEACHING_ALL_PASSED\n');
end

function out=harness(mdl,stage,time,data,params,variables)
h='TeachingComponentHarness';if bdIsLoaded(h),close_system(h,0);end
new_system(h);guard=onCleanup(@()close_system(h,0));
mw=get_param(mdl,'ModelWorkspace');hmw=get_param(h,'ModelWorkspace');
hmw.DataSource='MATLAB Code';hmw.MATLABCode=mw.MATLABCode;reload(hmw);
assignin(hmw,'teaching_input',[time data]);
dt=getVariable(mw,'dt');
add_block('simulink/Sources/From Workspace',[h '/Input'],'VariableName','teaching_input', ...
 'SampleTime',num2str(dt,17),'Interpolate','off','OutputAfterFinalValue','Holding final value');
target=[h '/Stage'];add_block([mdl '/' stage],target);
for k=1:size(params,1),set_param(target,params{k,1},params{k,2});end
if strcmp(stage,'输出延迟')
 ph=get_param([h '/Input'],'PortHandles');dest=get_param(target,'PortHandles');add_line(h,ph.Outport(1),dest.Inport(1));
 add_block('simulink/Sinks/Terminator',[h '/Unused']);p=get_param([h '/Unused'],'PortHandles');add_line(h,dest.Outport(1),p.Inport(1));
else
 tag='Currentabc';if strcmp(stage,'角度设置'),tag='theta_e';end
 add_block('simulink/Signal Routing/Goto',[h '/Truth'],'GotoTag',tag,'TagVisibility','global');
 ph=get_param([h '/Input'],'PortHandles');dest=get_param([h '/Truth'],'PortHandles');add_line(h,ph.Outport(1),dest.Inport(1));
end
for k=1:size(variables,1),assignin(hmw,variables{k,1},variables{k,2});end
set_param(h,'SolverType','Fixed-step','Solver','FixedStepDiscrete','FixedStep',num2str(dt,17), ...
 'StopTime',num2str(time(end),17),'ReturnWorkspaceOutputs','on','SaveOutput','off','SaveTime','off');
out=sim(h);
end
function r=check(name,actual,expected,tol)
assert(isequal(size(actual),size(expected)),'Shape mismatch: %s',name);
err=max(abs(double(actual(:))-double(expected(:))));assert(err<=tol,'Failed %s: error %.12g',name,err);
r=struct('name',name,'samples',size(actual,1),'max_abs_error',err,'passed',true);
fprintf('PASS %s %.3g\n',name,err);
end
function err=feedbackError(o)
i=double(o.log_iabc_meas.Data);theta=double(o.log_theta_meas.Data);
alpha=(2*i(:,1)-i(:,2)-i(:,3))/3;beta=(i(:,2)-i(:,3))/sqrt(3);
id=alpha.*cos(theta)+beta.*sin(theta);iq=-alpha.*sin(theta)+beta.*cos(theta);
err=max(abs([double(o.log_id.Data(:))-id;double(o.log_iq.Data(:))-iq]));
end
function assertCloseDelayed(raw,applied,n)
a=teach_values(raw);b=teach_values(applied);expected=[zeros(n,size(a,2));a(1:end-n,:)];
assert(max(abs(b(:)-expected(:)))<1e-12,'Closed-loop applied PWM thresholds do not match the configured cycle delay.');
end
function makePlot(base,outs,folder)
f=figure('Visible','off','Color','white','Position',[50 50 1300 850]);tiledlayout(2,2,'TileSpacing','compact');
nexttile;plot(base.log_speed.Time,base.log_speed.Data,outs{1}.log_speed.Time,outs{1}.log_speed.Data);grid on;
xlabel('Time (s)');ylabel('Speed (rpm)');title('Execution rate only; PI gains unchanged');legend('50 us reference','1 ms speed task');
nexttile;plot(base.log_iq.Time,base.log_iq.Data,outs{2}.log_iq.Time,outs{2}.log_iq.Data);grid on;
xlabel('Time (s)');ylabel('Measured iq (A)');title('Lumped output delay');legend('No added delay','One 50 us cycle');
nexttile;o=outs{3};plot(o.log_iabc_true.Time,o.log_iabc_true.Data(:,1),o.log_iabc_meas.Time,o.log_iabc_meas.Data(:,1));
xlim([0.08 0.09]);grid on;xlabel('Time (s)');ylabel('Phase A current (A)');title('Truth and measurement');legend('True','Noise + ADC');
nexttile;plot(o.log_theta_error.Time,o.log_theta_error.Data*180/pi);grid on;
xlabel('Time (s)');ylabel('Electrical angle error (deg)');title('2 deg bias + 0.1 deg quantization');
sgtitle('Teaching controls stage 1 / Demonstration parameters / No tuning');
exportgraphics(f,fullfile(folder,'teaching_comparison.png'),'Resolution',130);close(f);
end
