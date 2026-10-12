function report=validate_speed_loop_stage1
% Independent speed-PI recurrence and executable sample-rate checks.
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);mdl='PMSM_FOC_R2026a';
load_system(fullfile(root,[mdl '.slx']));mw=get_param(mdl,'ModelWorkspace');
assert(strcmp(get_param(Simulink.ID.getHandle([mdl ':216']),'Value'),'Ld-Lq'));
kp=getVariable(mw,'kp_w');ki=getVariable(mw,'ki_w');ks=getVariable(mw,'ks_w');
upper=getVariable(mw,'uplimit_w');lower=getVariable(mw,'downlimit_w');
step=getVariable(mw,'Ts_speed');dt=getVariable(mw,'dt');
assert(abs(kp-getVariable(mw,'J')*getVariable(mw,'wsc')/(30/pi))<1e-14);
assert(abs(step-dt)<1e-14,'Default speed period should preserve the published execution rate.');
rates=[step 2*step];cases=struct('name',{},'sample_time_s',{},'samples',{},'maximum_error_Nm',{},'maximum_integral_error_Nm',{},'passed',{});
for rate=rates
 e={zeros(81,1),ones(81,1)*10,ones(81,1)*3000,ones(81,1)*-3000, ...
    [ones(40,1)*3000;ones(40,1)*-3000;zeros(81,1)]};
 names={'zero','linear_constant','positive_saturation','negative_saturation','saturation_reversal'};
 for k=1:numel(e)
  [y,xi]=runHarness(mdl,mw,e{k},rate);
  [expected,expectedIntegral]=referencePI(e{k},kp,ki,ks,rate,lower,upper);
  err=max(abs(y-expected));integralError=max(abs(xi-expectedIntegral));passed=max(err,integralError)<2e-8;
  assert(passed,'PI recurrence mismatch (%s, period %.9g): %.9g',names{k},rate,err);
  cases(end+1)=struct('name',names{k},'sample_time_s',rate,'samples',numel(e{k}), ...
   'maximum_error_Nm',err,'maximum_integral_error_Nm',integralError,'passed',passed); %#ok<AGROW>
 end
end
% Check actual compiled rates, including a non-default period, without saving it.
original=getVariable(mw,'Ts_speed');cleanup=onCleanup(@()assignin(mw,'Ts_speed',original));
compiled=struct('period_s',{},'feedback_period_s',{},'proportional_period_s',{},'integrator_period_s',{});
for rate=rates
 assignin(mw,'Ts_speed',rate);
 set_param(mdl,'SimulationCommand','update');
 feval(mdl,[],[],[],'compile');
 try
  st=cell(1,3);ids={'190','164','438'};
  for j=1:3
   st{j}=get_param(Simulink.ID.getHandle([mdl ':' ids{j}]),'CompiledSampleTime');
   % A ZOH can report both its continuous input and discrete output rates.
   if iscell(st{j}),st{j}=vertcat(st{j}{:});end
   assert(isnumeric(st{j})&&size(st{j},2)==2,'Unexpected sample-time metadata.');
   discrete=unique(st{j}(isfinite(st{j}(:,1))&st{j}(:,1)>0,1));
   assert(isscalar(discrete),'Expected one discrete execution period per block.');
   st{j}=[discrete 0];
  end
  fprintf('SPEED_COMPILED_RATE %.9g: %s\n',rate,jsonencode(st));
  assert(all(cellfun(@(x)isnumeric(x)&&~isempty(x)&&abs(x(1)-rate)<1e-12,st)),'Compiled rate does not follow Ts_speed.');
 catch err
  feval(mdl,[],[],[],'term');rethrow(err);
 end
 feval(mdl,[],[],[],'term');
 compiled(end+1)=struct('period_s',rate,'feedback_period_s',st{1}(1), ...
   'proportional_period_s',st{2}(1),'integrator_period_s',st{3}(1)); %#ok<AGROW>
end
assignin(mw,'Ts_speed',original);clear cleanup;
% Exercise the actual torque-conversion block expression with saliency and nonzero id.
oldLd=getVariable(mw,'Ld');oldLq=getVariable(mw,'Lq');
cleanup=onCleanup(@()restoreInductance(mw,oldLd,oldLq));
assignin(mw,'Ld',2e-4);assignin(mw,'Lq',1e-4);
delta=evalin(mw,get_param(Simulink.ID.getHandle([mdl ':216']),'Value'));
polePairs=getVariable(mw,'p');flux=getVariable(mw,'phis');
ids=[-5 0 5];iq=3;torque=1.5*polePairs*(flux+delta*ids)*iq;
expected=1.5*polePairs*(flux+(2e-4-1e-4)*ids)*iq;
assert(max(abs(torque-expected))<1e-14&&max(abs(torque./(1.5*polePairs*(flux+delta*ids))-iq))<1e-12);
restoreInductance(mw,oldLd,oldLq);clear cleanup;
report=struct('pi_cases',cases,'compiled_rates',compiled,'torque_conversion_nonzero_id_passed',true,'all_passed',true);
fprintf('SPEED_COMPONENT_CHECKS_PASSED %d PI cases\n',numel(cases));
end
function restoreInductance(mw,ld,lq)
assignin(mw,'Ld',ld);assignin(mw,'Lq',lq);
end
function [y,xi]=runHarness(mdl,mw,errorVector,period)
harness='speed_pi_stage1_test';if bdIsLoaded(harness),close_system(harness,0);end
new_system(harness);cleanup=onCleanup(@()close_system(harness,0));
hmw=get_param(harness,'ModelWorkspace');hmw.DataSource='MATLAB Code';hmw.MATLABCode=mw.MATLABCode;reload(hmw);
assignin(hmw,'Ts_speed',period);
time=(0:numel(errorVector)-1)'*period;assignin(hmw,'speed_test_error',[time errorVector]);
add_block('simulink/Sources/From Workspace',[harness '/Error'],'VariableName','speed_test_error', ...
 'SampleTime',num2str(period,17),'Interpolate','off','OutputAfterFinalValue','Holding final value');
add_block(getfullname(Simulink.ID.getHandle([mdl ':155'])),[harness '/PI']);
integrator=find_system([harness '/PI'],'LookUnderMasks','all','BlockType','DiscreteIntegrator');
ports=get_param(integrator{1},'PortHandles');
set_param(ports.Outport(1),'DataLogging','on','DataLoggingNameMode','Custom','DataLoggingName','test_integral');
add_block('simulink/Sinks/To Workspace',[harness '/Output'],'VariableName','pi_output','SaveFormat','Timeseries');
add_line(harness,'Error/1','PI/1');add_line(harness,'PI/1','Output/1');
set_param(harness,'SolverType','Fixed-step','Solver','FixedStepDiscrete','FixedStep',num2str(period,17), ...
 'StopTime',num2str(time(end),17),'ReturnWorkspaceOutputs','on','SignalLogging','on', ...
 'AlgebraicLoopMsg',get_param(mdl,'AlgebraicLoopMsg'));
out=sim(harness);ts=out.pi_output;assert(numel(ts.Time)==numel(errorVector));y=double(ts.Data(:));
ts=out.logsout.getElement('test_integral').Values;assert(numel(ts.Time)==numel(errorVector));xi=double(ts.Data(:));
end
function [y,xi]=referencePI(e,kp,ki,ks,h,lo,hi)
% Solve the implicit backward-Euler equation with both existing clamps.
% At t=0, InitialConditionSetting=Output fixes the integral output at zero.
y=zeros(size(e));xi=zeros(size(e));x=0;y(1)=clip(kp*e(1),lo,hi);
for k=2:numel(e)
 left=lo;right=hi;
 for j=1:80
  candidate=(left+right)/2;u=kp*e(k)+candidate;
  residual=candidate-clip(x+h*ki*(e(k)-ks*(u-clip(u,lo,hi))),lo,hi);
  if residual>0,right=candidate;else,left=candidate;end
 end
 x=(left+right)/2;xi(k)=x;y(k)=clip(kp*e(k)+x,lo,hi);
end
end
function x=clip(x,lo,hi)
x=min(max(x,lo),hi);
end
