function r=pmsm_experiment_verify(folder)
% Verify an archived result independently of the currently loaded model.
r=jsondecode(fileread(fullfile(folder,'record.json')));
assert(r.schema==1&&strcmp(r.status,'completed'),'实验未完整完成，不能作为可比较结果。');
assert(r.restored_reference&&r.main_model_unchanged,'实验未满足恢复或主模型保持要求。');
required={'reference_state.json','reference_manifest.json','plan.json','reference.mat','factor.mat','comparison.png','response.png','metrics.csv'};
if strcmp(r.scenario.id,'encoder_speed'),required=setdiff(required,{'factor.mat'},'stable');end
if ismember(r.scenario.id,{'digital_filter','angle_bias','gate_deadtime','gate_deadtime_pair'}),required{end+1}='mechanism.png';end
if strcmp(r.scenario.id,'gate_deadtime_pair'),required=[required {'startup.png','alignment.json'}];end
if strcmp(r.scenario.id,'low_speed_compensation'),required=[required {'compensated.mat','mechanism.png','startup.png','alignment.json'}];end
if strcmp(r.scenario.id,'noise_filter'),required=[required {'filtered.mat','mechanism.png','analysis.json'}];end
if strcmp(r.scenario.id,'timing_events'),required=[required {'mechanism.png','timing.json','events.csv'}];end
if strcmp(r.scenario.id,'timing_deadline'),required=[required {'late.mat','mechanism.png','deadline.json','events.csv'}];end
if strcmp(r.scenario.id,'sampling_window'),required=[required {'held.mat','mechanism.png','window.json','samples.csv'}];end
if strcmp(r.scenario.id,'encoder_angle'),required=[required {'delayed.mat','mechanism.png','encoder.json','encoder_samples.csv'}];end
if strcmp(r.scenario.id,'encoder_speed'),required=[required {'mechanism.png','speed.json','speed_samples.csv'}];end
if strcmp(r.scenario.id,'speed_feedback'),required=[required {'long.mat','mechanism.png','feedback.json','feedback_samples.csv'}];end
if strcmp(r.scenario.id,'speed_filter'),required=[required {'mechanism.png','speed_filter.json','filter_samples.csv'}];end
assert(isequal(sort({r.files.path}),sort(required)),'实验结果文件清单不完整。');
for f=r.files(:)',assert(strcmp(teach_hash(fullfile(folder,f.path)),f.sha256),'实验文件已改变或混用：%s',f.path);end
assert(strcmp(teach_hash(fullfile(folder,'reference_state.json')),r.baseline_state_sha256),'参考状态身份不符。');
assert(strcmp(teach_hash(fullfile(folder,'reference_manifest.json')),r.baseline_manifest_sha256),'参考版本身份不符。');
end
