function o=run_deadtime_case(mdl,deadUs,compOn,stopTime,gridDivider,options)
% Identical steady-state initialization, gains, timing and load in each case.
if nargin<5,gridDivider=1;end
if nargin<6,options=struct;end
if ~isfield(options,'rpm'),options.rpm=600;end
if ~isfield(options,'load_Nm'),options.load_Nm=.207;end
if ~isfield(options,'comp_us'),options.comp_us=deadUs;end
mw=get_param(mdl,'ModelWorkspace');Kt=getVariable(mw,'Kt');Rs=getVariable(mw,'Rs');loadTorque=options.load_Nm;iq=loadTorque/Kt;
in=Simulink.SimulationInput(mdl);in=in.setModelParameter('StopTime',num2str(stopTime,12));
in=in.setVariable('n',options.rpm,'Workspace',mdl);
in=in.setBlockParameter([mdl '/解耦'],'enabled','on');
loadBlock=find_system(mdl,'SearchDepth',1,'BlockType','Step','Name','T_load1');assert(isscalar(loadBlock));
for param={'Before','After'},in=in.setBlockParameter(loadBlock{1},param{1},num2str(loadTorque,17));end
in=in.setBlockParameter(loadBlock{1},'Time','0');
settings=teach_settings(mdl);
for s=settings,for q=s.parameters,if endsWith(q.name,'_on'),in=in.setBlockParameter([mdl '/' s.block],q.name,'off');end,end,end
in=in.setBlockParameter([mdl '/时序设置'],'real_on','on');
in=in.setBlockParameter([mdl '/时序设置'],'grid_divider',num2str(gridDivider));
in=in.setBlockParameter([mdl '/功率设置'],'gate_on','on');
in=in.setBlockParameter([mdl '/功率设置'],'gate_us',num2str(deadUs,12));
in=in.setBlockParameter([mdl '/功率设置'],'comp_on',compOn);
in=in.setBlockParameter([mdl '/功率设置'],'comp_us',num2str(options.comp_us,12));
if isfield(options,'hysteresis_A')
 in=in.setBlockParameter([mdl '/功率设置'],'hysteresis_A',num2str(options.hysteresis_A,12));
end
if isfield(options,'aligned_current_logs') && options.aligned_current_logs
 % Observation only: record the current available on the compensation task.
 for var={'log_iabc_meas','log_iabc_true'}
  b=find_system(mdl,'LookUnderMasks','all','FollowLinks','off','BlockType','ToWorkspace','VariableName',var{1});
  assert(isscalar(b));in=in.setBlockParameter(b{1},'SampleTime','timing_control_sample');
 end
end
motor=getfullname(Simulink.ID.getHandle([mdl ':626']));
in=in.setBlockParameter([motor '/id_iq_wm_theta'],'InitialCondition',mat2str([0;iq;options.rpm*pi/30;0],17));
speed=getfullname(Simulink.ID.getHandle([mdl ':155']));q=getfullname(Simulink.ID.getHandle([mdl ':453']));
in=in.setBlockParameter([speed '/' sprintf('Discrete-Time\nIntegrator')],'InitialCondition',num2str(loadTorque,17));
in=in.setBlockParameter([q '/' sprintf('Discrete-Time\nIntegrator')],'InitialCondition',num2str(Rs*iq,17));
% Keep complete control and 1us physical logs, but only a short tail of
% 62.5ns event/gate diagnostics for edge inspection and manageable memory.
for name={'obs_adc_timing','obs_pwm_timing','obs_dead_gates','obs_dead_requested','obs_dead_bridge'}
 b=find_system(mdl,'LookUnderMasks','all','FollowLinks','off','BlockType','ToWorkspace','VariableName',name{1});
 assert(isscalar(b));in=in.setBlockParameter(b{1},'MaxDataPoints','4000');
 if strcmp(name{1},'obs_dead_bridge'),in=in.setBlockParameter(b{1},'SampleTime','dead_h');end
end
o=sim(in);
end
