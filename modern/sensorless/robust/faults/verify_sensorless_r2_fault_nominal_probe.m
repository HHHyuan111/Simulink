function report=verify_sensorless_r2_fault_nominal_probe(folder)
% Analysis only: compare every preexisting log, including52 original logs.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);addpath(base,fullfile(modern,'teaching'));
current=jsondecode(fileread(fullfile(folder,'record.json')));assert(strcmp(current.status,'diagnostic_passed')&&current.restored);
old=jsondecode(fileread(fullfile(base,'milestones/N3R2/followup_20261017/v4_r1_short_logging_check_record.json')));
assert(strcmp(current.raw_sha256,teach_hash(fullfile(folder,'signals.mat'))));assert(strcmp(old.raw_sha256,teach_hash(fullfile(old.folder,'signals.mat'))));
names=whos('-file',fullfile(old.folder,'signals.mat'));[same,count,failures]=compare_sensorless_n3_raw(fullfile(old.folder,'signals.mat'),fullfile(folder,'signals.mat'),{names.name});
schema=jsondecode(fileread(fullfile(base,'baseline/log_schema.json')));assert(all(ismember({schema.name},{names.name}))&&numel(schema)==52);
report=struct('all_passed',same,'reference',old.folder,'current',folder,'logs',numel(names),'numeric_elements',count,...
 'original52_included',true,'failures',{failures},'analysis_only',true);
teach_writejson(fullfile(folder,'nominal_comparison.json'),report);assert(same,strjoin(failures,','));
raw=load(fullfile(folder,'signals.mat'),'obs_sless_r2_actual_publications');p=raw.obs_sless_r2_actual_publications;v=teach_values(p);
assert(numel(p.Time)==400&&all(v(:,13)==1)&&max(abs(p.Time-v(:,3)))<1e-12&&max(abs(p.Time-v(:,2)-3e-6))<1e-12);
report.actual_publication_events=400;teach_writejson(fullfile(folder,'nominal_comparison.json'),report);
end
