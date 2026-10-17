function report=probe_sensorless_r2_literal_binding(folder)
% One compile-only hot-case probe. No physical replay and no precision claim.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);mdl='PMSM_FOC_R2026a';
for d={'','sensorless','sensorless/robust','sensorless/robust/integration','sensorless/robust/performance','sensorless/robust/execution_v3','sensorless/robust/phase_guard','sensorless/robust/literal_plant','teaching','control','timing','deadtime','framework','layout/appearance'},addpath(fullfile(modern,d{1}));end
assert(~isfolder(folder)&&~bdIsLoaded(mdl));mkdir(folder);cleanup=onCleanup(@()close_private(mdl));
Simulink.fileGenControl('set','CacheFolder',fullfile(folder,'.build/cache'),'CodeGenFolder',fullfile(folder,'.build/codegen'),'createDir',true);
report=struct('kind','literal_binding_compile_probe','status','running','phase','load','simulation_called',false,'attempt_limit',1,'process_id',feature('getpid'));
teach_writejson(fullfile(folder,'report.json'),report);
try
 load_system(fullfile(modern,[mdl '.slx']));pmsm_reference('restore');original=teach_snapshot(mdl);fixed=pmsm_reference('capture');originalInit=get_param(mdl,'InitFcn');
 plan=jsondecode(fileread(fullfile(base,'contracts/nonideal_r2_test_plan.json')));cases=plan.cases;if ~iscell(cases),cases=num2cell(cases);end
 testcase=cases{find(cellfun(@(x)strcmp(x.id,'hot_R1p2_L0p8'),cases))};backup=sensorless_v2_stimulus(mdl,testcase);sensorless_r2_initialize_stopped(mdl);
 report.phase='literal_exact_evaluation';teach_writejson(fullfile(folder,'report.json'),report);plant=sensorless_r2_plant_literals(mdl,1.2,.8);report.plant=plant;configured=teach_snapshot(mdl);
 report.phase='install_compile';teach_writejson(fullfile(folder,'report.json'),report);pmsm_sensorless_v2_model('install',mdl,0);sensorless_r2_phase_guard_model(mdl);sensorless_r2_initialize_stopped(mdl);
 ws=get_param(mdl,'ModelWorkspace');reference=jsondecode(fileread(fullfile(base,'milestones/N3R2/followup_20261017/v4_r1_short_logging_check_record.json')));
 observer=getVariable(ws,'sless_cfg');front=getVariable(ws,'sless_v2_cfg');
 report.nominal_observer_preserved=isequaln(observer(:),reference.observer_config(:))&&isequaln(front(:),reference.config_vector(:));assert(report.nominal_observer_preserved);
 report.phase='observer_compile';teach_writejson(fullfile(folder,'report.json'),report);set_param(mdl,'SimulationCommand','update');graph=check_sensorless_v2_graph(mdl,configured);assert(graph.passed);
 pmsm_sensorless_v2_model('remove',mdl);assert(isequaln(configured,teach_snapshot(mdl)));sensorless_r2_restore_literals(mdl,plant);
 set_param(mdl,'InitFcn',originalInit);sensorless_n3_restore(mdl,backup);assert(isequaln(original,teach_snapshot(mdl))&&isequaln(fixed,pmsm_reference('capture')));
 report.phase='completed';report.status='diagnostic_passed';report.restored=true;report.model_sha256=teach_hash(fullfile(modern,[mdl '.slx']));
 for f=dir(fullfile(here,'*.m'))',report.sources.(erase(f.name,'.m'))=teach_hash(fullfile(f.folder,f.name));end
 teach_writejson(fullfile(folder,'report.json'),report);fprintf('R2_LITERAL_COMPILE_PROBE_PASSED no_simulation=1\n');
catch err
 report.status='failed_execution';report.error=getReport(err,'extended','hyperlinks','off');teach_writejson(fullfile(folder,'report.json'),report);rethrow(err);
end
end
function close_private(mdl)
if bdIsLoaded(mdl),close_system(mdl,0);end
end
