function record=verify_pmsm_speed_probe(folder)
here=fileparts(mfilename('fullpath'));root=fileparts(here);
record=jsondecode(fileread(fullfile(folder,'record.json')));
assert(strcmp(record.status,'complete')&&record.quality_passed&&record.structure_restored&&record.main_model_unchanged);
assert(strcmp(record.model_sha256,teach_hash(fullfile(root,'PMSM_FOC_R2026a.slx'))));
for f=record.source_files(:)',assert(strcmp(f.sha256,teach_hash(fullfile(here,f.path))),'试测源码已改变：%s',f.path);end
for f=record.files(:)',assert(strcmp(f.sha256,teach_hash(fullfile(folder,f.path))),'试测结果校验失败：%s',f.path);end
a=load(fullfile(folder,'analysis.mat'));
for k=1:numel(a.p.amplitudes_rpm)
 s=load(fullfile(folder,sprintf('probe_%d_raw.mat',k)));raw=s.raw;tt=raw.speed_ref.Time;state=teach_values(raw.obs_state);
 assert(isequal(tt,raw.obs_state.Time,raw.speed_error.Time,raw.speed_feedback.Time));tick=round(tt/a.p.sample_time_s);
 assert(all(diff(tick)==1)&&max(abs(tt-tick*a.p.sample_time_s))<1e-10);
 x=[teach_values(raw.speed_ref) state(:,3)*30/pi teach_values(raw.speed_error) teach_values(raw.speed_feedback)];
 for j=1:numel(a.p.segments)
  seg=a.p.segments(j);stride=round(a.p.analysis_sample_time_s/a.p.sample_time_s);
  ix=tick>=seg.measure_tick&tick<seg.end_tick&mod(tick,stride)==0;fit=pmsm_sine_response(tt(ix),x(ix,:),seg.frequency_Hz);
  assert(isequaln(fit,a.responses(k).fits(j)),'原始记录重新分析不一致。');
 end
end
end
