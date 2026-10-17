function report=verify_sensorless_r2_v8_short(folder)
% Exact complete96-log comparison, independent of display sampling changes.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);addpath(base,fullfile(modern,'teaching'));
record=jsondecode(fileread(fullfile(folder,'record.json')));assert(strcmp(record.status,'passed')&&strcmp(record.case_id,'r1_short_logging_check')&&record.native_endpoint_verified);
reference=fullfile(base,'runs/N3R2_fault_final_short_precheck_20261017_141116_c027734c-49b8-4ecd-8e60-81a403609cfc/r1_short_logging_check_attempt_2');
old=jsondecode(fileread(fullfile(reference,'record.json')));
assert(strcmp(old.raw_sha256,teach_hash(fullfile(reference,'signals.mat')))&&strcmp(record.raw_sha256,teach_hash(fullfile(folder,'signals.mat'))));
names=whos('-file',fullfile(reference,'signals.mat'));assert(numel(names)==96&&record.log_count==96);
[same,count,failures]=compare_sensorless_n3_raw(fullfile(reference,'signals.mat'),fullfile(folder,'signals.mat'),{names.name});
report=struct('all_passed',same,'logs',96,'numeric_elements',count,'failures',{failures},'reference',reference,'current',folder,...
 'all_Time_Data_equal',same,'native_endpoint_included',true,'no_second_observer_initialization',record.execution.initialized_once);
teach_writejson(fullfile(folder,'v7_complete_log_comparison.json'),report);assert(same,strjoin(failures,','));
end
