function r=verify_pmsm_system_baseline(folder)
here=fileparts(mfilename('fullpath'));addpath(fullfile(fileparts(here),'teaching'));
r=jsondecode(fileread(fullfile(folder,'record.json')));
assert(r.schema==1&&strcmp(r.kind,'integrated_system_baseline_v1')&&strcmp(r.status,'completed'));
assert(r.restored_reference&&r.original_structure_preserved);
required={'plan.json','reference_manifest.json','reference.mat','factor.mat','analysis.json','metrics.csv','response.png','feedback.png','currents.png'};
assert(isequal(sort({r.files.path}),sort(required)));
for f=r.files(:)',assert(strcmp(teach_hash(fullfile(folder,f.path)),f.sha256),'整机档案文件已变化：%s',f.path);end
assert(strcmp(teach_hash(fullfile(folder,'reference_manifest.json')),r.reference_sha256));
p=jsondecode(fileread(fullfile(folder,'plan.json')));assert(strcmp(p.kind,r.kind)&&isequal(p.value(:),r.value(:))&&p.duration_s==r.duration_s);
a=jsondecode(fileread(fullfile(folder,'analysis.json')));assert(a.interface_checks_passed);
end
