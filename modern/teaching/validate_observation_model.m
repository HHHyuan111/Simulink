function report=validate_observation_model(baseline)
folder=fileparts(mfilename('fullpath'));mdl='PMSM_FOC_R2026a';
if nargin==0,c=load(fullfile(fileparts(folder),'.build','observation_stage','before.mat'),'baseline');baseline=c.baseline;end
fprintf('OBS_TEST_DISABLED\n');in=Simulink.SimulationInput(mdl);in=setModelParameter(in,'StopTime','0.12');off=sim(in);
save(fullfile(fileparts(folder),'.build','observation_stage','disabled_probe.mat'),'off','-v7.3');
comparisonsProbe=struct('name',{},'same_time',{},'same_data',{},'max_error',{});
probeNames=baseline.who;
for k=1:numel(probeNames)
 name=probeNames{k};a=baseline.get(name);if ~isa(a,'timeseries'),continue;end;b=off.get(name);
 comparisonsProbe(end+1)=struct('name',name,'same_time',isequaln(a.Time,b.Time),'same_data',isequaln(a.Data,b.Data),'max_error',max(abs(double(a.Data(:))-double(b.Data(:))))); %#ok<AGROW>
end
teach_writejson(fullfile(fileparts(folder),'.build','observation_stage','disabled_probe.json'),comparisonsProbe);
comparisons=struct('name',{},'samples',{},'identical',{});
baselineNames=baseline.who;
for n=baselineNames(:)'
 name=n{1};old=baseline.get(name);if ~isa(old,'timeseries'),continue;end
 new=off.get(name);assert(isequaln(old.Time,new.Time)&&isequaln(old.Data,new.Data),'Default changed: %s',name);
 comparisons(end+1)=struct('name',name,'samples',numel(old.Time),'identical',true); %#ok<AGROW>
end
fprintf('OBS_DEFAULT_IDENTICAL %d\n',numel(comparisons));
state=teach_values(off.obs_state);assert(max(abs(state(:,1)-teach_values(off.log_id)))<1e-10);
assert(max(abs(state(:,2)-teach_values(off.log_iq)))<1e-10);
mw=get_param(mdl,'ModelWorkspace');dt=getVariable(mw,'dt');T=getVariable(mw,'T');
assert(max(abs(diff(off.obs_gates_fast.Time)-T))<1e-12);
assert(max(abs(diff(off.obs_current_fast.Time)-T))<1e-12);
assert(isequaln(off.obs_phase_ideal.Data,off.obs_phase_actual.Data));

fprintf('OBS_TEST_COMPONENTS\n');
components=struct('name',{},'max_abs_error',{},'passed',{});
x=[1 -2 0.5];N=80;t=(0:N-1)'*dt;
o=component(mdl,'采样设置',t,repmat(x,N,1),{'analog_on','on'});
expected=(1-exp(-2*pi*5000*t))*x;
components(end+1)=check('analog_lowpass_closed_form',teach_values(o.log_iabc_meas),expected,2e-8);
o=component(mdl,'采样设置',t,repmat(x,N,1),{'analog_on','on';'filter_on','on'});
alpha=exp(-2*pi*500*dt);digital=zeros(N,3);
for k=1:N,if k>1,digital(k,:)=alpha*digital(k-1,:);end;digital(k,:)=digital(k,:)+(1-alpha)*expected(k,:);end
components(end+1)=check('analog_then_sample_then_digital',teach_values(o.log_iabc_meas),digital,2e-8);
% Board input-referred quantization; rail midpoint is an explicit assumption.
span=3.3/(2*0.001*20);lsb=2*span/4096;adcInput=repmat([100 -100 0.051],N,1);
o=component(mdl,'采样设置',t,adcInput,{'adc_on','on';'adc_span',num2str(span,17)});
codes=min(4095,max(0,round(adcInput/lsb)+2048));
components(end+1)=check('firmware_adc_scale_and_rails',teach_values(o.log_iabc_meas),(codes-2048)*lsb,1e-12);

currents=repmat([2 -1 -1;-2 1 1;0 0 0;1 2 -3;50 -30 -20],16,1);
variants={{};{'dead_on','on'};{'drop_on','on'};{'dead_on','on';'drop_on','on'}};
for k=1:numel(variants)
 o=component(mdl,'功率设置',t,currents,variants{k});d=double(k==2||k==4);r=double(k>=3);
 % Independent phase-by-phase expectation, then floating-star projection.
 raw=d*0.5e-6/dt*(24+r*0.7)*currents./(abs(currents)+0.1)+r*0.01*currents;
 expected=raw-mean(raw,2);actual=teach_values(o.obs_power_drop);
 components(end+1)=check(sprintf('power_average_case_%d',k),actual,expected,1e-12);
 assert(max(abs(sum(actual,2)))<1e-12);
 loss=sum(actual.*currents,2);assert(min(loss)>-1e-12,'Power error produces energy for zero-sum phase currents.');
end

fprintf('OBS_TEST_CLOSED_LOOP\n');
cfgs={ 'analog_only',{'采样设置','analog_on','on'}; ...
 'deadtime_average',{'功率设置','dead_on','on'}; ...
 'device_drop',{'功率设置','drop_on','on'}; ...
 'firmware_io',{'时序设置','speed_on','on';'时序设置','speed_divider','2';'采样设置','adc_on','on';'采样设置','adc_span','82.5';'功率设置','dead_on','on'}; ...
 'combined_reverse',{'时序设置','speed_on','on';'时序设置','speed_divider','2';'采样设置','analog_on','on';'采样设置','adc_on','on';'采样设置','adc_span','82.5';'功率设置','dead_on','on';'功率设置','drop_on','on'}};
closed=struct('name',{},'speed_final_rpm',{},'peak_iq_A',{},'feedback_error_A',{},'pi_identity_max_error',{},'passed',{});outputs=cell(size(cfgs,1),1);
for k=1:size(cfgs,1)
 input=Simulink.SimulationInput(mdl);input=setModelParameter(input,'StopTime','0.12');cfg=cfgs{k,2};
 for j=1:size(cfg,1),input=setBlockParameter(input,[mdl '/' cfg{j,1}],cfg{j,2},cfg{j,3});end
 if k==5,input=setVariable(input,'n',-1500,'Workspace',mdl);end
 fprintf('OBS_CLOSED %s\n',cfgs{k,1});o=sim(input);outputs{k}=o;
 outputNames=o.who;
 for name=outputNames(:)'
  ts=o.get(name{1});if isa(ts,'timeseries'),assert(all(isfinite(ts.Data(:))),'Nonfinite log: %s',name{1});end
 end
 gates=teach_values(o.obs_gates_fast);assert(all(sum(gates(:,[1 2]),2)==1)&&all(sum(gates(:,[3 4]),2)==1)&&all(sum(gates(:,[5 6]),2)==1));
 a=teach_values(o.log_iabc_meas);theta=teach_values(o.log_theta_meas);
 al=(2*a(:,1)-a(:,2)-a(:,3))/3;be=(a(:,2)-a(:,3))/sqrt(3);
 err=max(abs([teach_values(o.log_id)-(al.*cos(theta)+be.*sin(theta));teach_values(o.log_iq)-(-al.*sin(theta)+be.*cos(theta))]));assert(err<1e-10);
 % Applied voltage follows its logged correction at every fast sample (held each dt).
 tf=o.obs_phase_actual.Time;tc=o.obs_power_drop.Time;drop=teach_values(o.obs_power_drop);
 idx=min(numel(tc),floor(tf/dt+1e-7)+1);expected=teach_values(o.obs_phase_ideal)-drop(idx,:);
 assert(max(abs(expected-teach_values(o.obs_phase_actual)),[],'all')<1e-12);
 piErrors=zeros(1,3);axisIndex=0;
 for axisName={'speed','d','q'}
  p=teach_values(o.get(['obs_pi_' axisName{1}]));assert(size(p,2)==4);
  if strcmp(axisName{1},'speed'),limit=getVariable(mw,'uplimit_w');else,limit=getVariable(mw,'uplimit_iq');end
  assert(max(abs(p(:,4)-min(limit,max(-limit,p(:,3)))))<1e-12);
  piError=max(abs(p(:,3)-p(:,1)-p(:,2)));
  axisIndex=axisIndex+1;piErrors(axisIndex)=piError;
  if piError>=1e-9
   save(fullfile(fileparts(folder),'.build','observation_stage','pi_probe.mat'),'o','p','axisName','piError','-v7.3');
   fprintf('PI_OBSERVATION_IDENTITY %s error=%.12g\n',axisName{1},piError);
  end
  assert(piError<1e-9,'PI observation mismatch exceeds numerical algebraic-loop tolerance.');
 end
 closed(end+1)=struct('name',cfgs{k,1},'speed_final_rpm',double(o.log_speed.Data(end)), ...
  'peak_iq_A',max(abs(double(o.log_iq.Data))),'feedback_error_A',err,'pi_identity_max_error',piErrors,'passed',true); %#ok<AGROW>
end
% Firmware rate check: applied to all actual speed PI discrete elements.
timing=[mdl '/时序设置'];oldOn=get_param(timing,'speed_on');oldDiv=get_param(timing,'speed_divider');
guard=onCleanup(@()set_param(timing,'speed_on',oldOn,'speed_divider',oldDiv));
set_param(timing,'speed_on','on','speed_divider','2');set_param(mdl,'SimulationCommand','update');
feval(mdl,[],[],[],'compile');try
 periods=zeros(1,3);ids={'190','164','438'};
 for k=1:3,st=get_param(Simulink.ID.getHandle([mdl ':' ids{k}]),'CompiledSampleTime');if iscell(st),st=vertcat(st{:});end;rate=unique(st(st(:,1)>0&isfinite(st(:,1)),1));assert(isscalar(rate));periods(k)=rate;end
 assert(max(abs(periods-100e-6))<1e-12);
catch e,feval(mdl,[],[],[],'term');rethrow(e);end
feval(mdl,[],[],[],'term');clear guard;reload(mw);
report=struct('matlab',version,'disabled_comparison',comparisons,'components',components,'closed_loop',closed, ...
 'firmware_speed_periods_s',periods,'fast_log_period_s',T,'control_log_period_s',dt, ...
 'firmware_commit','48d6e86814ac6657b1313b4c92ef24c88f492e07','adc_lsb_A',lsb, ...
 'scope','Default-equivalence, component math, observation wiring and finite 120ms closed loops; average deadtime only, no tuning or hardware validation.', ...
 'all_passed',true);
save(fullfile(folder,'observation_runs.mat'),'off','outputs','report','-v7');
fprintf('OBSERVATION_ALL_PASSED\n');
end

function o=component(mdl,stage,time,data,params)
h='ObservationHarness';if bdIsLoaded(h),close_system(h,0);end;new_system(h);guard=onCleanup(@()close_system(h,0));
mw=get_param(mdl,'ModelWorkspace');hmw=get_param(h,'ModelWorkspace');hmw.DataSource='MATLAB Code';hmw.MATLABCode=mw.MATLABCode;reload(hmw);
assignin(hmw,'obs_input',[time data]);dt=getVariable(mw,'dt');
add_block('simulink/Sources/From Workspace',[h '/Input'],'VariableName','obs_input','SampleTime',num2str(dt,17),'Interpolate','off','OutputAfterFinalValue','Holding final value');
add_block('simulink/Signal Routing/Goto',[h '/Truth'],'GotoTag','Currentabc','TagVisibility','global');
a=get_param([h '/Input'],'PortHandles');b=get_param([h '/Truth'],'PortHandles');add_line(h,a.Outport(1),b.Inport(1));
target=[h '/Stage'];add_block([mdl '/' stage],target);for k=1:size(params,1),set_param(target,params{k,1},params{k,2});end
if strcmp(stage,'功率设置')
 add_block('simulink/Sources/Constant',[h '/Bus'],'Value','24');add_block('simulink/Signal Routing/Goto',[h '/BusTag'],'GotoTag','UDC','TagVisibility','global');
 a=get_param([h '/Bus'],'PortHandles');b=get_param([h '/BusTag'],'PortHandles');add_line(h,a.Outport(1),b.Inport(1));
end
set_param(h,'SolverType','Fixed-step','Solver','ode4','FixedStep','T','StopTime',num2str(time(end),17), ...
 'ReturnWorkspaceOutputs','on','SaveOutput','off','SaveTime','off');o=sim(h);
end
function r=check(name,actual,expected,tol)
assert(isequal(size(actual),size(expected)),'Shape mismatch: %s',name);err=max(abs(actual-expected),[],'all');
assert(err<=tol,'Component %s: %.12g',name,err);r=struct('name',name,'max_abs_error',err,'passed',true);fprintf('PASS %s %.3g\n',name,err);
end
