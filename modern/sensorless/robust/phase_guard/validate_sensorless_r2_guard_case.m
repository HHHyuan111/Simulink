function record=validate_sensorless_r2_guard_case(id,folder)
% R1 estimates plus instantaneous packet phase quality. No truth guard.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);mdl='PMSM_FOC_R2026a';
for d={'','sensorless','sensorless/robust','sensorless/robust/integration','sensorless/robust/performance','sensorless/robust/execution_v3','sensorless/robust/phase_guard','teaching','control','timing','deadtime','framework','layout/appearance'},addpath(fullfile(modern,d{1}));end
assert(~bdIsLoaded(mdl));record=sensorless_r2_guard_snapshot(folder);record.case_id=id;record.numerical_version='R1_estimation_with_R2_packet_phase_guard';
plan=jsondecode(fileread(fullfile(base,'contracts/nonideal_r2_test_plan.json')));cases=plan.cases;if ~iscell(cases),cases=num2cell(cases);end
index=find(cellfun(@(x)strcmp(x.id,id),cases));assert(isscalar(index));testcase=cases{index};record.effective_case=testcase;
assert(ismember(testcase.kind,{'logging_validation','normal_precision'})&&isfield(testcase,'speed_rpm'));
assert(~isfield(testcase,'plant_R_multiplier')&&~isfield(testcase,'plant_deadtime_s')&&~isfield(testcase,'schedule')&&~isfield(testcase,'missing_reference_interval_s')&&~isfield(testcase,'reset_reference_s'),'R2 v3 physical variation adapter is not implemented.');
Simulink.fileGenControl('set','CacheFolder',fullfile(folder,'.build/cache'),'CodeGenFolder',fullfile(folder,'.build/codegen'),'createDir',true);
sldiagviewer.diary(fullfile(folder,'diagnostics.log'),'UTF-8');cleanup=onCleanup(@()close_private(mdl));
try
 record=stage(record,folder,'load');load_system(fullfile(modern,[mdl '.slx']));pmsm_reference('restore');original=teach_snapshot(mdl);fixed=pmsm_reference('capture');originalInit=get_param(mdl,'InitFcn');
 record=stage(record,folder,'configure');backup=sensorless_v2_stimulus(mdl,testcase);set_param([mdl '/speed_ref'],'Value',num2str(testcase.speed_rpm,17));
 record=stage(record,folder,'initialize_original_stopped');record.original_initialization=sensorless_r2_initialize_stopped(mdl);configured=teach_snapshot(mdl);
 record=stage(record,folder,'install');pmsm_sensorless_v2_model('install',mdl,testcase.interference_s);
 if testcase.speed_rpm<0,set_param([mdl '/无感观测'],'direction','-1');end
 record.phase_guard=sensorless_r2_phase_guard_model(mdl);
 record=stage(record,folder,'initialize_observer_stopped');record.observer_initialization=sensorless_r2_initialize_stopped(mdl);
 record.logging=sensorless_r2_logging(mdl);
 counterPath=[mdl '/无感观测/观测/R2累计记录'];record.logging.native_counter_sample_before=get_param(counterPath,'SampleTime');
 set_param(counterPath,'SampleTime','50e-6');record.logging.native_counter_sample_after='50e-6';
 ws=get_param(mdl,'ModelWorkspace');before=workspace_values(ws);
 record.control_sample=getVariable(ws,'timing_control_sample');record.speed_sample=getVariable(ws,'timing_speed_sample');
 record.config_vector=getVariable(ws,'sless_v2_cfg');record.observer_config=getVariable(ws,'sless_cfg');record.configuration=teach_settings(mdl);
 record=stage(record,folder,'observer_compile');set_param(mdl,'SimulationCommand','update');afterCompile=workspace_values(ws);
 record.workspace_unchanged_by_compile=isequaln(before,afterCompile);assert(record.workspace_unchanged_by_compile);
 graph=check_sensorless_v2_graph(mdl,configured);teach_writejson(fullfile(folder,'graph.json'),graph);assert(graph.passed);
 record=stage(record,folder,'simulate');started=tic;out=sim(mdl,'StopTime',num2str(testcase.duration_s,17));record.elapsed_s=toc(started);
 afterSimulation=workspace_values(ws);record.workspace_unchanged_by_simulation=isequaln(before,afterSimulation);assert(record.workspace_unchanged_by_simulation);
 record=stage(record,folder,'archive');signals=struct;
 for key=out.who'
  series=out.get(key{1});if ~isa(series,'timeseries'),continue;end
  assert(all(isfinite(series.Time),'all')&&all(isfinite(series.Data),'all'),'Nonfinite log: %s',key{1});signals.(key{1})=series;
 end
 save(fullfile(folder,'signals.mat'),'-struct','signals','-v7.3');record.raw_sha256=teach_hash(fullfile(folder,'signals.mat'));record.log_count=numel(fieldnames(signals));
 record=stage(record,folder,'metrics');metrics=analyse_sensorless_r2_case(signals,testcase);teach_writejson(fullfile(folder,'metrics.json'),metrics);clear out signals;
 record=stage(record,folder,'restore');pmsm_sensorless_v2_model('remove',mdl);afterLayer=teach_snapshot(mdl);record.layer_restored=isequaln(configured,afterLayer);
 set_param(mdl,'InitFcn',originalInit);sensorless_n3_restore(mdl,backup);afterModel=teach_snapshot(mdl);afterFixed=pmsm_reference('capture');
 record.callback_restored=strcmp(get_param(mdl,'InitFcn'),originalInit);record.reference_restored=isequaln(original,afterModel)&&isequaln(fixed,afterFixed);
 assert(record.layer_restored&&record.callback_restored&&record.reference_restored);sensorless_v2_guard_sources(record);
 save(fullfile(folder,'restoration.mat'),'original','configured','afterLayer','afterModel','fixed','afterFixed','before','afterCompile','afterSimulation','-v7.3');
 record.phase='completed';record.metrics_passed=metrics.all_passed;record.status='completed_performance_failed';if metrics.all_passed,record.status='passed';end
 teach_writejson(fullfile(folder,'record.json'),record);fprintf('R2_GUARD_CASE_COMPLETED %s passed=%d elapsed=%g\n',id,metrics.all_passed,record.elapsed_s);
catch err
 record.status='failed_execution';record.error=getReport(err,'extended','hyperlinks','off');teach_writejson(fullfile(folder,'record.json'),record);rethrow(err);
end
end
function values=workspace_values(ws)
entries=whos(ws);names=sort({entries.name});values=struct('name',{},'value',{});
for k=1:numel(names),values(k)=struct('name',names{k},'value',getVariable(ws,names{k}));end
end
function record=stage(record,folder,name)
record.phase=name;teach_writejson(fullfile(folder,'record.json'),record);fprintf('R2_GUARD_PHASE %s %s\n',record.case_id,name);
end
function close_private(mdl)
if bdIsLoaded(mdl),close_system(mdl,0);end
end
