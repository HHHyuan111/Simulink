function publish_timing_stage3
% Final desktop step, deliberately separate from candidate verification.
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);addpath(fullfile(root,'teaching'));
recordFile=fullfile(folder,'timing_stage3_results.json');record=jsondecode(fileread(recordFile));
candidate=fullfile(root,'.build','timing_stage','PMSM_FOC_R2026a.slx');canonical=fullfile(root,'PMSM_FOC_R2026a.slx');
assert(record.all_passed&&isfield(record,'original_geometry_preserved')&&record.original_geometry_preserved);
assert(strcmp(teach_hash(candidate),record.model_sha256),'Verified candidate has changed.');
current=teach_hash(canonical);assert(strcmp(current,record.source_sha256)||strcmp(current,record.model_sha256),'Main model changed since review; do not overwrite.');
release_timing_gui;
if ~strcmp(current,record.model_sha256),copyfile(candidate,canonical);end
assert(strcmp(teach_hash(canonical),record.model_sha256));
record.publication_status='published';record.canonical_sha256=record.model_sha256;
record.published_at=char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));teach_writejson(recordFile,record);
refresh_timing_gui;
end
