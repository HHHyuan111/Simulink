function report=probe_sensorless_r2_dynamic_restoration(folder)
% Check the same dynamic setup/cleanup independently, without simulation.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);mdl='PMSM_FOC_R2026a';
for d={'','sensorless','sensorless/robust','sensorless/robust/integration','sensorless/robust/performance','sensorless/robust/execution_v3','sensorless/robust/phase_guard','teaching','control','timing','deadtime','framework','layout/appearance'},addpath(fullfile(modern,d{1}));end
assert(~isfolder(folder)&&~bdIsLoaded(mdl));mkdir(folder);cleanup=onCleanup(@()close_private(mdl));
modelHash=teach_hash(fullfile(modern,[mdl '.slx']));load_system(fullfile(modern,[mdl '.slx']));pmsm_reference('restore');original=teach_snapshot(mdl);fixed=pmsm_reference('capture');originalInit=get_param(mdl,'InitFcn');
plan=jsondecode(fileread(fullfile(base,'contracts/nonideal_r2_test_plan.json')));cases=plan.cases;if ~iscell(cases),cases=num2cell(cases);end
testcase=cases{find(cellfun(@(x)strcmp(x.id,'combined_dynamic'),cases))};backup=sensorless_v2_stimulus(mdl,testcase);
command=struct;command.speed_initial_rpm=testcase.speed_initial_rpm;command.events=testcase.events;command.configuration=struct('bridge','preserve_nonideal_profile');
dynamicBackup=sensorless_n3_stimulus(mdl,command);sensorless_r2_initialize_stopped(mdl);configured=teach_snapshot(mdl);
pmsm_sensorless_v2_model('install',mdl,0);sensorless_r2_phase_guard_model(mdl);sensorless_r2_initialize_stopped(mdl);sensorless_r2_logging(mdl);
set_param([mdl '/无感观测/观测/R2累计记录'],'SampleTime','50e-6');
pmsm_sensorless_v2_model('remove',mdl);afterLayer=teach_snapshot(mdl);assert(isequaln(configured,afterLayer));
set_param(mdl,'InitFcn',originalInit);sensorless_n3_restore(mdl,dynamicBackup);sensorless_n3_restore(mdl,backup);
after=teach_snapshot(mdl);afterFixed=pmsm_reference('capture');assert(isequaln(original,after)&&isequaln(fixed,afterFixed)&&strcmp(originalInit,get_param(mdl,'InitFcn')));
assert(strcmp(modelHash,teach_hash(fullfile(modern,[mdl '.slx']))));
report=struct('kind','independent_dynamic_setup_restoration_probe','all_passed',true,'simulation_called',false,...
 'original_failed_attempt_restored',false,'same_setup_restoration_path_verified',true,'model_sha256',modelHash,...
 'probe_sha256',teach_hash([mfilename('fullpath') '.m']));
save(fullfile(folder,'restoration.mat'),'original','configured','afterLayer','after','fixed','afterFixed','-v7.3');
report.raw_sha256=teach_hash(fullfile(folder,'restoration.mat'));teach_writejson(fullfile(folder,'report.json'),report);
fprintf('R2_DYNAMIC_RESTORATION_PROBE_PASSED no_simulation=1\n');
end
function close_private(mdl)
if bdIsLoaded(mdl),close_system(mdl,0);end
end
