function report=verify_sensorless_r2_normal_serialized_short(folder)
% Same frozen complete arrays, without fabricating legacy init metadata.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);addpath(base,fullfile(modern,'teaching'));
r=jsondecode(fileread(fullfile(folder,'record.json')));assert(strcmp(r.status,'passed')&&strcmp(r.case_id,'r1_short_logging_check')&&r.native_endpoint_verified);
assert(r.execution.single_sim_call&&strcmp(r.execution.mode,'normal')&&strcmp(r.execution.child_mode,'normal')&&r.main_bridge_preserved&&r.reference_restored&&r.layer_restored&&r.callback_restored);
current=fullfile(folder,'signals.mat');assert(strcmp(r.raw_sha256,teach_hash(current)));
reference=fullfile(base,'runs/N3R1_formal_20261016_233230_ef2a2a57-ee3e-451c-9850-e101d2101803/combined_formal_attempt_1');
old=jsondecode(fileread(fullfile(reference,'record.json')));assert(strcmp(old.raw_sha256,teach_hash(fullfile(reference,'signals.mat'))));
names=whos('-file',fullfile(reference,'signals.mat'));changed={r.logging.changes.variable};common=setdiff({names.name},changed,'stable');
[same,count,failures]=compare_sensorless_n3_raw(fullfile(reference,'signals.mat'),current,common);schema=jsondecode(fileread(fullfile(base,'baseline/log_schema.json')));
assert(numel(common)==81&&numel(schema)==52&&all(ismember({schema.name},common)));
logging=struct('all_passed',same,'compared_logs',81,'original52_included',true,'numeric_elements',count,'failures',{failures});
teach_writejson(fullfile(folder,'logging_validation.json'),logging);assert(same,strjoin(failures,','));
reference=fullfile(base,'runs/N3R2_fault_final_short_precheck_20261017_141116_c027734c-49b8-4ecd-8e60-81a403609cfc/r1_short_logging_check_attempt_2');
old=jsondecode(fileread(fullfile(reference,'record.json')));assert(strcmp(old.raw_sha256,teach_hash(fullfile(reference,'signals.mat'))));
names=whos('-file',fullfile(reference,'signals.mat'));assert(numel(names)==96&&r.log_count==96);
[same,count,failures]=compare_sensorless_n3_raw(fullfile(reference,'signals.mat'),current,{names.name});
report=struct('all_passed',same,'logs',96,'numeric_elements',count,'failures',{failures},'reference',reference,'current',folder,...
 'all_Time_Data_equal',same,'native_endpoint_included',true,'single_physical_sim_call',true,'legacy_init_flag_fabricated',false);
teach_writejson(fullfile(folder,'v7_complete_log_comparison.json'),report);assert(same,strjoin(failures,','));
end
