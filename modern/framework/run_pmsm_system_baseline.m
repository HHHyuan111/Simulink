function [record,outputs]=run_pmsm_system_baseline(value)
% Two 400ms closed loops using the original model, with complete restoration.
if nargin<1,value=[];end
here=fileparts(mfilename('fullpath'));root=fileparts(here);teach=fullfile(root,'teaching');addpath(teach);
p=pmsm_system_plan(value);mdl='PMSM_FOC_R2026a';source=fullfile(root,[mdl '.slx']);
if ~bdIsLoaded(mdl),load_system(source);pmsm_reference('restore');end
assert(strcmp(get_param(mdl,'SimulationStatus'),'stopped'));
assert(~pmsm_encoder_model('installed',mdl),'请先恢复固定参考，保留您当前展开的实验。');
assert(~pmsm_system_inputs('installed',mdl));
assert(isequaln(pmsm_reference('capture'),p.baseline_state),'请先恢复固定参考。');
pmsm_reference('restore');before=teach_snapshot(mdl);
id=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));u=char(java.util.UUID.randomUUID);id=[id '_system_' u(1:8)];
folder=fullfile(here,'runs',id);mkdir(folder);
record=struct('schema',1,'kind',p.kind,'id',id,'folder',folder,'status','running',...
 'value',p.value,'duration_s',p.duration_s,'matlab_version',version,'model_sha256',teach_hash(source),...
 'reference_sha256',teach_hash(fullfile(teach,'reference_v1','manifest.json')),...
 'source_files',struct('path',{},'sha256',{}),'files',struct('path',{},'sha256',{}),...
 'restored_reference',false,'original_structure_preserved',false,'cases',struct([]));
names={'pmsm_system_plan.m','pmsm_system_inputs.m','run_pmsm_system_baseline.m','pmsm_system_analysis.m','render_pmsm_system_baseline.m','verify_pmsm_system_baseline.m','repeat_pmsm_system_baseline.m','open_pmsm_framework.m'};
for name=names,record.source_files(end+1)=struct('path',['framework/' name{1}],'sha256',teach_hash(fullfile(here,name{1})));end
names={'pmsm_encoder_model.m','pmsm_encoder_speed_model.m','pmsm_speed_feedback_model.m','pmsm_speed_filter_model.m','teach_hash.m','teach_values.m','teach_snapshot.m','pmsm_reference.m','pmsm_experiment_plan.m','pmsm_experiment_catalog.m','pmsm_check_switches.m'};
for name=names,record.source_files(end+1)=struct('path',['teaching/' name{1}],'sha256',teach_hash(fullfile(teach,name{1})));end
teach_writejson(fullfile(folder,'record.json'),record);teach_writejson(fullfile(folder,'plan.json'),p);
teach_writejson(fullfile(folder,'reference_manifest.json'),p.baseline_manifest);
outputs=cell(1,2);guard=onCleanup(@()restoreSystem(mdl,p.baseline_state));
try
 pmsm_encoder_model('install',mdl);pmsm_encoder_speed_model('install',mdl);
 pmsm_speed_feedback_model('install',mdl);pmsm_speed_filter_model('install',mdl);
 pmsm_system_inputs('install',mdl,p.input_schedule);
 for k=1:2
  in=Simulink.SimulationInput(mdl);in=in.setModelParameter('StopTime',num2str(p.duration_s,17));
  for change=p.cases(k).changes(:)',in=in.setBlockParameter([mdl '/' change.section],change.parameter,change.value);end
  cfgs={p.encoder_configurations(k),p.speed_configuration,p.feedback_configurations(k),p.filter_configurations(k)};
  paths={'角度设置/编码器','角度设置/编码器/测速','速度反馈','速度反馈/速度滤波'};
  for j=1:4,cfg=cfgs{j};for key=fieldnames(cfg)',in=in.setBlockParameter([mdl '/' paths{j}],key{1},cfg.(key{1}));end,end
  loadPath=getfullname(Simulink.ID.getHandle([mdl ':523']));
  in=in.setBlockParameter(loadPath,'Time',num2str(p.input_schedule.load_step_s,17));
  in=in.setBlockParameter(loadPath,'Before',num2str(p.input_schedule.load_before_Nm,17));
  in=in.setBlockParameter(loadPath,'After',num2str(p.input_schedule.load_after_Nm,17));
  for change=p.logging_overrides(:)'
   b=find_system(mdl,'LookUnderMasks','all','FollowLinks','off','BlockType','ToWorkspace','VariableName',change.signal);
   assert(isscalar(b));in=in.setBlockParameter(b{1},change.parameter,change.value);
  end
  for name={'obs_adc_timing','log_Tcm_applied'}
   b=find_system(mdl,'LookUnderMasks','all','FollowLinks','off','BlockType','ToWorkspace','VariableName',name{1});assert(isscalar(b));
   if strcmp(name{1},'obs_adc_timing'),period='timing_control_sample';cap='inf';else,period='timing_h';cap='4000';end
   in=in.setBlockParameter(b{1},'SampleTime',period);in=in.setBlockParameter(b{1},'MaxDataPoints',cap);
  end
  fprintf('SYSTEM_BASELINE %s\n',p.cases(k).label);o=sim(in);
  names={'log_speed','log_nref','log_id','log_iq','log_iq_ref','obs_id_ref','log_Te','log_TL','obs_state',...
   'log_iabc_true','log_iabc_meas','obs_voltage','obs_current_fast','log_theta_true','log_theta_meas',...
   'obs_dead_requested','obs_dead_gates','obs_adc_timing','obs_pwm_timing','log_Tcm_applied','log_Tcm_requested',...
   'log_encoder','log_encoder_mechanical','log_encoder_control','log_speed_short','log_speed_window',...
   'log_speed_long','log_speed_control','log_speed_feedback','log_speed_filter','obs_pi_speed','obs_pi_d','obs_pi_q'};
  signals=struct;
  for name=names,x=o.get(name{1});assert(isa(x,'timeseries')&&all(isfinite(x.Data),'all'),'非有限或缺失信号：%s',name{1});signals.(name{1})=x;end
  clear o;outputs{k}=signals;save(fullfile(folder,[p.cases(k).id '.mat']),'signals','-v7.3');
  record.cases(k).id=p.cases(k).id;record.cases(k).label=p.cases(k).label;record.cases(k).signals=fieldnames(signals);
 end
 clear guard;assert(isequaln(pmsm_reference('capture'),p.baseline_state));
 record.restored_reference=true;record.original_structure_preserved=isequaln(before,teach_snapshot(mdl));assert(record.original_structure_preserved);
 assert(strcmp(record.model_sha256,teach_hash(source)));
 for f=record.source_files(:)',assert(strcmp(f.sha256,teach_hash(fullfile(root,f.path))));end
 cmd=sprintf('"%s" -batch "addpath(''%s''); render_pmsm_system_baseline(''%s'')"',...
  fullfile(matlabroot,'bin','matlab.exe'),strrep(here,'''',''''''),strrep(folder,'''',''''''));
 [status,out]=system(cmd);fprintf('%s',out);assert(status==0,'原始数据已保留，报告生成失败。');
 names={'plan.json','reference_manifest.json','reference.mat','factor.mat','analysis.json','metrics.csv','response.png','feedback.png','currents.png'};
 for name=names,record.files(end+1)=struct('path',name{1},'sha256',teach_hash(fullfile(folder,name{1})));end
 record.status='completed';teach_writejson(fullfile(folder,'record.json'),record);verify_pmsm_system_baseline(folder);
 teach_writejson(fullfile(here,'latest.json'),struct('folder',folder,'id',id));fprintf('SYSTEM_BASELINE_COMPLETE %s\n',folder);
catch err
 record.status='failed';record.error=err.message;teach_writejson(fullfile(folder,'record.json'),record);rethrow(err);
end
end
function restoreSystem(mdl,baseline)
if pmsm_system_inputs('installed',mdl),pmsm_system_inputs('remove',mdl);end
if pmsm_encoder_model('installed',mdl),pmsm_encoder_model('remove',mdl);end
pmsm_reference('restore');assert(isequaln(pmsm_reference('capture'),baseline));
end
