function record=build_sensorless_r2_continuous(id,folder)
% One source implementation for development precheck and later frozen matrix.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);mdl='PMSM_FOC_R2026a';
for part={'','sensorless','sensorless/robust','sensorless/robust/integration','sensorless/robust/performance','sensorless/robust/execution_v3',...
 'sensorless/robust/phase_guard','sensorless/robust/faults','sensorless/robust/scenarios','sensorless/robust/literal_plant',...
 'sensorless/robust/execution_v8','sensorless/robust/constructor','sensorless/robust/model_reference','sensorless/robust/generated_backend','sensorless/robust/portable_model','sensorless/robust/portable_execution','sensorless/robust/continuous_codegen','teaching','control','timing','deadtime','framework','layout/appearance'}
 addpath(fullfile(modern,part{1}));
end
assert(~bdIsLoaded(mdl));record=sensorless_r2_continuous_snapshot(folder);record.case_id=id;record.process_id=matlabProcessID;
plan=jsondecode(fileread(fullfile(base,'contracts/nonideal_r2_test_plan.json')));cases=plan.cases;if ~iscell(cases),cases=num2cell(cases);end
selected=cellfun(@(x)strcmp(x.id,id),cases);assert(sum(selected)==1);testcase=cases{selected};record.effective_case=testcase;
build=fullfile(base,'.build','generated_backend',char(java.util.UUID.randomUUID));assert(~isfolder(build));
record.generation_paths=struct('cache',fullfile(build,'c'),'codegen',fullfile(build,'g'),'isolated_per_attempt',true);
Simulink.fileGenControl('set','CacheFolder',record.generation_paths.cache,'CodeGenFolder',record.generation_paths.codegen,'createDir',true);
token=strrep(char(java.util.UUID.randomUUID),'-','');child=['sr2_' token(1:8)];cleanup=onCleanup(@()close_private(mdl,child));
try
 sensorless_r2_verify_constructor;record=stage(record,folder,'load');parentFolder=fullfile(folder,'parent');mkdir(parentFolder);parentFile=fullfile(parentFolder,[mdl '.slx']);
 copyfile(fullfile(modern,[mdl '.slx']),parentFile);assert(strcmp(teach_hash(parentFile),record.model_sha256));
 record.owned_parent_file=parentFile;load_system(parentFile);assert(strcmp(get_param(mdl,'FileName'),parentFile));
 set_param(0,'CurrentSystem',mdl);assert(strcmp(bdroot,mdl));pmsm_reference_geometry('restore');
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
 bridgeBackup=sensorless_r2_bridge_codegen('apply',mdl);record.bridge_adaptation=bridgeBackup;
 configured=teach_snapshot(mdl);record=stage(record,folder,'construct_direct_stopped');pmsm_sensorless_v2_geometry_model('install',mdl,0);
 if isfield(testcase,'speed_rpm')&&testcase.speed_rpm<0,set_param([mdl '/无感观测'],'direction','-1');end
 record.phase_guard=sensorless_r2_phase_guard_model(mdl);record.logging=sensorless_r2_logging(mdl);set_param([mdl '/无感观测/观测/R2累计记录'],'SampleTime','50e-6');
 record.fault_adapter=sensorless_r2_fault_model(mdl,testcase);if strcmp(id,'deadline_jitter'),sensorless_r2_pwm_event_logging(mdl);end
 record.observer_initialization=sensorless_r2_initialize_stopped(mdl);graph=check_sensorless_v2_graph(mdl,configured);assert(graph.passed);teach_writejson(fullfile(folder,'direct_graph.json'),graph);
 record=stage(record,folder,'convert_reference');record.reference_adapter=sensorless_r2_reference_model('install',mdl,folder,child);
 record.reference_adapter.original_inherited_type_child_sha256=record.reference_adapter.child_model_sha256;
 for k=1:numel(record.reference_adapter.interface)
  port=[child '/输入_' record.reference_adapter.interface(k).name];set_param(port,'OutDataTypeStr','double');
 end
 save_system(child,record.reference_adapter.child_file);record.reference_adapter.child_model_sha256=teach_hash(record.reference_adapter.child_file);
 backupRoot=get_param([mdl '/无感观测'],'UserData');backupRoot.reference_adapter=record.reference_adapter;set_param([mdl '/无感观测'],'UserData',backupRoot);
 ws=get_param(mdl,'ModelWorkspace');childWs=get_param(child,'ModelWorkspace');before=workspace_values(ws);childBefore=workspace_values(childWs);assert(isequaln(before,childBefore));
 record.config_vector=getVariable(ws,'sless_v2_cfg');record.observer_config=getVariable(ws,'sless_cfg');record.configuration=teach_settings(mdl);
 if isfield(testcase,'plant_R_multiplier')
  accepted=jsondecode(fileread(fullfile(base,'milestones/N3R2/followup_20261017/v4_r1_short_logging_check_record.json')));
  record.observer_nominal_preserved=isequaln(record.config_vector(:),accepted.config_vector(:))&&isequaln(record.observer_config(:),accepted.observer_config(:));assert(record.observer_nominal_preserved);
 end
 record=stage(record,folder,'persist_owned_hierarchy');
 state=struct('mdl',mdl,'child',child,'parentFile',parentFile,'original',original,'configured',configured,'fixed',fixed,...
  'originalInit',originalInit,'stimulus',backup,'reference',record.reference_adapter,...
  'parentWorkspace',before,'childWorkspace',childBefore,'parentDataSource',ws.DataSource,'parentCode',ws.MATLABCode,...
  'dynamic',dynamic,'pwm',pwm,'plant',plant,'bridgeBackup',bridgeBackup);
 state.persisted=sensorless_r2_portable_storage(mdl,child,parentFile,record.reference_adapter);
 record.reference_adapter=state.persisted.reference;
 state.reference=record.reference_adapter;state.backup=get_param([mdl '/无感观测'],'UserData');
 state.parent_sha256=teach_hash(parentFile);state.child_sha256=teach_hash(state.reference.child_file);
 save(fullfile(folder,'handoff.mat'),'state','-v7.3');record.handoff_sha256=teach_hash(fullfile(folder,'handoff.mat'));
 record.exported_parent_sha256=state.parent_sha256;record.exported_child_sha256=state.child_sha256;
 graph=check_sensorless_r2_generated_graph(mdl,configured,state.reference);assert(graph.passed);teach_writejson(fullfile(folder,'graph.json'),graph);
 record=stage(record,folder,'prove_owned_restoration');
 ws.DataSource=state.parentDataSource;ws.MATLABCode=state.parentCode;
 sensorless_r2_reference_model('remove',mdl);record.layer_restored=isequaln(configured,teach_snapshot(mdl));assert(record.layer_restored);
 if ~isempty(pwm),sensorless_r2_restore_fault_pwm(pwm);end
 if ~isempty(plant),sensorless_r2_restore_literals(mdl,plant);end
 record.bridge_metadata_restored=sensorless_r2_bridge_codegen('restore',mdl,bridgeBackup);assert(record.bridge_metadata_restored);
 set_param(mdl,'InitFcn',originalInit);if ~isempty(dynamic),sensorless_n3_restore(mdl,dynamic);end
 sensorless_n3_restore(mdl,backup);
 record.reference_restored=isequaln(original,teach_snapshot(mdl))&&isequaln(fixed,pmsm_reference('capture'));assert(record.reference_restored);
 record.callbacks_restored=strcmp(get_param(mdl,'InitFcn'),originalInit);assert(record.callbacks_restored);
 sensorless_v2_guard_sources(record);sensorless_r2_verify_constructor;
 record.saved_exports_unchanged=strcmp(teach_hash(parentFile),state.parent_sha256)&&strcmp(teach_hash(state.reference.child_file),state.child_sha256);assert(record.saved_exports_unchanged);
 record.phase='completed';record.status='passed';record.stopped_handoff_only=true;record.simulation_starts=0;record.R2_passed=false;
 teach_writejson(fullfile(folder,'record.json'),record);fprintf('STAGED_R2_BUILD passed=1\n');
catch err
 record.status='failed_execution';record.error=getReport(err,'extended','hyperlinks','off');teach_writejson(fullfile(folder,'record.json'),record);
 rethrow(err);
end
end
function record=stage(record,folder,name)
record.phase=name;teach_writejson(fullfile(folder,'record.json'),record);fprintf('STAGED_R2_PHASE %s %s\n',record.case_id,name);
end
function values=workspace_values(ws)
entries=whos(ws);names=sort({entries.name});values=repmat(struct('name','','value',[]),numel(names),1);
for k=1:numel(names),values(k)=struct('name',names{k},'value',getVariable(ws,names{k}));end
end
function close_private(mdl,child)
if bdIsLoaded(mdl),close_system(mdl,0);end
if ~isempty(child)&&bdIsLoaded(child),close_system(child,0);end
end
