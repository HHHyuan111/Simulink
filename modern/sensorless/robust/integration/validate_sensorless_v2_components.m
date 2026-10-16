function record=validate_sensorless_v2_components(folder)
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);
addpath(base,fileparts(here),here,fullfile(modern,'teaching'));
assert(~bdIsLoaded('PMSM_FOC_R2026a'));record=sensorless_v2_snapshot_sources(folder);
try
 [metrics,raw]=sensorless_v2_component_tests;
 save(fullfile(folder,'raw.mat'),'metrics','raw','-v7.3');teach_writejson(fullfile(folder,'metrics.json'),metrics);
 sensorless_v2_guard_sources(record);record.status='passed';record.phase='completed';record.all_passed=metrics.all_passed;
 record.raw_sha256=teach_hash(fullfile(folder,'raw.mat'));teach_writejson(fullfile(folder,'record.json'),record);
 fprintf('N3R1_COMPONENT_PASSED %s\n',folder);
catch err
 record.status='failed';record.error=getReport(err,'extended','hyperlinks','off');teach_writejson(fullfile(folder,'record.json'),record);rethrow(err);
end
end
