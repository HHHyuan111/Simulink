function record=verify_pmsm_speed_step(folder)
here=fileparts(mfilename('fullpath'));root=fileparts(here);
record=jsondecode(fileread(fullfile(folder,'record.json')));
assert(strcmp(record.status,'complete')&&record.quality_passed&&record.structure_restored&&record.main_model_unchanged);
assert(strcmp(record.model_sha256,teach_hash(fullfile(root,'PMSM_FOC_R2026a.slx'))));
for f=record.source_files(:)',assert(strcmp(f.sha256,teach_hash(fullfile(here,f.path))),'实验源码已改变：%s',f.path);end
for f=record.files(:)',assert(strcmp(f.sha256,teach_hash(fullfile(folder,f.path))),'实验结果校验失败：%s',f.path);end
a=load(fullfile(folder,'analysis.mat'));
for k=1:numel(a.p.amplitudes_rpm)
 s=load(fullfile(folder,sprintf('step_%d_raw.mat',k)));metrics=pmsm_speed_step_metrics(s.raw,a.p,a.p.amplitudes_rpm(k));
 for key=fieldnames(metrics)',assert(isequaln(metrics.(key{1}),a.metrics(k).(key{1})),'原始数据重分析不一致。');end
end
end
