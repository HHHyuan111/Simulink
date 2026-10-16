function [record,outputs]=run_pmsm_experiment(id,value,duration)
% Fixed controlled comparisons. Requires the loaded model at the reference.
% Uses temporary SimulationInput overrides; neither SLX nor reference is saved.
if nargin<1,id='current_bias';end
if nargin<2,value=[];end
if nargin<3,duration=[];end
plan=pmsm_experiment_plan(id,value,duration);here=fileparts(mfilename('fullpath'));root=fileparts(here);mdl='PMSM_FOC_R2026a';
source=fullfile(root,[mdl '.slx']);wasLoaded=bdIsLoaded(mdl);
if ~wasLoaded,load_system(source);end
assert(strcmp(get_param(mdl,'SimulationStatus'),'stopped'),'先停止仿真。');
if pmsm_encoder_speed_model('installed',mdl),pmsm_encoder_speed_model('remove',mdl);end
if pmsm_encoder_model('installed',mdl),pmsm_encoder_model('remove',mdl);end
assert(isequaln(pmsm_reference('capture'),plan.baseline_state),'请先点击“恢复固定参考（整套）”，避免覆盖当前实验参数。');
pmsm_reference('restore'); % Also checks for unsaved algorithm/connection edits.
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));uuid=char(java.util.UUID.randomUUID);
runId=[stamp '_' id '_' uuid(1:8)];folder=fullfile(here,'experiments','runs',runId);assert(~isfolder(folder));mkdir(folder);
record=struct('schema',1,'id',runId,'status','running','folder',folder,'scenario',plan.scenario, ...
 'factor_value',plan.value,'factor_unit',plan.scenario.unit,'duration_s',plan.duration_s, ...
 'statistics_window_s',plan.statistics_window_s,'plot_window_s',plan.plot_window_s, ...
 'matlab_version',version,'model_sha256',teach_hash(source),'baseline_manifest_sha256',teach_hash(fullfile(here,'reference_v1','manifest.json')), ...
 'baseline_state_sha256',teach_hash(fullfile(here,'reference_v1','state.json')), ...
 'parameters_are_demonstration_values',true,'pi_gains_changed',false,'source_files',struct('path',{},'sha256',{}), ...
 'cases',struct('id',{},'label',{},'configuration',{},'changes',{},'metrics',{},'available_signal_count',{},'retained_signals',{}), ...
 'files',struct('path',{},'sha256',{}),'restored_reference',false,'main_model_unchanged',false);
record.logging_overrides=plan.logging_overrides;record.numerical=plan.numerical;
if isfield(plan,'comparison_contract'),record.comparison_contract=plan.comparison_contract;end
if isfield(plan,'common_variables'),record.common_variables=plan.common_variables;end
runtime={'pmsm_experiment_catalog.m','pmsm_experiment_plan.m','run_pmsm_experiment.m','plot_pmsm_experiment.m','plot_pmsm_mechanism.m','plot_pmsm_deadtime_pair.m','plot_pmsm_low_speed_comp.m','plot_pmsm_noise_filter.m','pmsm_noise_filter_analysis.m','pmsm_render_noise_filter_run.m','plot_pmsm_timing_events.m','pmsm_timing_events_analysis.m','pmsm_render_timing_events_run.m','pmsm_deadtime_pair_alignment.m','pmsm_plot_style.m','pmsm_experiment_verify.m','open_pmsm_experiments.m'};
runtime=[runtime {'plot_pmsm_timing_deadline.m','pmsm_timing_deadline_analysis.m','pmsm_render_timing_deadline_run.m'}];
runtime=[runtime {'plot_pmsm_sampling_window.m','pmsm_sampling_window_analysis.m','pmsm_render_sampling_window_run.m'}];
runtime=[runtime {'pmsm_speed_feedback_model.m','pmsm_speed_feedback_view.m','pmsm_speed_filter_model.m','pmsm_speed_filter_view.m'}];
runtime=[runtime {'pmsm_encoder_model.m','pmsm_encoder_view.m','pmsm_encoder_speed_model.m','pmsm_encoder_speed_view.m'}];
if strcmp(id,'encoder_angle')
 runtime=[runtime {'pmsm_encoder_analysis.m','plot_pmsm_encoder.m','pmsm_render_encoder_run.m'}];
 record.encoder_configurations=plan.encoder_configurations;
end
if ismember(id,{'encoder_speed','speed_feedback','speed_filter'})
 runtime=[runtime {'pmsm_encoder_speed_analysis.m','plot_pmsm_encoder_speed.m','pmsm_render_encoder_speed_run.m'}];
 record.encoder_configurations=plan.encoder_configurations;record.speed_configuration=plan.speed_configuration;
end
if ismember(id,{'speed_feedback','speed_filter'})
 runtime=[runtime {'pmsm_speed_feedback_analysis.m','plot_pmsm_speed_feedback.m','pmsm_render_speed_feedback_run.m'}];record.feedback_configurations=plan.feedback_configurations;
end
if strcmp(id,'speed_filter')
 runtime=[runtime {'pmsm_speed_filter_analysis.m','plot_pmsm_speed_filter.m','pmsm_render_speed_filter_run.m'}];record.filter_configurations=plan.filter_configurations;
end
for name=runtime,record.source_files(end+1)=struct('path',name{1},'sha256',teach_hash(fullfile(here,name{1})));end
teach_writejson(fullfile(folder,'record.json'),record);
teach_writejson(fullfile(folder,'reference_state.json'),plan.baseline_state);teach_writejson(fullfile(folder,'reference_manifest.json'),plan.baseline_manifest);
teach_writejson(fullfile(folder,'plan.json'),plan);
outputs=cell(1,numel(plan.cases));
try
 if ismember(id,{'encoder_angle','encoder_speed','speed_feedback','speed_filter'}),pmsm_encoder_model('install',mdl);end
 if ismember(id,{'encoder_speed','speed_feedback','speed_filter'}),pmsm_encoder_speed_model('install',mdl);end
 if ismember(id,{'speed_feedback','speed_filter'}),pmsm_speed_feedback_model('install',mdl);end
 if strcmp(id,'speed_filter'),pmsm_speed_filter_model('install',mdl);end
 for k=1:numel(plan.cases)
  input=Simulink.SimulationInput(mdl);input=input.setModelParameter('StopTime',num2str(plan.duration_s,17));
  if isfield(plan,'common_variables')
   for variable=plan.common_variables(:)',input=input.setVariable(variable.name,variable.value,'Workspace',mdl);end
  end
  for change=plan.cases(k).changes(:)',input=input.setBlockParameter([mdl '/' change.section],change.parameter,change.value);end
  if ismember(id,{'encoder_angle','encoder_speed','speed_feedback','speed_filter'})
   cfg=plan.encoder_configurations(k);
   for key=fieldnames(cfg)',input=input.setBlockParameter([mdl '/角度设置/编码器'],key{1},cfg.(key{1}));end
  end
  if ismember(id,{'encoder_speed','speed_feedback','speed_filter'})
   cfg=plan.speed_configuration;for key=fieldnames(cfg)',input=input.setBlockParameter([mdl '/角度设置/编码器/测速'],key{1},cfg.(key{1}));end
  end
  if ismember(id,{'speed_feedback','speed_filter'})
   cfg=plan.feedback_configurations(k);for key=fieldnames(cfg)',input=input.setBlockParameter([mdl '/速度反馈'],key{1},cfg.(key{1}));end
  end
  if strcmp(id,'speed_filter')
   cfg=plan.filter_configurations(k);for key=fieldnames(cfg)',input=input.setBlockParameter([mdl '/速度反馈/速度滤波'],key{1},cfg.(key{1}));end
  end
  for change=plan.logging_overrides(:)'
   block=find_system(mdl,'LookUnderMasks','all','FollowLinks','off','BlockType','ToWorkspace','VariableName',change.signal);
   assert(isscalar(block),'诊断记录不唯一：%s',change.signal);input=input.setBlockParameter(block{1},change.parameter,change.value);
  end
  fprintf('FIXED_EXPERIMENT %s / %s\n',id,plan.cases(k).id);o=sim(input);
  [signals,metrics,available]=collect(o,plan.statistics_window_s,id);clear o;
  outputs{k}=signals;save(fullfile(folder,[plan.cases(k).id '.mat']),'signals','-v7.3');
  record.cases(k)=struct('id',plan.cases(k).id,'label',plan.cases(k).label,'configuration',plan.cases(k).configuration, ...
   'changes',plan.cases(k).changes,'metrics',metrics,'available_signal_count',available,'retained_signals',{fieldnames(signals)});
 end
 paired=strcmp(id,'gate_deadtime_pair');hasMechanism=ismember(id,{'digital_filter','angle_bias','gate_deadtime','gate_deadtime_pair'});
 if ismember(id,{'noise_filter','timing_events','timing_deadline','sampling_window','encoder_angle','encoder_speed','speed_feedback','speed_filter'})
  % Keep new analysis/graphics away from retained native simulation state.
  executable=fullfile(matlabroot,'bin','matlab.exe');quotedHere=strrep(here,'''','''''');quotedFolder=strrep(folder,'''','''''');
  renderer='pmsm_render_noise_filter_run';if strcmp(id,'timing_events'),renderer='pmsm_render_timing_events_run';end
  if strcmp(id,'timing_deadline'),renderer='pmsm_render_timing_deadline_run';end
  if strcmp(id,'sampling_window'),renderer='pmsm_render_sampling_window_run';end
  if strcmp(id,'encoder_angle'),renderer='pmsm_render_encoder_run';end
  if ismember(id,{'encoder_speed','speed_feedback','speed_filter'}),renderer='pmsm_render_encoder_speed_run';end
  if ismember(id,{'speed_feedback','speed_filter'}),renderer='pmsm_render_speed_feedback_run';end
  if strcmp(id,'speed_filter'),renderer='pmsm_render_speed_filter_run';end
  command=sprintf('"%s" -batch "addpath(''%s''); %s(''%s'')"',executable,quotedHere,renderer,quotedFolder);
  [status,renderOutput]=system(command);fprintf('%s',renderOutput);assert(status==0,'报告未完整生成，原始记录已保留。');
 elseif strcmp(id,'low_speed_compensation')
  plot_pmsm_low_speed_comp(outputs,plan,folder);
 elseif paired
  plot_pmsm_deadtime_pair(outputs,plan,folder);
 else
  plot_pmsm_experiment(outputs,plan,folder);
  if hasMechanism,plot_pmsm_mechanism(outputs,plan,folder);end
 end
 summary=metricsTable(record);writetable(summary,fullfile(folder,'metrics.csv'),'Encoding','UTF-8');
 if ismember(id,{'encoder_speed','speed_feedback','speed_filter'}),pmsm_encoder_speed_model('remove',mdl);end
 if ismember(id,{'encoder_angle','encoder_speed','speed_feedback','speed_filter'}),pmsm_encoder_model('remove',mdl);end
 pmsm_reference('restore');assert(isequaln(pmsm_reference('capture'),plan.baseline_state));record.restored_reference=true;
 assert(strcmp(record.model_sha256,teach_hash(source)));record.main_model_unchanged=true;
 for f=record.source_files(:)',assert(strcmp(teach_hash(fullfile(here,f.path)),f.sha256),'实验期间脚本版本发生变化。');end
 artifacts={'reference_state.json','reference_manifest.json','plan.json','reference.mat','factor.mat','comparison.png','response.png','metrics.csv'};
 if strcmp(id,'encoder_speed'),artifacts=setdiff(artifacts,{'factor.mat'},'stable');end
 if hasMechanism,artifacts{end+1}='mechanism.png';end
 if paired,artifacts=[artifacts {'startup.png','alignment.json'}];end
 if strcmp(id,'low_speed_compensation'),artifacts=[artifacts {'compensated.mat','mechanism.png','startup.png','alignment.json'}];end
 if strcmp(id,'noise_filter'),artifacts=[artifacts {'filtered.mat','mechanism.png','analysis.json'}];end
 if strcmp(id,'timing_events'),artifacts=[artifacts {'mechanism.png','timing.json','events.csv'}];end
 if strcmp(id,'timing_deadline'),artifacts=[artifacts {'late.mat','mechanism.png','deadline.json','events.csv'}];end
 if strcmp(id,'sampling_window'),artifacts=[artifacts {'held.mat','mechanism.png','window.json','samples.csv'}];end
 if strcmp(id,'encoder_angle'),artifacts=[artifacts {'delayed.mat','mechanism.png','encoder.json','encoder_samples.csv'}];end
 if strcmp(id,'encoder_speed'),artifacts=[artifacts {'mechanism.png','speed.json','speed_samples.csv'}];end
 if strcmp(id,'speed_feedback'),artifacts=[artifacts {'long.mat','mechanism.png','feedback.json','feedback_samples.csv'}];end
 if strcmp(id,'speed_filter'),artifacts=[artifacts {'mechanism.png','speed_filter.json','filter_samples.csv'}];end
 for name=artifacts,record.files(end+1)=struct('path',name{1},'sha256',teach_hash(fullfile(folder,name{1})));end
 record.status='completed';teach_writejson(fullfile(folder,'record.json'),record);pmsm_experiment_verify(folder);
 teach_writejson(fullfile(here,'experiments','latest.json'),struct('id',runId,'scenario',id,'folder',folder,'record_sha256',teach_hash(fullfile(folder,'record.json'))));
catch err
 record.status='failed';record.error=getReport(err,'extended','hyperlinks','off');
 if pmsm_encoder_speed_model('installed',mdl),pmsm_encoder_speed_model('remove',mdl);end
 if ismember(id,{'encoder_angle','encoder_speed','speed_feedback','speed_filter'})&&pmsm_encoder_model('installed',mdl),pmsm_encoder_model('remove',mdl);end
 try,pmsm_reference('restore');record.restored_reference=true;catch restoreErr,record.restore_error=restoreErr.message;end
 record.main_model_unchanged=strcmp(record.model_sha256,teach_hash(source));teach_writejson(fullfile(folder,'record.json'),record);
 if ~wasLoaded,close_system(mdl,0);end
 rethrow(err);
end
if ~wasLoaded,close_system(mdl,0);end
fprintf('FIXED_EXPERIMENT_COMPLETE %s\n',folder);
end

function [s,m,available]=collect(o,window,id)
names={'log_speed','log_nref','log_id','log_iq','log_iq_ref','obs_id_ref','log_Te','log_TL','obs_state', ...
 'log_iabc_true','log_iabc_meas','log_iabc_noise','log_iabc_adc','log_iabc_filter','obs_voltage','obs_current_fast', ...
 'log_theta_true','log_theta_meas','log_theta_error','obs_dead_requested','obs_dead_gates'};
if strcmp(id,'low_speed_compensation'),names{end+1}='obs_dead_comp';end
if ismember(id,{'timing_events','timing_deadline','sampling_window','encoder_angle','encoder_speed','speed_feedback','speed_filter'}),names=[names {'obs_adc_timing','obs_pwm_timing','log_Tcm_applied'}];end
if ismember(id,{'encoder_angle','encoder_speed','speed_feedback','speed_filter'}),names=[names {'log_encoder','log_encoder_mechanical','log_encoder_control'}];end
if ismember(id,{'encoder_speed','speed_feedback','speed_filter'}),names=[names {'log_speed_short','log_speed_window','log_speed_long','log_speed_control'}];end
if ismember(id,{'speed_feedback','speed_filter'}),names{end+1}='log_speed_feedback';end
if strcmp(id,'speed_filter'),names{end+1}='log_speed_filter';end
s=struct;available=0;allNames=o.who;
for k=1:numel(allNames),if isa(o.get(allNames{k}),'timeseries'),available=available+1;end,end
for name=names
 x=o.get(name{1});assert(isa(x,'timeseries')&&all(isfinite(x.Data),'all'),'缺少或出现非有限观测：%s',name{1});s.(name{1})=x;
end
assert(isequal(s.log_iabc_true.Time,s.log_iabc_meas.Time),'真值与测量电流时间轴不同，不能直接相减。');
time=s.log_iabc_true.Time;tail=time>=window(1)&time<=window(2);err=teach_values(s.log_iabc_meas)-teach_values(s.log_iabc_true);
assert(any(tail));state=teach_values(s.obs_state);iqRef=teach_values(s.log_iq_ref);idRef=teach_values(s.obs_id_ref);
for name={'log_speed','log_nref','log_iq','log_id','log_iq_ref','obs_id_ref','obs_state','log_Te'},assert(isequal(time,s.(name{1}).Time),'统计观测时间轴不一致：%s',name{1});end
speedError=teach_values(s.log_nref)-teach_values(s.log_speed);voltage=teach_values(s.obs_voltage);torque=teach_values(s.log_Te);iq=teach_values(s.log_iq);
m=struct('statistics_window_s',window,'measurement_mean_error_ABC_A',mean(err(tail,:),1), ...
 'measurement_rms_error_ABC_A',sqrt(mean(err(tail,:).^2,1)), ...
 'speed_tracking_rms_rpm',sqrt(mean(speedError(tail).^2)), ...
 'iq_feedback_tracking_rms_A',sqrt(mean((iq(tail)-iqRef(tail)).^2)), ...
 'iq_true_tracking_rms_A',sqrt(mean((state(tail,2)-iqRef(tail)).^2)), ...
 'id_true_tracking_rms_A',sqrt(mean((state(tail,1)-idRef(tail)).^2)), ...
 'torque_std_Nm',std(torque(tail)),'iq_true_peak_A',max(abs(state(:,2))),'voltage_saturation_fraction',mean(voltage(:,8)), ...
 'control_log_period_s',median(diff(time)),'physical_current_log_period_s',median(diff(s.obs_current_fast.Time)));
id=teach_values(s.log_id);m.true_id_mean_A=mean(state(tail,1));m.feedback_id_mean_A=mean(id(tail));
assert(isequal(time,s.log_theta_error.Time),'角度误差统计时间轴不同。');
angle=teach_values(s.log_theta_error);m.angle_error_mean_electrical_deg=mean(angle(tail))*180/pi;
m.gate_log_period_s=median(diff(s.obs_dead_gates.Time));
end

function t=metricsTable(r)
rows=cell(numel(r.cases),11);
for k=1:numel(r.cases)
 m=r.cases(k).metrics;rows(k,:)=[{r.cases(k).id} num2cell(m.measurement_mean_error_ABC_A) num2cell(m.measurement_rms_error_ABC_A) ...
  {m.speed_tracking_rms_rpm,m.iq_feedback_tracking_rms_A,m.iq_true_tracking_rms_A,m.torque_std_Nm}];
end
t=cell2table(rows,'VariableNames',{'case_id','mean_error_A_A','mean_error_B_A','mean_error_C_A','rms_error_A_A','rms_error_B_A','rms_error_C_A', ...
 'speed_error_rms_rpm','iq_feedback_error_rms_A','iq_true_error_rms_A','torque_std_Nm'});
end
