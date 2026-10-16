function folder=run_pmsm_speed_step
% Independent worker. Never save the experiment adapter into the source SLX.
here=fileparts(mfilename('fullpath'));root=fileparts(here);m='PMSM_FOC_R2026a';
assert(~bdIsLoaded(m),'请用repeat_pmsm_speed_step启动独立实验。');
source=fullfile(root,[m '.slx']);hash=teach_hash(source);manifest=pmsm_reference('verify');assert(strcmp(hash,manifest.model_sha256));
p=struct('amplitudes_rpm',[20 10],'sample_time_s',50e-6,'speed_task_s',100e-6,...
 'step_time_s',.02,'duration_s',.25,'dc_start_s',.20,'minimum_verified_tail_s',.025,...
 'scope','零负载自由转子；原速度PI与d/q电流环；原SVPWM周期平均电压适配，共同1us数值延迟；非实板标定');
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));uuid=char(java.util.UUID.randomUUID);
folder=fullfile(here,'frequency','speed_loop','runs',[stamp '_' uuid(1:8)]);mkdir(folder);
record=struct('status','running','plan',p,'model_sha256',hash,'matlab_version',version,...
 'source_files',struct('path',{},'sha256',{}),'structure_restored',false);
for f={'run_pmsm_speed_step.m','pmsm_speed_step_metrics.m','plot_pmsm_speed_step.m','teach_values.m'}
 record.source_files(end+1)=struct('path',f{1},'sha256',teach_hash(fullfile(here,f{1})));
end
teach_writejson(fullfile(folder,'record.json'),record);
load_system(source);closer=onCleanup(@()close_system(m,0));pmsm_reference('restore');before=teach_snapshot(m);
teach_writejson(fullfile(folder,'reference_parameters.json'),pmsm_config('read'));
created={};ph=get_param([m '/Sum4'],'PortHandles');dest=ph.Inport(1);oldSrc=get_param(get_param(dest,'Line'),'SrcPortHandle');
assert(strcmp(regexprep(get_param([m '/Sum4'],'Inputs'),'[^+-]',''),'+-'));
fb=get_param(get_param(ph.Inport(2),'Line'),'SrcPortHandle');
bridge=get_param([m '/Universal Bridge'],'PortHandles').Outport;vdest=get_param(get_param(bridge,'Line'),'DstPortHandle');assert(isscalar(vdest));
motor=[m '/Permanent Magnet' newline 'Synchronous Machine'];
der=get_param([motor '/derivatives'],'PortHandles');accel=get_param(get_param(der.Inport(3),'Line'),'SrcPortHandle');
assert(strcmp(get_param(get_param(accel,'Parent'),'Name'),'dwm_dt'));
qp=get_param([m '/Sum1'],'PortHandles');iqref=get_param(get_param(qp.Inport(2),'Line'),'SrcPortHandle');
record.iq_reference_source=get_param(iqref,'Parent');record.mechanical_source=get_param(accel,'Parent');
try
 inject=make('simulink/Sources/From Workspace','速度阶跃注入','VariableName','speed_injection','SampleTime','dt','Interpolate','off','OutputAfterFinalValue','Holding final value');
 delete_line(m,oldSrc,dest);add_line(m,get_param(inject,'PortHandles').Outport,dest,'autorouting','on');
 from=make('simulink/Signal Routing/From','速度实验调制','GotoTag','Tcm');mux=make('simulink/Signal Routing/Mux','速度实验平均电压','Inputs','3');mp=get_param(mux,'PortHandles');
 for phase=1:3
  b=make('simulink/User-Defined Functions/Fcn',['速度实验相电压' num2str(phase)],'Expr',sprintf('-2*Vdc/Ts*(u(%d)-(u(1)+u(2)+u(3))/3)',phase));
  bp=get_param(b,'PortHandles');add_line(m,get_param(from,'PortHandles').Outport,bp.Inport,'autorouting','on');add_line(m,bp.Outport,mp.Inport(phase),'autorouting','on');
 end
 memory=make('simulink/Discrete/Unit Delay','速度实验数值保持','SampleTime','T','InitialCondition','[0;0;0]');mem=get_param(memory,'PortHandles');
 add_line(m,mp.Outport,mem.Inport,'autorouting','on');delete_line(m,bridge,vdest);add_line(m,mem.Outport,vdest,'autorouting','on');
 unused=make('simulink/Sinks/Terminator','速度实验原桥占位');add_line(m,bridge,get_param(unused,'PortHandles').Inport,'autorouting','on');
 names={'speed_ref','speed_error','speed_feedback','speed_iq_ref','speed_torque','speed_acceleration'};
 sources=[get_param(inject,'PortHandles').Outport get_param([m '/Sum4'],'PortHandles').Outport fb iqref get_param([motor '/Te'],'PortHandles').Outport accel];
 for k=1:numel(names)
  parent=get_param(get_param(sources(k),'Parent'),'Parent');b=[parent '/阶跃记录_' names{k}];
  add_block('simulink/Sinks/To Workspace',b,'VariableName',names{k},'SaveFormat','Timeseries','SampleTime','dt','MaxDataPoints','inf');created{end+1}=b;
  add_line(parent,sources(k),get_param(b,'PortHandles').Inport,'autorouting','on');
 end
 required=[names {'obs_state','obs_pi_speed','obs_pi_d','obs_pi_q','obs_aw_d','obs_aw_q'}];metrics=struct([]);
 for a=1:numel(p.amplitudes_rpm)
  fprintf('SPEED_STEP %.3g rpm\n',p.amplitudes_rpm(a));t=(0:round(p.duration_s/p.sample_time_s))'*p.sample_time_s;
  in=Simulink.SimulationInput(m);in=in.setVariable('speed_injection',[t p.amplitudes_rpm(a)*(t>=p.step_time_s)],'Workspace',m);
  in=in.setModelParameter('StopTime',num2str(p.duration_s,17));in=in.setVariable('n',0,'Workspace',m);
  in=in.setBlockParameter([m '/T_load1'],'Before','0');in=in.setBlockParameter([m '/T_load1'],'After','0');
  logs=find_system(m,'LookUnderMasks','all','BlockType','ToWorkspace');
  for b=logs(:)',if ~ismember(get_param(b{1},'VariableName'),required),in=in.setBlockParameter(b{1},'MaxDataPoints','4000');end,end
  out=sim(in);raw=struct;for n=required,raw.(n{1})=out.get(n{1});end;clear out;
  save(fullfile(folder,sprintf('step_%d_raw.mat',a)),'raw','-v7.3');
  s=pmsm_speed_step_metrics(raw,p,p.amplitudes_rpm(a));state=teach_values(raw.obs_state);mw=get_param(m,'ModelWorkspace');
  s.mechanical_balance_error_Nm=max(abs(getVariable(mw,'J')*teach_values(raw.speed_acceleration)-teach_values(raw.speed_torque)+getVariable(mw,'F')*state(:,3)));
  s.max_iq_A=max(abs(state(:,2)));s.max_id_A=max(abs(state(:,1)));s.voltage_limit_residual_V=0;s.pi_saturation_residual=0;
  for n={'obs_aw_d','obs_aw_q'},v=teach_values(raw.(n{1}));s.voltage_limit_residual_V=max(s.voltage_limit_residual_V,max(abs(v(:,1))));end
  for n={'obs_pi_speed','obs_pi_d','obs_pi_q'},v=teach_values(raw.(n{1}));s.pi_saturation_residual=max(s.pi_saturation_residual,max(abs(v(:,3)-v(:,4))));end
  if a==1,metrics=s;main=state(:,3)/p.amplitudes_rpm(a);else,metrics(a)=s;record.normalized_speed_difference=max(abs(main-state(:,3)/p.amplitudes_rpm(a)));end
 end
 % Compile and record actual speed-task rate rather than equating log rate to execution rate.
 assignin(mw,'speed_injection',[t p.amplitudes_rpm(1)*(t>=p.step_time_s)]);
 feval(m,[],[],[],'compile');cc=onCleanup(@()feval(m,[],[],[],'term'));
 holdBlock=Simulink.ID.getFullName([m ':164']);record.speed_hold_sample_time=get_param(holdBlock,'CompiledSampleTime');
 integrator=Simulink.ID.getFullName([m ':438']);record.speed_integrator_sample_time=get_param(integrator,'CompiledSampleTime');clear cc;
 assert(abs(record.speed_hold_sample_time(1)-p.speed_task_s)<1e-12&&abs(record.speed_integrator_sample_time(1)-p.speed_task_s)<1e-12);
 restoreGraph;assert(isequaln(before,teach_snapshot(m)));record.structure_restored=true;
 assert(strcmp(hash,teach_hash(source)));record.main_model_unchanged=true;record.metrics=metrics;
 record.quality_passed=all([metrics.tail_peak_error_percent]<2)&all([metrics.tail_drift_percent]<.1)&...
  all([metrics.mechanical_balance_error_Nm]<1e-9)&all([metrics.pi_saturation_residual]<1e-8)&all([metrics.voltage_limit_residual_V]<1e-8)&...
  record.normalized_speed_difference<1e-4&&all(arrayfun(@(s)~isempty(s.settling_time_s),metrics));
 save(fullfile(folder,'analysis.mat'),'p','metrics');s=load(fullfile(folder,'step_1_raw.mat'));fig=plot_pmsm_speed_step(s.raw,p,p.amplitudes_rpm(1));
 savefig(fig,fullfile(folder,'response.fig'));exportgraphics(fig,fullfile(folder,'response.png'),'Resolution',140);close(fig);
 for item=record.source_files(:)',assert(strcmp(item.sha256,teach_hash(fullfile(here,item.path))));end
 record.status='complete';record.files=struct('path',{},'sha256',{});
 files=dir(folder);for f=files(:)',if ~f.isdir&&~strcmp(f.name,'record.json'),record.files(end+1)=struct('path',f.name,'sha256',teach_hash(fullfile(folder,f.name)));end,end
 teach_writejson(fullfile(folder,'record.json'),record);
 if record.quality_passed,teach_writejson(fullfile(here,'frequency','speed_loop','latest.json'),struct('folder',folder,'record_sha256',teach_hash(fullfile(folder,'record.json'))));end
 fprintf('SPEED_STEP_COMPLETE quality=%d %s\n',record.quality_passed,folder);
catch err
 record.status='failed';record.error=err.message;teach_writejson(fullfile(folder,'record.json'),record);rethrow(err);
end
 function b=make(lib,name,varargin)
  b=[m '/' name];add_block(lib,b,varargin{:});created{end+1}=b;
 end
 function restoreGraph
  for b=created(end:-1:1)
   parent=get_param(b{1},'Parent');ph=get_param(b{1},'PortHandles');
   for port=ph.Inport(:)',ln=get_param(port,'Line');if ln>=0,delete_line(parent,get_param(ln,'SrcPortHandle'),port);end,end
   for port=ph.Outport(:)',ln=get_param(port,'Line');if ln>=0,delete_line(ln);end,end
   delete_block(b{1});
  end
  add_line(m,oldSrc,dest,'autorouting','on');add_line(m,bridge,vdest,'autorouting','on');
 end
end
