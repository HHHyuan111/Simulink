function folder=run_pmsm_current_frequency
% Run in an independent MATLAB process; never reuse/overwrite a live model.
here=fileparts(mfilename('fullpath'));root=fileparts(here);addpath(here);m='PMSM_FOC_R2026a';
assert(~bdIsLoaded(m),'频响实验请使用repeat_pmsm_current_frequency，在独立进程运行，保留当前模型。');
source=fullfile(root,[m '.slx']);hash=teach_hash(source);manifest=pmsm_reference('verify');assert(strcmp(hash,manifest.model_sha256));
p=pmsm_current_frequency_plan;stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));uuid=char(java.util.UUID.randomUUID);
folder=fullfile(here,'frequency','current_loop','runs',[stamp '_' uuid(1:8)]);mkdir(folder);
record=struct('schema',1,'status','running','model_sha256',hash,'matlab_version',version,...
 'plan',p,'reference_manifest_sha256',teach_hash(fullfile(here,'reference_v1','manifest.json')),...
 'scope',p.scope,'source_files',struct('path',{},'sha256',{}),'cases',[],'structure_restored',false);
for n={'run_pmsm_current_frequency.m','pmsm_current_frequency_plan.m','pmsm_sine_response.m','pmsm_frequency_metrics.m','plot_pmsm_current_frequency.m','teach_values.m'}
 record.source_files(end+1)=struct('path',n{1},'sha256',teach_hash(fullfile(here,n{1})));
end
teach_writejson(fullfile(folder,'record.json'),record);
load_system(source);closer=onCleanup(@()close_system(m,0));pmsm_reference('restore');before=teach_snapshot(m);
teach_writejson(fullfile(folder,'reference_parameters.json'),pmsm_config('read'));
created={};sumPorts=get_param([m '/Sum'],'PortHandles');dest=sumPorts.Inport(1);
oldSrc=get_param(get_param(dest,'Line'),'SrcPortHandle');assert(strcmp(get_param(get_param(oldSrc,'Parent'),'Name'),'id_ref'));
sumFeedback=get_param(get_param(sumPorts.Inport(2),'Line'),'SrcPortHandle');
bridgePorts=get_param([m '/Universal Bridge'],'PortHandles');bridgeSrc=bridgePorts.Outport(1);
voltageDest=get_param(get_param(bridgeSrc,'Line'),'DstPortHandle');assert(isscalar(voltageDest));
try
 inject=[m '/频响注入'];add_block('simulink/Sources/From Workspace',inject,'VariableName','fre_injection',...
  'SampleTime','dt','Interpolate','off','OutputAfterFinalValue','Holding final value','Position',[2200 50 2310 80]);created{end+1}=inject;
 delete_line(m,oldSrc,dest);add_line(m,get_param(inject,'PortHandles').Outport,dest,'autorouting','on');
 % Small perturbations are below the original 1us PWM edge grid. For this
 % experiment alone use exact cycle-average voltage from ORIGINAL Tcm:
 % D=1-2*Tcm/Ts; Vabc=Vdc*(D-mean(D)). PI/SVPWM/motor remain original.
 from=[m '/频响调制'];add_block('simulink/Signal Routing/From',from,'GotoTag','Tcm','Position',[2200 500 2310 530]);created{end+1}=from;
 mux=[m '/频响平均电压'];add_block('simulink/Signal Routing/Mux',mux,'Inputs','3','Position',[2600 500 2605 620]);created{end+1}=mux;
 mp=get_param(mux,'PortHandles');
 for phase=1:3
  path=[m '/频响相电压' num2str(phase)];add_block('simulink/User-Defined Functions/Fcn',path,...
   'Expr',sprintf('-2*Vdc/Ts*(u(%d)-(u(1)+u(2)+u(3))/3)',phase),'Position',[2400 450+phase*60 2530 480+phase*60]);created{end+1}=path;
  ph=get_param(path,'PortHandles');add_line(m,get_param(from,'PortHandles').Outport,ph.Inport,'autorouting','on');add_line(m,ph.Outport,mp.Inport(phase),'autorouting','on');
 end
 memory=[m '/频响数值保持'];add_block('simulink/Discrete/Unit Delay',memory,'SampleTime','T','InitialCondition','[0;0;0]',...
  'Position',[2700 540 2750 580]);created{end+1}=memory;memoryPorts=get_param(memory,'PortHandles');
 add_line(m,mp.Outport,memoryPorts.Inport,'autorouting','on');
 delete_line(m,bridgeSrc,voltageDest);add_line(m,memoryPorts.Outport,voltageDest,'autorouting','on');
 unused=[m '/频响原桥占位'];add_block('simulink/Sinks/Terminator',unused,'Position',[2700 660 2720 680]);created{end+1}=unused;
 add_line(m,bridgeSrc,get_param(unused,'PortHandles').Inport,'autorouting','on');
 piPort=get_param([m '/PI Controller_w1'],'PortHandles');errorSrc=get_param(get_param(piPort.Inport,'Line'),'SrcPortHandle');
 sources=[get_param(inject,'PortHandles').Outport errorSrc sumFeedback];names={'fre_ref','fre_error','fre_feedback'};
 for k=1:3
  path=[m '/' names{k}];add_block('simulink/Sinks/To Workspace',path,'VariableName',names{k},'SaveFormat','Timeseries',...
   'SampleTime','dt','MaxDataPoints','inf','Decimation','1','Position',[2400 50+k*60 2510 80+k*60]);created{end+1}=path;
  add_line(m,sources(k),get_param(path,'PortHandles').Inport,'autorouting','on');
 end
 responses=struct([]);
 for c=1:numel(p.cases)
  amplitudes=struct([]);
  for a=1:numel(p.amplitudes_A)
   fprintf('CURRENT_FREQUENCY %s amplitude %.3gA duration %.4gs\n',p.cases(c).id,p.amplitudes_A(a),p.duration_s);
   t=(0:round(p.duration_s/p.sample_time_s))'*p.sample_time_s;u=zeros(size(t));
   for seg=p.segments
    ix=seg.start_tick+1:seg.end_tick;u(ix)=p.amplitudes_A(a)*sin(2*pi*seg.frequency_Hz*(t(ix)-seg.start_tick*p.sample_time_s));
   end
   in=Simulink.SimulationInput(m);in=in.setVariable('fre_injection',[t u],'Workspace',m);in=in.setVariable('n',0,'Workspace',m);
   in=in.setModelParameter('StopTime',num2str(p.duration_s,17));
   in=in.setBlockParameter([m '/T_load1'],'Before','0');in=in.setBlockParameter([m '/T_load1'],'After','0');
   in=in.setBlockParameter([m '/采样设置'],'delay_on',onoff(p.cases(c).delay_cycles>0));
   in=in.setBlockParameter([m '/采样设置'],'delay_cycles',num2str(max(1,p.cases(c).delay_cycles)));
   % Bound unrelated high-rate archives. Required estimator channels stay full.
   logs=find_system(m,'LookUnderMasks','all','BlockType','ToWorkspace');
   for b=logs(:)'
    if ~ismember(get_param(b{1},'VariableName'),[names {'obs_state','obs_pi_d','obs_aw_d'}]),in=in.setBlockParameter(b{1},'MaxDataPoints','4000');end
   end
   out=sim(in);raw=struct;
   for name=[names {'obs_state','obs_pi_d','obs_aw_d'}],raw.(name{1})=out.get(name{1});end
   clear out;
   save(fullfile(folder,sprintf('%s_%d_raw.mat',p.cases(c).id,a)),'raw','-v7.3');
   state=teach_values(raw.obs_state);piData=teach_values(raw.obs_pi_d);aw=teach_values(raw.obs_aw_d);
   tt=raw.fre_ref.Time;assert(isequal(tt,raw.fre_error.Time,raw.fre_feedback.Time,raw.obs_state.Time));
   tick=round(tt/p.sample_time_s);assert(max(abs(tt-tick*p.sample_time_s))<1e-10&&all(diff(tick)==1));
   x=[teach_values(raw.fre_ref) state(:,1) teach_values(raw.fre_error) teach_values(raw.fre_feedback)];
   fits=struct([]);for k=1:numel(p.segments)
    seg=p.segments(k);ix=tick>=seg.measure_tick&tick<seg.end_tick;assert(sum(ix)==p.measuring_cycles*p.samples_per_period(k));
    fit=pmsm_sine_response(tt(ix),x(ix,:),seg.frequency_Hz);if k==1,fits=fit;else,fits(k)=fit;end
   end
   guards=struct('pi_saturation_V',max(abs(piData(:,3)-piData(:,4))),'final_limit_residual_V',max(abs(aw(:,1))),...
    'max_q_current_A',max(abs(state(:,2))),'max_speed_rad_s',max(abs(state(:,3))));
   amplitudes(a).fits=fits;amplitudes(a).guards=guards;
  end
  main=amplitudes(1).fits;half=amplitudes(2).fits;T=[main.T_true];L=[main.loop];
  linearityT=abs(T-[half.T_true])./max(abs(T),1e-6);linearityL=abs(L-[half.loop])./max(abs(L),1e-6);
  valid=true(size(T));
  for k=1:numel(main)
   for a=1:2
    fit=amplitudes(a).fits(k);g=amplitudes(a).guards;
    valid(k)=valid(k)&&all(fit.relative_residual<.03)&&all(fit.relative_half_drift<.03)&&fit.reference_identity_error<1e-10&&...
     g.pi_saturation_V<1e-8&&g.final_limit_residual_V<1e-8&&g.max_q_current_A<1e-3&&g.max_speed_rad_s<1e-3;
   end
  end
  valid=valid&linearityT<.02&linearityL<.02&isfinite(L);
  response=struct('id',p.cases(c).id,'label',p.cases(c).label,'T',T,'L',L,'valid',valid,'amplitudes',amplitudes,...
   'linearity_T',linearityT,'linearity_L',linearityL,'metrics',pmsm_frequency_metrics(p.frequency_Hz,T,L,valid));
  if c==1,responses=response;else,responses(c)=response;end
 end
 assert(all([responses.valid]),'存在未通过小信号质量检查的频点；不发布为有效基线。');
 for c=1:numel(responses),assert(~isempty(responses(c).metrics.bandwidth_Hz)&&~isempty(responses(c).metrics.phase_margin_deg),'扫频未覆盖指标交点；不发布为完整基线。');end
 restoreGraph;assert(isequaln(before,teach_snapshot(m)));record.structure_restored=true;
 record.cases=rmfield(responses,{'T','L','amplitudes'});
 for c=1:numel(responses)
  record.cases(c).T_real=real(responses(c).T);record.cases(c).T_imag=imag(responses(c).T);
  record.cases(c).L_real=real(responses(c).L);record.cases(c).L_imag=imag(responses(c).L);
  record.cases(c).guards={responses(c).amplitudes.guards};
 end
 assert(strcmp(hash,teach_hash(source)));record.status='complete';record.main_model_unchanged=true;
 save(fullfile(folder,'analysis.mat'),'p','responses');
 fig=plot_pmsm_current_frequency(p,responses);savefig(fig,fullfile(folder,'response.fig'));exportgraphics(fig,fullfile(folder,'response.png'),'Resolution',140);close(fig);
 record.files=struct('path',{},'sha256',{});files=dir(folder);
 for file=files(:)',if ~file.isdir&&~strcmp(file.name,'record.json'),record.files(end+1)=struct('path',file.name,'sha256',teach_hash(fullfile(folder,file.name)));end,end
 teach_writejson(fullfile(folder,'record.json'),record);
 teach_writejson(fullfile(here,'frequency','current_loop','latest.json'),struct('folder',folder,'record_sha256',teach_hash(fullfile(folder,'record.json'))));
 fprintf('CURRENT_FREQUENCY_COMPLETE %s\n',folder);
catch err
 record.status='failed';record.error=err.message;teach_writejson(fullfile(folder,'record.json'),record);rethrow(err);
end
 function restoreGraph
  % Remove only owned taps and injection; preserve every old branch.
  for path=created(end:-1:1)
   ph=get_param(path{1},'PortHandles');for port=ph.Inport(:)',ln=get_param(port,'Line');if ln>=0,src=get_param(ln,'SrcPortHandle');delete_line(m,src,port);end,end
   for port=ph.Outport(:)',ln=get_param(port,'Line');if ln>=0,delete_line(ln);end,end
   delete_block(path{1});
  end
  add_line(m,oldSrc,dest,'autorouting','on');
  add_line(m,bridgeSrc,voltageDest,'autorouting','on');
 end
end
function s=onoff(b)
if b,s='on';else,s='off';end
end
