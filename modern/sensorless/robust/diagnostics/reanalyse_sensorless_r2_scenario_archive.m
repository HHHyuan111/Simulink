function report=reanalyse_sensorless_r2_scenario_archive(folder,destination)
% Reprocess immutable existing physics. Never load a model or rerun sim.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);
for d={'sensorless','sensorless/robust','sensorless/robust/integration','sensorless/robust/performance','sensorless/robust/scenarios','teaching'},addpath(fullfile(modern,d{1}));end
assert(~isfolder(destination)&&~bdIsLoaded('PMSM_FOC_R2026a'));mkdir(destination);
record=jsondecode(fileread(fullfile(folder,'record.json')));assert(strcmp(record.phase,'metrics')&&strcmp(record.status,'failed_execution'));
raw=fullfile(folder,'signals.mat');assert(strcmp(record.raw_sha256,teach_hash(raw)));
changed={};
for f=record.source_files(:)'
 assert(strcmp(f.sha256,teach_hash(fullfile(folder,'source',f.path))));
 if ~strcmp(f.sha256,teach_hash(fullfile(base,f.path))),changed{end+1}=f.path;end %#ok<AGROW>
end
assert(isequal(changed,{'robust/performance/analyse_sensorless_r2_case.m'}),'Unexpected DUT source changes.');
for f=record.contracts(:)',assert(strcmp(f.sha256,teach_hash(fullfile(base,f.path))));end
signals=load(raw);metrics=analyse_sensorless_r2_scenario(signals,record.effective_case);clear signals;
teach_writejson(fullfile(destination,'metrics.json'),metrics);
report=struct('kind','analysis_only_reprocessing','original_folder',folder,'original_status',record.status,...
 'original_record_sha256',teach_hash(fullfile(folder,'record.json')),'raw_sha256',record.raw_sha256,...
 'simulation_reexecuted',false,'model_loaded',false,'original_attempt_overwritten',false,...
 'original_restoration_executed',false,'metrics_passed',metrics.all_passed,'changed_sources',{changed},...
 'old_analysis_sha256',teach_hash(fullfile(folder,'source/robust/performance/analyse_sensorless_r2_case.m')),...
 'new_analysis_sha256',teach_hash(fullfile(base,'robust/performance/analyse_sensorless_r2_case.m')),...
 'reprocessor_sha256',teach_hash([mfilename('fullpath') '.m']));
teach_writejson(fullfile(destination,'report.json'),report);fprintf('R2_ARCHIVE_REANALYSED passed=%d no_simulation=1\n',metrics.all_passed);
end
