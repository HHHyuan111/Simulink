function [record,signals]=run_pmsm_startup(times,enabled,windowOn)
% Same original model, locally installed startup layer, complete restoration.
if nargin<1,times=[0 15 20 30];end
if nargin<2,enabled=true;end
if nargin<3,windowOn=false;end
validateattributes(times,{'double'},{'vector','numel',4,'finite','nonnegative'});
assert(all(diff(times)>0)&&times(4)<=130);
here=fileparts(mfilename('fullpath'));root=fileparts(here);addpath(fullfile(root,'teaching'),fullfile(root,'framework'));
mdl='PMSM_FOC_R2026a';source=fullfile(root,[mdl '.slx']);
p=pmsm_system_plan;
loadedHere=~bdIsLoaded(mdl);if loadedHere,load_system(source);pmsm_reference('restore');end
assert(isequaln(pmsm_reference('capture'),p.baseline_state),'请使用固定参考的独立会话。');
before=teach_snapshot(mdl);guard=onCleanup(@()restore(mdl));
id=[char(datetime('now','Format','yyyyMMdd_HHmmss_SSS')) '_' char(java.util.UUID.randomUUID)];
folder=fullfile(here,'runs',id);mkdir(folder);
record=struct('kind','minimum_startup_v1','folder',folder,'status','running','times_ms',times,...
 'enabled',enabled,'window_on',windowOn,'model_sha256',teach_hash(source),...
 'reference_sha256',teach_hash(fullfile(root,'teaching','reference_v1','manifest.json')),'source_files',struct('path',{},'sha256',{}));
for section={'startup','teaching','timing','deadtime','control'}
 files=dir(fullfile(root,section{1},'*.m'));
 for f=files(:)',relative=[section{1} '/' f.name];record.source_files(end+1)=struct('path',relative,'sha256',teach_hash(fullfile(root,relative)));end
end
for name={'pmsm_system_plan.m','pmsm_system_inputs.m'}
 relative=['framework/' name{1}];record.source_files(end+1)=struct('path',relative,'sha256',teach_hash(fullfile(root,relative)));
end
teach_writejson(fullfile(folder,'record.json'),record);
try
 for change=p.cases(2).changes(:)',set_param([mdl '/' change.section],change.parameter,change.value);end
 set_param([mdl '/功率设置'],'gate_on','on','gate_us','0','comp_on','off');
 if windowOn,set_param([mdl '/时序设置'],'window_on','on','invalid_hold_on','on');end
 pmsm_encoder_model('install',mdl);pmsm_encoder_speed_model('install',mdl);pmsm_speed_feedback_model('install',mdl);pmsm_speed_filter_model('install',mdl);
 cfgs={p.encoder_configurations(2),p.speed_configuration,p.feedback_configurations(2),p.filter_configurations(2)};
 paths={'角度设置/编码器','角度设置/编码器/测速','速度反馈','速度反馈/速度滤波'};
 for j=1:4,for key=fieldnames(cfgs{j})',set_param([mdl '/' paths{j}],key{1},cfgs{j}.(key{1}));end,end
 pmsm_system_inputs('install',mdl,p.input_schedule);
 pmsm_startup_model('install',mdl);on='off';if enabled,on='on';end
 set_param([mdl '/启停'],'enabled',on,'start_ms',num2str(times(1),17),'stop_ms',num2str(times(2),17),'restart_ms',num2str(times(3),17));
 in=Simulink.SimulationInput(mdl);in=in.setModelParameter('StopTime',num2str(times(4)*1e-3,17));
 for name={'obs_dead_gates','obs_dead_requested','obs_pwm_timing','log_Tcm_applied'}
  logs=find_system(mdl,'LookUnderMasks','all','BlockType','ToWorkspace','VariableName',name{1});assert(isscalar(logs));
  in=in.setBlockParameter(logs{1},'SampleTime','timing_h');in=in.setBlockParameter(logs{1},'MaxDataPoints','inf');
 end
 logs=find_system(mdl,'LookUnderMasks','all','BlockType','ToWorkspace','VariableName','obs_adc_timing');
 in=in.setBlockParameter(logs{1},'SampleTime','timing_control_sample');in=in.setBlockParameter(logs{1},'MaxDataPoints','inf');
 fprintf('STARTUP_SIMULATION on=%d window=%d duration_ms=%g\n',enabled,windowOn,times(4));o=sim(in);
 signals=struct;names=o.who;
 for j=1:numel(names),x=o.get(names{j});if isa(x,'timeseries'),assert(all(isfinite(x.Data),'all'));signals.(names{j})=x;end,end
 save(fullfile(folder,'signals.mat'),'signals','-v7.3');
 if enabled,analysis=analyse_pmsm_startup(signals,record);teach_writejson(fullfile(folder,'analysis.json'),analysis);end
 clear guard;record.reference_restored=isequaln(pmsm_reference('capture'),p.baseline_state);assert(record.reference_restored);
 record.structure_preserved=isequaln(before,teach_snapshot(mdl));assert(record.structure_preserved);
 assert(strcmp(record.model_sha256,teach_hash(source)));
 for f=record.source_files(:)',assert(strcmp(f.sha256,teach_hash(fullfile(root,f.path))));end
 record.status='completed';record.signals_sha256=teach_hash(fullfile(folder,'signals.mat'));teach_writejson(fullfile(folder,'record.json'),record);
 fprintf('STARTUP_COMPLETE %s\n',folder);
 if loadedHere,close_system(mdl,0);end
catch err
 record.status='failed';record.error=err.message;teach_writejson(fullfile(folder,'record.json'),record);rethrow(err);
end
end
function restore(mdl)
if pmsm_startup_model('installed',mdl),pmsm_startup_model('remove',mdl);end
if pmsm_system_inputs('installed',mdl),pmsm_system_inputs('remove',mdl);end
if pmsm_encoder_model('installed',mdl),pmsm_encoder_model('remove',mdl);end
pmsm_reference('restore');
end
