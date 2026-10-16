function folder=run_pmsm_speed_probe
% Independent worker. Never save the experiment adapter into the source SLX.
here=fileparts(mfilename('fullpath'));root=fileparts(here);m='PMSM_FOC_R2026a';
assert(~bdIsLoaded(m),'请用repeat_pmsm_speed_probe启动独立实验。');
source=fullfile(root,[m '.slx']);hash=teach_hash(source);manifest=pmsm_reference('verify');assert(strcmp(hash,manifest.model_sha256));
p=pmsm_speed_probe_plan;
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));uuid=char(java.util.UUID.randomUUID);
folder=fullfile(here,'frequency','speed_probe','runs',[stamp '_' uuid(1:8)]);mkdir(folder);
record=struct('status','running','plan',p,'model_sha256',hash,'matlab_version',version,...
 'source_files',struct('path',{},'sha256',{}),'structure_restored',false);
for f={'run_pmsm_speed_probe.m','pmsm_speed_probe_plan.m','pmsm_sine_response.m','plot_pmsm_speed_probe.m','plot_pmsm_speed_step.m','teach_values.m'}
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
 required=[names {'obs_state','obs_pi_speed','obs_pi_d','obs_pi_q','obs_aw_d','obs_aw_q'}];responses=struct([]);
 for a=1:numel(p.amplitudes_rpm)
  fprintf('SPEED_PROBE %.3g rpm duration %.4gs\n',p.amplitudes_rpm(a),p.duration_s);t=(0:round(p.duration_s/p.sample_time_s))'*p.sample_time_s;u=zeros(size(t));
  for seg=p.segments
   ix=seg.start_tick+1:seg.end_tick;u(ix)=p.amplitudes_rpm(a)*sin(2*pi*seg.frequency_Hz*(t(ix)-seg.start_tick*p.sample_time_s));
  end
  timer=tic;in=Simulink.SimulationInput(m);in=in.setVariable('speed_injection',[t u],'Workspace',m);
  in=in.setModelParameter('StopTime',num2str(p.duration_s,17));in=in.setVariable('n',0,'Workspace',m);
  in=in.setBlockParameter([m '/T_load1'],'Before','0');in=in.setBlockParameter([m '/T_load1'],'After','0');
  logs=find_system(m,'LookUnderMasks','all','BlockType','ToWorkspace');
  for b=logs(:)',if ~ismember(get_param(b{1},'VariableName'),required),in=in.setBlockParameter(b{1},'MaxDataPoints','4000');end,end
  out=sim(in);raw=struct;for n=required,raw.(n{1})=out.get(n{1});end;clear out;
  elapsed=toc(timer);save(fullfile(folder,sprintf('probe_%d_raw.mat',a)),'raw','-v7.3');
  state=teach_values(raw.obs_state);mw=get_param(m,'ModelWorkspace');tt=raw.speed_ref.Time;tick=round(tt/p.sample_time_s);
  assert(isequal(tt,raw.speed_error.Time,raw.speed_feedback.Time,raw.obs_state.Time)&&all(diff(tick)==1));
  x=[teach_values(raw.speed_ref) state(:,3)*30/pi teach_values(raw.speed_error) teach_values(raw.speed_feedback)];fits=struct([]);
  for k=1:numel(p.segments)
   seg=p.segments(k);stride=round(p.analysis_sample_time_s/p.sample_time_s);
   ix=tick>=seg.measure_tick&tick<seg.end_tick&mod(tick,stride)==0;
   assert(sum(ix)==p.measuring_cycles*p.samples_per_period(k)/stride);fit=pmsm_sine_response(tt(ix),x(ix,:),seg.frequency_Hz);
   if k==1,fits=fit;else,fits(k)=fit;end
  end
  s=struct('elapsed_s',elapsed);
  s.mechanical_balance_error_Nm=max(abs(getVariable(mw,'J')*teach_values(raw.speed_acceleration)-teach_values(raw.speed_torque)+getVariable(mw,'F')*state(:,3)));
  s.max_iq_A=max(abs(state(:,2)));s.max_id_A=max(abs(state(:,1)));s.voltage_limit_residual_V=0;s.pi_saturation_residual=0;
  for n={'obs_aw_d','obs_aw_q'},v=teach_values(raw.(n{1}));s.voltage_limit_residual_V=max(s.voltage_limit_residual_V,max(abs(v(:,1))));end
  for n={'obs_pi_speed','obs_pi_d','obs_pi_q'},v=teach_values(raw.(n{1}));s.pi_saturation_residual=max(s.pi_saturation_residual,max(abs(v(:,3)-v(:,4))));end
  response=struct('amplitude_rpm',p.amplitudes_rpm(a),'fits',fits,'guards',s);if a==1,responses=response;else,responses(a)=response;end
 end
 % Compile and record actual speed-task rate rather than equating log rate to execution rate.
 assignin(mw,'speed_injection',[t u]);
 feval(m,[],[],[],'compile');cc=onCleanup(@()feval(m,[],[],[],'term'));
 holdBlock=Simulink.ID.getFullName([m ':164']);record.speed_hold_sample_time=get_param(holdBlock,'CompiledSampleTime');
 integrator=Simulink.ID.getFullName([m ':438']);record.speed_integrator_sample_time=get_param(integrator,'CompiledSampleTime');clear cc;
 assert(abs(record.speed_hold_sample_time(1)-p.speed_task_s)<1e-12&&abs(record.speed_integrator_sample_time(1)-p.speed_task_s)<1e-12);
 restoreGraph;assert(isequaln(before,teach_snapshot(m)));record.structure_restored=true;
 assert(strcmp(hash,teach_hash(source)));record.main_model_unchanged=true;
 T=[responses(1).fits.T_true];L=[responses(1).fits.loop];
 record.linearity_T=abs(T-[responses(2).fits.T_true])./max(abs(T),1e-6);
 record.linearity_L=abs(L-[responses(2).fits.loop])./max(abs(L),1e-6);
 record.quality_passed=all(record.linearity_T<.02)&all(record.linearity_L<.02);
 for response=responses
  g=response.guards;record.quality_passed=record.quality_passed&&g.mechanical_balance_error_Nm<1e-9&&g.pi_saturation_residual<1e-8&&g.voltage_limit_residual_V<1e-8;
  for fit=response.fits,record.quality_passed=record.quality_passed&&all(fit.relative_residual<.03)&&all(fit.relative_half_drift<.03)&&fit.reference_identity_error<1e-9&&isfinite(fit.loop);end
 end
 record.guards={responses.guards};record.T_real=real(T);record.T_imag=imag(T);record.L_real=real(L);record.L_imag=imag(L);
 save(fullfile(folder,'analysis.mat'),'p','responses');
 fig=plot_pmsm_speed_probe(p,responses);savefig(fig,fullfile(folder,'response.fig'));exportgraphics(fig,fullfile(folder,'response.png'),'Resolution',140);close(fig);

 for item=record.source_files(:)',assert(strcmp(item.sha256,teach_hash(fullfile(here,item.path))));end
 record.status='complete';record.files=struct('path',{},'sha256',{});
 files=dir(folder);for f=files(:)',if ~f.isdir&&~strcmp(f.name,'record.json'),record.files(end+1)=struct('path',f.name,'sha256',teach_hash(fullfile(folder,f.name)));end,end
 teach_writejson(fullfile(folder,'record.json'),record);
 if record.quality_passed,teach_writejson(fullfile(here,'frequency','speed_probe','latest.json'),struct('folder',folder,'record_sha256',teach_hash(fullfile(folder,'record.json'))));end
 fprintf('SPEED_PROBE_COMPLETE quality=%d %s\n',record.quality_passed,folder);
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
