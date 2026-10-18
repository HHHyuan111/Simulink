function report=probe_sensorless_r2_stopped_bootstrap(folder)
% Split the existing stopped preamble into durable boundaries; no simulation.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);mdl='PMSM_FOC_R2026a';
for part={'','sensorless','sensorless/robust','sensorless/robust/integration','sensorless/robust/performance','sensorless/robust/execution_v3',...
 'sensorless/robust/phase_guard','sensorless/robust/faults','sensorless/robust/scenarios','sensorless/robust/literal_plant',...
 'sensorless/robust/execution_v8','sensorless/robust/constructor','sensorless/robust/model_reference','sensorless/robust/generated_backend','teaching','control','timing','deadtime','framework','layout/appearance'}
 addpath(fullfile(modern,part{1}));
end
assert(~isfolder(folder)&&~bdIsLoaded(mdl));mkdir(folder);cleanup=onCleanup(@()close_private(mdl));
report=struct('kind','stopped_preamble_isolation','phase','copy','all_passed',false,'process_id',matlabProcessID,...
 'matlab_version',version,'simulation_starts',0,'compile_requested',false,'observer_constructed',false,'model_saved',false,'native_retries',0);
source=fullfile(modern,[mdl '.slx']);target=fullfile(folder,[mdl '.slx']);copyfile(source,target);
report.model_sha256=teach_hash(source);assert(strcmp(teach_hash(target),report.model_sha256));
copyfile([mfilename('fullpath') '.m'],fullfile(folder,'probe_source.m.txt'));report.probe_sha256=teach_hash([mfilename('fullpath') '.m']);
contract=fullfile(base,'contracts/nonideal_r2_stopped_bootstrap_probe.json');copyfile(contract,fullfile(folder,'contract.json'));report.contract_sha256=teach_hash(contract);
report.function_paths=struct('load_system',which('load_system'),'geometry_restore',which('pmsm_reference_geometry'),'reference',which('pmsm_reference'),'snapshot',which('teach_snapshot'),'config',which('pmsm_config'));
try
 stage('before_load');load_system(target);stage('after_load');report.current_root_after_load=bdroot;report.current_system_after_load=gcs;
 report.context_matches=strcmp(report.current_root_after_load,mdl);stage('root_context_recorded');assert(report.context_matches,'Unexpected current model root.');
 stage('before_fixed_restore');pmsm_reference_geometry('restore');stage('after_fixed_restore');
 stage('before_main_snapshot');original=teach_snapshot(mdl);stage('after_main_snapshot');
 stage('before_reference_capture');fixed=pmsm_reference('capture');stage('after_reference_capture');
 stage('before_callback_read');originalInit=get_param(mdl,'InitFcn');report.callback_characters=numel(originalInit);stage('after_callback_read');
 report.original_blocks=numel(original.blocks);report.workspace_variables=numel(fixed.workspace_values)+numel(fixed.workspace_metadata);
 save(fullfile(folder,'stopped_snapshot.mat'),'original','fixed','originalInit','-v7.3');report.snapshot_sha256=teach_hash(fullfile(folder,'stopped_snapshot.mat'));
 stage('before_close');close_system(mdl,0);report.closed=~bdIsLoaded(mdl);
 report.source_unchanged=strcmp(teach_hash(source),report.model_sha256);report.copy_unchanged=strcmp(teach_hash(target),report.model_sha256);
 report.all_passed=report.closed&&report.source_unchanged&&report.copy_unchanged&&report.context_matches;stage('completed');
catch err
 report.phase_at_error=report.phase;report.phase='diagnostic_error';report.error=getReport(err,'extended','hyperlinks','off');teach_writejson(fullfile(folder,'report.json'),report);rethrow(err);
end
 function stage(value)
  report.phase=value;teach_writejson(fullfile(folder,'report.json'),report);fprintf('STOPPED_PREAMBLE_PHASE %s\n',value);
 end
end
function close_private(mdl)
if bdIsLoaded(mdl),close_system(mdl,0);end
end
