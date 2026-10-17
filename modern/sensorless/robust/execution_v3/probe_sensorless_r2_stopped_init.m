function record=probe_sensorless_r2_stopped_init(folder)
% One-shot compile isolation only. No sim call; no performance verdict.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);mdl='PMSM_FOC_R2026a';
for d={'','sensorless','sensorless/robust','sensorless/robust/integration','sensorless/robust/performance','sensorless/robust/execution_v3','teaching','control','timing','deadtime','framework','layout/appearance'},addpath(fullfile(modern,d{1}));end
assert(~bdIsLoaded(mdl));record=sensorless_r2_v3_snapshot(folder);
record.kind='stopped_initialization_compile_probe';record.acceptance_evidence=false;record.simulation_called=false;
cleanup=onCleanup(@()close_private(mdl));
try
 record=stage(record,folder,'load');load_system(fullfile(modern,[mdl '.slx']));pmsm_reference('restore');original=teach_snapshot(mdl);fixed=pmsm_reference('capture');
 originalInit=get_param(mdl,'InitFcn');
 plan=jsondecode(fileread(fullfile(base,'contracts/nonideal_r2_test_plan.json')));cases=plan.cases;if ~iscell(cases),cases=num2cell(cases);end
 testcase=cases{find(cellfun(@(x)strcmp(x.id,'r1_short_logging_check'),cases))};
 record=stage(record,folder,'configure');backup=sensorless_v2_stimulus(mdl,testcase);
 record=stage(record,folder,'initialize_original_stopped');record.original_initialization=sensorless_r2_initialize_stopped(mdl);configured=teach_snapshot(mdl);
 record=stage(record,folder,'install_with_empty_original_callback');pmsm_sensorless_v2_model('install',mdl,0);
 record=stage(record,folder,'initialize_observer_stopped');record.observer_initialization=sensorless_r2_initialize_stopped(mdl);
 record.logging=sensorless_r2_logging(mdl);ws=get_param(mdl,'ModelWorkspace');before=workspace_values(ws);
 record.config_vector=getVariable(ws,'sless_v2_cfg');record.observer_config=getVariable(ws,'sless_cfg');
 record=stage(record,folder,'observer_compile_empty_callback');set_param(mdl,'SimulationCommand','update');
 after=workspace_values(ws);record.workspace_unchanged_by_compile=isequaln(before,after);assert(record.workspace_unchanged_by_compile);
 graph=check_sensorless_v2_graph(mdl,configured);assert(graph.passed);teach_writejson(fullfile(folder,'graph.json'),graph);
 record=stage(record,folder,'restore');pmsm_sensorless_v2_model('remove',mdl);afterLayer=teach_snapshot(mdl);record.layer_restored=isequaln(configured,afterLayer);
 set_param(mdl,'InitFcn',originalInit);sensorless_n3_restore(mdl,backup);afterModel=teach_snapshot(mdl);afterFixed=pmsm_reference('capture');
 record.reference_restored=isequaln(original,afterModel)&&isequaln(fixed,afterFixed);record.callback_restored=strcmp(originalInit,get_param(mdl,'InitFcn'));
 assert(record.layer_restored&&record.reference_restored&&record.callback_restored);sensorless_v2_guard_sources(record);
 save(fullfile(folder,'workspace_check.mat'),'before','after','original','configured','afterLayer','afterModel','fixed','afterFixed','-v7.3');
 record.status='diagnostic_passed';record.phase='completed';record.raw_sha256=teach_hash(fullfile(folder,'workspace_check.mat'));
 teach_writejson(fullfile(folder,'record.json'),record);fprintf('R2_STOPPED_INIT_PROBE_COMPLETED no_simulation=1\n');
catch err
 record.status='failed_execution';record.error=getReport(err,'extended','hyperlinks','off');teach_writejson(fullfile(folder,'record.json'),record);rethrow(err);
end
end
function values=workspace_values(ws)
entries=whos(ws);names=sort({entries.name});values=struct('name',{},'value',{});
for k=1:numel(names),values(k)=struct('name',names{k},'value',getVariable(ws,names{k}));end
end
function record=stage(record,folder,name)
record.phase=name;teach_writejson(fullfile(folder,'record.json'),record);fprintf('R2_STOPPED_INIT_PROBE %s\n',name);
end
function close_private(mdl)
if bdIsLoaded(mdl),close_system(mdl,0);end
end
