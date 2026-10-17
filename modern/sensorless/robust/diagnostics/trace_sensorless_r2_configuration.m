function record=trace_sensorless_r2_configuration(folder)
% One-shot diagnostic only: no compile, observer install, or simulation.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);mdl='PMSM_FOC_R2026a';
for d={'','sensorless','sensorless/robust','sensorless/robust/integration','teaching','control','timing','deadtime','framework','layout/appearance'},addpath(fullfile(modern,d{1}));end
assert(~isfolder(folder)&&~bdIsLoaded(mdl));mkdir(folder);
record=struct('kind','configuration_probe_only','acceptance_evidence',false,'compile_called',false,'simulation_called',false,...
 'observer_installed',false,'process_id',feature('getpid'),'status','running','phase','before_load',...
 'model_sha256',teach_hash(fullfile(modern,[mdl '.slx'])),'probe_source_sha256',teach_hash([mfilename('fullpath') '.m']));
teach_writejson(fullfile(folder,'record.json'),record);cleanup=onCleanup(@()close_private(mdl));
load_system(fullfile(modern,[mdl '.slx']));record.phase='before_reference';teach_writejson(fullfile(folder,'record.json'),record);
pmsm_reference('restore');record.phase='before_stimulus';teach_writejson(fullfile(folder,'record.json'),record);
plan=jsondecode(fileread(fullfile(base,'contracts','nonideal_r2_test_plan.json')));cases=plan.cases;if ~iscell(cases),cases=num2cell(cases);end
testcase=cases{find(cellfun(@(x)strcmp(x.id,'r1_short_logging_check'),cases))};record.effective_case=testcase;
backup=sensorless_v2_stimulus(mdl,testcase);record.phase='stimulus_returned_without_compile';teach_writejson(fullfile(folder,'record.json'),record);
record.settings=teach_settings(mdl);sensorless_n3_restore(mdl,backup);
record.status='diagnostic_completed';record.phase='restored';assert(strcmp(record.model_sha256,teach_hash(fullfile(modern,[mdl '.slx']))));
teach_writejson(fullfile(folder,'record.json'),record);fprintf('R2_CONFIGURATION_PROBE_COMPLETED no_compile=1 no_simulation=1\n');
end
function close_private(mdl)
if bdIsLoaded(mdl),close_system(mdl,0);end
end
