function report=verify_sensorless_r2_logging(compactFolder)
% Full original52 plus every unchanged observer control log, against R1.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));
reference=fullfile(base,'runs','N3R1_formal_20261016_233230_ef2a2a57-ee3e-451c-9850-e101d2101803','combined_formal_attempt_1');
record=jsondecode(fileread(fullfile(compactFolder,'record.json')));assert(strcmp(record.status,'passed')&&strcmp(record.case_id,'r1_short_logging_check'));
old=jsondecode(fileread(fullfile(reference,'record.json')));
assert(strcmp(old.raw_sha256,teach_hash(fullfile(reference,'signals.mat'))));
assert(strcmp(record.raw_sha256,teach_hash(fullfile(compactFolder,'signals.mat'))));
names=whos('-file',fullfile(reference,'signals.mat'));changed={record.logging.changes.variable};
common=setdiff({names.name},changed,'stable');
[same,count,failures]=compare_sensorless_n3_raw(fullfile(reference,'signals.mat'),fullfile(compactFolder,'signals.mat'),common);
assert(same,strjoin(failures,','));schema=jsondecode(fileread(fullfile(base,'baseline','log_schema.json')));
assert(all(ismember({schema.name},common))&&numel(schema)==52);
report=struct('node','N3R2','reference',reference,'compact',compactFolder,'compared_logs',numel(common),...
 'original52_included',true,'numeric_elements',count,'complete_common_logs_identical',same,'changed_display_logs',{changed},'all_passed',same);
teach_writejson(fullfile(compactFolder,'logging_validation.json'),report);
fprintf('R2_LOGGING_VALIDATION_PASSED logs=%d elements=%d\n',numel(common),count);
end
