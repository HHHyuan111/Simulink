function sensorless_v2_guard_sources(record)
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);
for f=record.source_files(:)',assert(strcmp(f.sha256,teach_hash(fullfile(base,f.path))),'R1 source changed during execution: %s',f.path);end
for f=record.contracts(:)',assert(strcmp(f.sha256,teach_hash(fullfile(base,f.path))),'R1 frozen contract changed.');end
assert(strcmp(record.model_sha256,teach_hash(fullfile(modern,'PMSM_FOC_R2026a.slx'))));
end
