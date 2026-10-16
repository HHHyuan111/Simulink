function r=verify_pmsm_vector_export(folder)
% Verify a derived result and its original numerical archive independently.
r=jsondecode(fileread(fullfile(folder,'record.json')));
assert(r.schema==1&&strcmp(r.kind,'pmsm_coordinates_export_v1')&&strcmp(r.status,'completed'),'展示档案未完整生成。');
required={'snapshot.png','comparison.png','signals.csv','windows.json','metrics.json','notes.md'};
assert(isequal(sort({r.files.path}),sort(required)),'展示文件清单不完整。');
for f=r.files(:)',assert(strcmp(teach_hash(fullfile(folder,f.path)),f.sha256),'展示文件已改变：%s',f.path);end
source=pmsm_experiment_verify(r.source_folder);
assert(strcmp(source.id,r.source_id)&&strcmp(teach_hash(fullfile(r.source_folder,'record.json')),r.source_record_sha256),'原始实验身份不符。');
for f=r.source_files(:)',assert(strcmp(teach_hash(fullfile(r.source_folder,f.path)),f.sha256),'原始数据已改变：%s',f.path);end
end
