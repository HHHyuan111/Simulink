function record=validate_sensorless_r2_v8_case(id,folder)
% One initialized observer graph; same v7 math, source-bound full traces.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);mdl='PMSM_FOC_R2026a';
for d={'','sensorless','sensorless/robust','sensorless/robust/integration','sensorless/robust/performance','sensorless/robust/execution_v3','sensorless/robust/phase_guard','sensorless/robust/faults','sensorless/robust/scenarios','sensorless/robust/execution_v8','teaching','control','timing','deadtime','framework','layout/appearance'},addpath(fullfile(modern,d{1}));end
assert(~bdIsLoaded(mdl));record=sensorless_r2_v8_snapshot(folder);record.case_id=id;record.process_id=feature('getpid');
assert(ismember(id,{'r1_short_logging_check','low_speed_stop','missing_five','reset_one','deadline_jitter'}));
plan=jsondecode(fileread(fullfile(base,'contracts/nonideal_r2_test_plan.json')));cases=plan.cases;if ~iscell(cases),cases=num2cell(cases);end
testcase=cases{find(cellfun(@(x)strcmp(x.id,id),cases))};record.effective_case=testcase;record.numerical_composition='unchanged_v7_fault_phase_cores_plus_local_dynamic_sources';
build=fullfile(base,'.build','v8r1',char(java.util.UUID.randomUUID));assert(~isfolder(build));
record.generation_paths=struct('cache',fullfile(build,'c'),'codegen',fullfile(build,'g'),'isolated_per_attempt',true);
representative=fullfile(record.generation_paths.cache,'slprj','_sfprj',mdl,'_self','sfun','src',['c999_' mdl '.c']);
assert(strlength(representative)<240);record.generated_representative_path_length=strlength(representative);
Simulink.fileGenControl('set','CacheFolder',record.generation_paths.cache,'CodeGenFolder',record.generation_paths.codegen,'createDir',true);
sldiagviewer.diary(fullfile(folder,'diagnostics.log'),'UTF-8');sm=[];cleanup=onCleanup(@()close_private(mdl));
try
 record=stage(record,folder,'load');load_system(fullfile(modern,[mdl '.slx']));pmsm_reference('restore');original=teach_snapshot(mdl);fixed=pmsm_reference('capture');originalInit=get_param(mdl,'InitFcn');
 record=stage(record,folder,'configure');backup=sensorless_v2_stimulus(mdl,testcase);dynamic=[];pwm=[];
 if isfield(testcase,'events')
  command=struct('speed_initial_rpm',testcase.speed_initial_rpm,'events',{testcase.events},'configuration',struct('bridge','preserve_nonideal_profile'));
  dynamic=sensorless_n3_stimulus(mdl,command);
 else,set_param([mdl '/speed_ref'],'Value',num2str(testcase.speed_rpm,17));end
 record.original_initialization=sensorless_r2_initialize_stopped(mdl);
 if strcmp(id,'deadline_jitter'),pwm=sensorless_r2_fault_pwm_model(mdl,sensorless_r2_fault_program(testcase));end
 configured=teach_snapshot(mdl);record=stage(record,folder,'install');pmsm_sensorless_v2_model('install',mdl,0);record.phase_guard=sensorless_r2_phase_guard_model(mdl);
 record.logging=sensorless_r2_logging(mdl);set_param([mdl '/无感观测/观测/R2累计记录'],'SampleTime','50e-6');
 record.fault_adapter=sensorless_r2_fault_model(mdl,testcase);if strcmp(id,'deadline_jitter'),sensorless_r2_pwm_event_logging(mdl);end
 record.observer_initialization=sensorless_r2_initialize_stopped(mdl);ws=get_param(mdl,'ModelWorkspace');before=workspace_values(ws);
 record.config_vector=getVariable(ws,'sless_v2_cfg');record.observer_config=getVariable(ws,'sless_cfg');record.configuration=teach_settings(mdl);
 record=stage(record,folder,'initialize_object_once');sm=simulation(mdl);sm=setModelParameter(sm,StopTime=num2str(testcase.duration_s,17));started=tic;initialize(sm);record.initialization_s=toc(started);
 assert(strcmp(sm.Status,'initialized'));afterCompile=workspace_values(ws);record.workspace_unchanged_by_compile=isequaln(before,afterCompile);assert(record.workspace_unchanged_by_compile);
 graph=check_sensorless_v2_graph(mdl,configured);teach_writejson(fullfile(folder,'graph.json'),graph);assert(graph.passed);
 record=stage(record,folder,'advance_same_initialized_graph');h=getVariable(ws,'timing_h');
 [out,record.execution]=sensorless_r2_run_initialized(sm,h,testcase.duration_s,folder);record.elapsed_s=record.execution.elapsed_s;assert(isempty(out.ErrorMessage));clear sm;sm=[];
 endpoint=out.get('obs_sless_r2_native_counters');native=teach_values(endpoint);
 record.native_endpoint_verified=abs(endpoint.Time(end)-testcase.duration_s)<1e-12&&abs(native(end,1)-testcase.duration_s)<1e-12&&native(end,12)==round(testcase.duration_s/h)+1;assert(record.native_endpoint_verified);
 afterSimulation=workspace_values(ws);record.workspace_unchanged_by_simulation=isequaln(before,afterSimulation);assert(record.workspace_unchanged_by_simulation);
 record=stage(record,folder,'archive');signals=struct;
 for key=out.who'
  series=out.get(key{1});if ~isa(series,'timeseries'),continue;end
  assert(all(isfinite(series.Time),'all')&&all(isfinite(series.Data),'all'),'Nonfinite log: %s',key{1});signals.(key{1})=series;
 end
 save(fullfile(folder,'signals.mat'),'-struct','signals','-v7.3');record.raw_sha256=teach_hash(fullfile(folder,'signals.mat'));record.log_count=numel(fieldnames(signals));clear out;
 record=stage(record,folder,'restore');pmsm_sensorless_v2_model('remove',mdl);afterLayer=teach_snapshot(mdl);record.layer_restored=isequaln(configured,afterLayer);
 if ~isempty(pwm),sensorless_r2_restore_fault_pwm(pwm);end
 set_param(mdl,'InitFcn',originalInit);if ~isempty(dynamic),sensorless_n3_restore(mdl,dynamic);end
 sensorless_n3_restore(mdl,backup);afterModel=teach_snapshot(mdl);afterFixed=pmsm_reference('capture');
 record.callback_restored=strcmp(get_param(mdl,'InitFcn'),originalInit);record.reference_restored=isequaln(original,afterModel)&&isequaln(fixed,afterFixed);
 assert(record.layer_restored&&record.callback_restored&&record.reference_restored);sensorless_v2_guard_sources(record);
 save(fullfile(folder,'restoration.mat'),'original','configured','afterLayer','afterModel','fixed','afterFixed','before','afterCompile','afterSimulation','-v7.3');
 record=stage(record,folder,'metrics');
 if strcmp(id,'r1_short_logging_check'),metrics=analyse_sensorless_r2_case(signals,testcase);
 elseif strcmp(id,'low_speed_stop'),metrics=analyse_sensorless_r2_scenario(signals,testcase);
 else,metrics=analyse_sensorless_r2_fault(signals,testcase);end
 teach_writejson(fullfile(folder,'metrics.json'),metrics);clear signals;
 record.phase='completed';record.metrics_passed=metrics.all_passed;record.status='completed_performance_failed';if metrics.all_passed,record.status='passed';end
 teach_writejson(fullfile(folder,'record.json'),record);fprintf('R2_V8_COMPLETED %s passed=%d elapsed=%g\n',id,metrics.all_passed,record.elapsed_s);
catch err
 record.status='failed_execution';record.error=getReport(err,'extended','hyperlinks','off');teach_writejson(fullfile(folder,'record.json'),record);
 try,if ~isempty(sm)&&~strcmp(sm.Status,'inactive'),terminate(sm);end,catch,end
 rethrow(err);
end
end
function values=workspace_values(ws)
entries=whos(ws);names=sort({entries.name});values=struct('name',{},'value',{});
for k=1:numel(names),values(k)=struct('name',names{k},'value',getVariable(ws,names{k}));end
end
function record=stage(record,folder,name)
record.phase=name;teach_writejson(fullfile(folder,'record.json'),record);fprintf('R2_V8_PHASE %s %s\n',record.case_id,name);
end
function close_private(mdl)
if bdIsLoaded(mdl),close_system(mdl,0);end
end
