function record=validate_sensorless_r2_reference_case(id,folder)
% One source implementation for development precheck and later frozen matrix.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);mdl='PMSM_FOC_R2026a';
for part={'','sensorless','sensorless/robust','sensorless/robust/integration','sensorless/robust/performance','sensorless/robust/execution_v3',...
 'sensorless/robust/phase_guard','sensorless/robust/faults','sensorless/robust/scenarios','sensorless/robust/literal_plant',...
 'sensorless/robust/execution_v8','sensorless/robust/constructor','sensorless/robust/model_reference','teaching','control','timing','deadtime','framework','layout/appearance'}
 addpath(fullfile(modern,part{1}));
end
assert(~bdIsLoaded(mdl));record=sensorless_r2_reference_snapshot(folder);record.case_id=id;record.process_id=matlabProcessID;
plan=jsondecode(fileread(fullfile(base,'contracts/nonideal_r2_test_plan.json')));cases=plan.cases;if ~iscell(cases),cases=num2cell(cases);end
selected=cellfun(@(x)strcmp(x.id,id),cases);assert(sum(selected)==1);testcase=cases{selected};record.effective_case=testcase;
build=fullfile(base,'.build','mr',char(java.util.UUID.randomUUID));assert(~isfolder(build));
record.generation_paths=struct('cache',fullfile(build,'c'),'codegen',fullfile(build,'g'),'isolated_per_attempt',true);
Simulink.fileGenControl('set','CacheFolder',record.generation_paths.cache,'CodeGenFolder',record.generation_paths.codegen,'createDir',true);
sldiagviewer.diary(fullfile(folder,'diagnostics.log'),'UTF-8');sm=[];token=strrep(char(java.util.UUID.randomUUID),'-','');child=['sr2_' token(1:8)];cleanup=onCleanup(@()close_private(mdl,child));
try
 sensorless_r2_verify_constructor;record=stage(record,folder,'load');load_system(fullfile(modern,[mdl '.slx']));pmsm_reference_geometry('restore');
 original=teach_snapshot(mdl);fixed=pmsm_reference('capture');originalInit=get_param(mdl,'InitFcn');
 record=stage(record,folder,'configure');originalReduction=get_param(mdl,'BlockReduction');assert(strcmp(originalReduction,'on'));
 backup=sensorless_v2_stimulus(mdl,testcase);dynamic=[];pwm=[];plant=[];
 if isfield(testcase,'events')
     command=struct('speed_initial_rpm',testcase.speed_initial_rpm,'events',{testcase.events},'configuration',struct('bridge','preserve_nonideal_profile'));
     dynamic=sensorless_n3_stimulus(mdl,command);
 else
     set_param([mdl '/speed_ref'],'Value',num2str(testcase.speed_rpm,17));
 end
 if isfield(testcase,'plant_deadtime_s'),set_param([mdl '/功率设置'],'gate_us',num2str(testcase.plant_deadtime_s*1e6,17));end
 record.original_initialization=sensorless_r2_initialize_stopped(mdl);
 if isfield(testcase,'plant_R_multiplier')
  plant=sensorless_r2_plant_literals(mdl,testcase.plant_R_multiplier,testcase.plant_L_multiplier);
  record.actual_plant_R_Ld_Lq=plant.actual;record.nominal_R_Ld_Lq=plant.nominal;record.binding_method='parenthesized_17_digit_literals_no_added_workspace_symbols';
 end
 if strcmp(id,'deadline_jitter'),pwm=sensorless_r2_fault_pwm_model(mdl,sensorless_r2_fault_program(testcase));end
 configured=teach_snapshot(mdl);record=stage(record,folder,'construct_direct_stopped');pmsm_sensorless_v2_geometry_model('install',mdl,0);
 if isfield(testcase,'speed_rpm')&&testcase.speed_rpm<0,set_param([mdl '/无感观测'],'direction','-1');end
 record.phase_guard=sensorless_r2_phase_guard_model(mdl);record.logging=sensorless_r2_logging(mdl);set_param([mdl '/无感观测/观测/R2累计记录'],'SampleTime','50e-6');
 record.fault_adapter=sensorless_r2_fault_model(mdl,testcase);if strcmp(id,'deadline_jitter'),sensorless_r2_pwm_event_logging(mdl);end
 record.observer_initialization=sensorless_r2_initialize_stopped(mdl);graph=check_sensorless_v2_graph(mdl,configured);assert(graph.passed);teach_writejson(fullfile(folder,'direct_graph.json'),graph);
 record=stage(record,folder,'convert_reference');record.reference_adapter=sensorless_r2_reference_model('install',mdl,folder,child);
 ws=get_param(mdl,'ModelWorkspace');childWs=get_param(child,'ModelWorkspace');before=workspace_values(ws);childBefore=workspace_values(childWs);assert(isequaln(before,childBefore));
 record.config_vector=getVariable(ws,'sless_v2_cfg');record.observer_config=getVariable(ws,'sless_cfg');record.configuration=teach_settings(mdl);
 if isfield(testcase,'plant_R_multiplier')
  accepted=jsondecode(fileread(fullfile(base,'milestones/N3R2/followup_20261017/v4_r1_short_logging_check_record.json')));
  record.observer_nominal_preserved=isequaln(record.config_vector(:),accepted.config_vector(:))&&isequaln(record.observer_config(:),accepted.observer_config(:));assert(record.observer_nominal_preserved);
 end
 record=stage(record,folder,'initialize_reference_once');sm=simulation(mdl);sm=setModelParameter(sm,StopTime=num2str(testcase.duration_s,17));initialize(sm);assert(strcmp(sm.Status,'initialized'));
 afterCompile=workspace_values(ws);childAfterCompile=workspace_values(childWs);record.workspace_unchanged_by_compile=isequaln(before,afterCompile)&&isequaln(childBefore,childAfterCompile);assert(record.workspace_unchanged_by_compile);
 graph=check_sensorless_r2_reference_graph(mdl,configured,record.reference_adapter);teach_writejson(fullfile(folder,'graph.json'),graph);assert(graph.passed);
 record=stage(record,folder,'advance_same_reference_graph');[out,record.execution]=sensorless_r2_run_initialized(sm,62.5e-9,testcase.duration_s,folder);record.elapsed_s=record.execution.elapsed_s;assert(isempty(out.ErrorMessage));clear sm;sm=[];
 endpoint=out.get('obs_sless_r2_native_counters');native=teach_values(endpoint);record.native_endpoint_verified=abs(endpoint.Time(end)-testcase.duration_s)<1e-12&&abs(native(end,1)-testcase.duration_s)<1e-12&&native(end,12)==round(testcase.duration_s/62.5e-9)+1;assert(record.native_endpoint_verified);
 afterSimulation=workspace_values(ws);childAfterSimulation=workspace_values(childWs);record.workspace_unchanged_by_simulation=isequaln(before,afterSimulation)&&isequaln(childBefore,childAfterSimulation);assert(record.workspace_unchanged_by_simulation);
 record=stage(record,folder,'archive');signals=struct;
 for key=out.who'
  series=out.get(key{1});if isa(series,'timeseries'),assert(all(isfinite(series.Time),'all')&&all(isfinite(series.Data),'all'));signals.(key{1})=series;end
 end
 save(fullfile(folder,'signals.mat'),'-struct','signals','-v7.3');record.raw_sha256=teach_hash(fullfile(folder,'signals.mat'));record.log_count=numel(fieldnames(signals));clear out;
 assert(strcmp(teach_hash(record.reference_adapter.child_file),record.reference_adapter.child_model_sha256));
 record=stage(record,folder,'restore');sensorless_r2_reference_model('remove',mdl);afterLayer=teach_snapshot(mdl);record.layer_restored=isequaln(configured,afterLayer);
 if ~isempty(pwm),sensorless_r2_restore_fault_pwm(pwm);end
 if ~isempty(plant),sensorless_r2_restore_literals(mdl,plant);end
 set_param(mdl,'InitFcn',originalInit);if ~isempty(dynamic),sensorless_n3_restore(mdl,dynamic);end
 sensorless_n3_restore(mdl,backup);afterModel=teach_snapshot(mdl);afterFixed=pmsm_reference('capture');
 record.callback_restored=strcmp(get_param(mdl,'InitFcn'),originalInit);record.reference_restored=isequaln(original,afterModel)&&isequaln(fixed,afterFixed);
 record.block_reduction=struct('effective','on','restored',strcmp(get_param(mdl,'BlockReduction'),originalReduction));
 assert(record.layer_restored&&record.callback_restored&&record.reference_restored&&record.block_reduction.restored);sensorless_v2_guard_sources(record);sensorless_r2_verify_constructor;
 save(fullfile(folder,'restoration.mat'),'original','configured','afterLayer','afterModel','fixed','afterFixed','before','afterCompile','afterSimulation','childBefore','childAfterCompile','childAfterSimulation','-v7.3');
 record=stage(record,folder,'metrics');
 if ismember(id,{'missing_five','reset_one','deadline_jitter'}),metrics=analyse_sensorless_r2_fault(signals,testcase);
 else,metrics=analyse_sensorless_r2_scenario(signals,testcase);end
 teach_writejson(fullfile(folder,'metrics.json'),metrics);record.phase='completed';record.metrics_passed=metrics.all_passed;record.status='completed_performance_failed';if metrics.all_passed,record.status='passed';end
 teach_writejson(fullfile(folder,'record.json'),record);fprintf('R2_REFERENCE_COMPLETED %s passed=%d elapsed=%g\n',id,metrics.all_passed,record.elapsed_s);
catch err
 record.status='failed_execution';record.error=getReport(err,'extended','hyperlinks','off');teach_writejson(fullfile(folder,'record.json'),record);
 try
  if ~isempty(sm)&&~strcmp(sm.Status,'inactive'),terminate(sm);end
 catch
 end
 rethrow(err);
end
end
function record=stage(record,folder,name)
record.phase=name;teach_writejson(fullfile(folder,'record.json'),record);fprintf('R2_REFERENCE_PHASE %s %s\n',record.case_id,name);
end
function values=workspace_values(ws)
entries=whos(ws);names=sort({entries.name});values=repmat(struct('name','','value',[]),numel(names),1);
for k=1:numel(names),values(k)=struct('name',names{k},'value',getVariable(ws,names{k}));end
end
function close_private(mdl,child)
if bdIsLoaded(mdl),close_system(mdl,0);end
if ~isempty(child)&&bdIsLoaded(child),close_system(child,0);end
end
