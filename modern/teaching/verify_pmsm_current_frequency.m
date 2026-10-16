function record=verify_pmsm_current_frequency(folder)
here=fileparts(mfilename('fullpath'));root=fileparts(here);
record=jsondecode(fileread(fullfile(folder,'record.json')));
assert(strcmp(record.status,'complete')&&record.structure_restored&&record.main_model_unchanged,'频响实验未完整完成。');
assert(all([record.cases.valid],'all'),'档案包含未通过质量检查的频点。');
assert(strcmp(record.model_sha256,teach_hash(fullfile(root,'PMSM_FOC_R2026a.slx'))),'模型版本与频响档案不一致。');
for f=record.source_files(:)',assert(strcmp(f.sha256,teach_hash(fullfile(here,f.path))),'频响源码已经改变：%s',f.path);end
for f=record.files(:)',assert(strcmp(f.sha256,teach_hash(fullfile(folder,f.path))),'频响结果校验失败：%s',f.path);end
a=load(fullfile(folder,'analysis.mat'),'p','responses');p=a.p;
for c=1:numel(a.responses)
 for amp=1:numel(p.amplitudes_A)
  s=load(fullfile(folder,sprintf('%s_%d_raw.mat',p.cases(c).id,amp)),'raw');raw=s.raw;
  t=raw.fre_ref.Time;state=teach_values(raw.obs_state);tick=round(t/p.sample_time_s);
  x=[teach_values(raw.fre_ref) state(:,1) teach_values(raw.fre_error) teach_values(raw.fre_feedback)];
  for k=1:numel(p.segments)
   seg=p.segments(k);ix=tick>=seg.measure_tick&tick<seg.end_tick;fit=pmsm_sine_response(t(ix),x(ix,:),seg.frequency_Hz);
   assert(isequaln(fit,a.responses(c).amplitudes(amp).fits(k)),'原始记录重新分析不一致。');
  end
 end
end
end
