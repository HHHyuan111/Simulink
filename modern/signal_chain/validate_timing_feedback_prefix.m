function report=validate_timing_feedback_prefix
% Cross-duration regression against the sealed 50ms event experiment.
root=fileparts(fileparts(mfilename('fullpath')));here=fullfile(root,'teaching');addpath(root,here);
latest=jsondecode(fileread(fullfile(root,'signal_chain','timing_feedback_latest.json')));new=pmsm_experiment_verify(latest.folder);
summary=jsondecode(fileread(fullfile(here,'experiments','examples','timing_deadline','summary.json')));oldFolder=summary.source_run_folder;
assert(strcmp(summary.source_record_sha256,teach_hash(fullfile(oldFolder,'record.json'))));old=pmsm_experiment_verify(oldFolder);
assert(strcmp(old.model_sha256,new.model_sha256)&&strcmp(old.baseline_state_sha256,new.baseline_state_sha256)&&strcmp(old.baseline_manifest_sha256,new.baseline_manifest_sha256));
skip={'obs_current_fast','obs_dead_requested','obs_dead_gates','obs_adc_timing','obs_pwm_timing','log_Tcm_applied'};checks=struct('case_id',{},'signal',{},'samples',{});
for k=1:3
 a=load(fullfile(oldFolder,[old.cases(k).id '.mat']),'signals');b=load(fullfile(latest.folder,[new.cases(k).id '.mat']),'signals');
 for field=setdiff(fieldnames(a.signals),skip)'
  x=a.signals.(field{1});y=b.signals.(field{1});v=teach_values(x);w=teach_values(y);keep=y.Time>=x.Time(1)&y.Time<=x.Time(end);
  assert(isequaln(x.Time,y.Time(keep))&&isequaln(v,w(keep,:)),'历史前缀不一致：%s/%s',old.cases(k).id,field{1});
  checks(end+1)=struct('case_id',old.cases(k).id,'signal',field{1},'samples',numel(x.Time));
 end
end
report=struct('passed',true,'source_folder',latest.folder,'historical_folder',oldFolder,'historical_record_sha256',summary.source_record_sha256,'source_record_sha256',latest.record_sha256,...
 'checks',checks,'scope','新200ms的前50ms完整控制日志与既有封存档案逐点比较；前两组计算时间相同，第三组旧11μs与新15μs均在50μs更新生效。未比较高频尾部诊断，未将其声称为新200ms的完整独立重跑。');
target=fullfile(root,'signal_chain','timing_feedback');if ~isfolder(target),mkdir(target);end
teach_writejson(fullfile(target,'prefix_validation.json'),report);disp(numel(checks));disp('TIMING_FEEDBACK_PREFIX_VALIDATED');
end
