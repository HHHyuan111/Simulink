function record=validate_sensorless_r2_generated_case(id,folder)
% One source implementation for development precheck and later frozen matrix.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);mdl='PMSM_FOC_R2026a';
for part={'','sensorless','sensorless/robust','sensorless/robust/integration','sensorless/robust/performance','sensorless/robust/execution_v3',...
 'sensorless/robust/phase_guard','sensorless/robust/faults','sensorless/robust/scenarios','sensorless/robust/literal_plant',...
 'sensorless/robust/execution_v8','sensorless/robust/constructor','sensorless/robust/model_reference','sensorless/robust/generated_backend','teaching','control','timing','deadtime','framework','layout/appearance'}
 addpath(fullfile(modern,part{1}));
end
assert(~bdIsLoaded(mdl));record=sensorless_r2_generated_snapshot(folder);record.case_id=id;record.process_id=matlabProcessID;
plan=jsondecode(fileread(fullfile(base,'contracts/nonideal_r2_test_plan.json')));cases=plan.cases;if ~iscell(cases),cases=num2cell(cases);end
selected=cellfun(@(x)strcmp(x.id,id),cases);assert(sum(selected)==1);testcase=cases{selected};record.effective_case=testcase;
build=fullfile(base,'.build','generated_backend',char(java.util.UUID.randomUUID));assert(~isfolder(build));
record.generation_paths=struct('cache',fullfile(build,'c'),'codegen',fullfile(build,'g'),'isolated_per_attempt',true);
Simulink.fileGenControl('set','CacheFolder',record.generation_paths.cache,'CodeGenFolder',record.generation_paths.codegen,'createDir',true);
sldiagviewer.diary(fullfile(folder,'diagnostics.log'),'UTF-8');token=strrep(char(java.util.UUID.randomUUID),'-','');child=['sr2_' token(1:8)];cleanup=onCleanup(@()close_private(mdl,child));
try
 sensorless_r2_verify_constructor;record=stage(record,folder,'load');parentFolder=fullfile(folder,'parent');mkdir(parentFolder);parentFile=fullfile(parentFolder,[mdl '.slx']);
 copyfile(fullfile(modern,[mdl '.slx']),parentFile);assert(strcmp(teach_hash(parentFile),record.model_sha256));
 record.owned_parent_file=parentFile;load_system(parentFile);assert(strcmp(get_param(mdl,'FileName'),parentFile));pmsm_reference_geometry('restore');
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
 record=stage(record,folder,'save_owned_hierarchy');save_system(mdl,parentFile);record.owned_parent_configured_sha256=teach_hash(parentFile);
 assert(isequaln(before,workspace_values(ws))&&isequaln(childBefore,workspace_values(childWs)));
 graph=check_sensorless_r2_generated_graph(mdl,configured,record.reference_adapter);teach_writejson(fullfile(folder,'graph.json'),graph);assert(graph.passed);
 record=stage(record,folder,'build_generated_target_once');
 record.compiler=struct('C',compiler_info('C'),'CXX',compiler_info('C++'),'private_preferences',prefdir);
 rtp=Simulink.BlockDiagram.buildRapidAcceleratorTarget(mdl);save(fullfile(folder,'runtime_parameters.mat'),'rtp');
 record.generated_target=target_inventory(build,folder,mdl,child);record.workspace_unchanged_by_compile=isequaln(before,workspace_values(ws))&&isequaln(childBefore,workspace_values(childWs));assert(record.workspace_unchanged_by_compile);
 record=stage(record,folder,'execute_generated_target_once');timer=tic;
 out=sim(mdl,'SimulationMode','rapid-accelerator','StopTime',num2str(testcase.duration_s,17));record.elapsed_s=toc(timer);assert(isempty(out.ErrorMessage));
 record.execution=struct('mode','rapid-accelerator','single_sim_call',true,'duration_s',testcase.duration_s,'elapsed_s',record.elapsed_s,'no_chunk_reinitialization',true);
 record=stage(record,folder,'archive_before_postprocessing');signals=struct;
 for key=out.who'
  series=out.get(key{1});if isa(series,'timeseries'),signals.(key{1})=series;end
 end
 save(fullfile(folder,'signals.mat'),'-struct','signals','-v7.3');record.raw_sha256=teach_hash(fullfile(folder,'signals.mat'));record.log_count=numel(fieldnames(signals));
 for key=fieldnames(signals)',series=signals.(key{1});assert(all(isfinite(series.Time),'all')&&all(isfinite(series.Data),'all'));end
 endpoint=out.get('obs_sless_r2_native_counters');native=teach_values(endpoint);record.native_endpoint_verified=abs(endpoint.Time(end)-testcase.duration_s)<1e-12&&abs(native(end,1)-testcase.duration_s)<1e-12&&native(end,12)==round(testcase.duration_s/62.5e-9)+1;assert(record.native_endpoint_verified);
 afterSimulation=workspace_values(ws);childAfterSimulation=workspace_values(childWs);record.workspace_unchanged_by_simulation=isequaln(before,afterSimulation)&&isequaln(childBefore,childAfterSimulation);assert(record.workspace_unchanged_by_simulation);
 clear out;record.owned_model_files_unchanged=strcmp(teach_hash(parentFile),record.owned_parent_configured_sha256);assert(record.owned_model_files_unchanged);
 assert(strcmp(teach_hash(record.reference_adapter.child_file),record.reference_adapter.child_model_sha256));
 record=stage(record,folder,'restore');sensorless_r2_reference_model('remove',mdl);afterLayer=teach_snapshot(mdl);record.layer_restored=isequaln(configured,afterLayer);
 if ~isempty(pwm),sensorless_r2_restore_fault_pwm(pwm);end
 if ~isempty(plant),sensorless_r2_restore_literals(mdl,plant);end
 set_param(mdl,'InitFcn',originalInit);if ~isempty(dynamic),sensorless_n3_restore(mdl,dynamic);end
 sensorless_n3_restore(mdl,backup);afterModel=teach_snapshot(mdl);afterFixed=pmsm_reference('capture');
 record.callback_restored=strcmp(get_param(mdl,'InitFcn'),originalInit);record.reference_restored=isequaln(original,afterModel)&&isequaln(fixed,afterFixed);
 record.block_reduction=struct('effective','on','restored',strcmp(get_param(mdl,'BlockReduction'),originalReduction));
 assert(record.layer_restored&&record.callback_restored&&record.reference_restored&&record.block_reduction.restored);sensorless_v2_guard_sources(record);sensorless_r2_verify_constructor;assert(strcmp(teach_hash(fullfile(modern,[mdl '.slx'])),record.model_sha256));
 save(fullfile(folder,'restoration.mat'),'original','configured','afterLayer','afterModel','fixed','afterFixed','before','afterSimulation','childBefore','childAfterSimulation','-v7.3');
 record=stage(record,folder,'metrics');
 if ismember(id,{'missing_five','reset_one','deadline_jitter'}),metrics=analyse_sensorless_r2_fault(signals,testcase);
 else,metrics=analyse_sensorless_r2_scenario(signals,testcase);end
 teach_writejson(fullfile(folder,'metrics.json'),metrics);record.phase='completed';record.metrics_passed=metrics.all_passed;record.status='completed_performance_failed';if metrics.all_passed,record.status='passed';end
 teach_writejson(fullfile(folder,'record.json'),record);fprintf('R2_GENERATED_COMPLETED %s passed=%d elapsed=%g\n',id,metrics.all_passed,record.elapsed_s);
catch err
 record.status='failed_execution';record.error=getReport(err,'extended','hyperlinks','off');teach_writejson(fullfile(folder,'record.json'),record);
 rethrow(err);
end
end
function record=stage(record,folder,name)
record.phase=name;teach_writejson(fullfile(folder,'record.json'),record);fprintf('R2_GENERATED_PHASE %s %s\n',record.case_id,name);
end
function values=workspace_values(ws)
entries=whos(ws);names=sort({entries.name});values=repmat(struct('name','','value',[]),numel(names),1);
for k=1:numel(names),values(k)=struct('name',names{k},'value',getVariable(ws,names{k}));end
end
function close_private(mdl,child)
if bdIsLoaded(mdl),close_system(mdl,0);end
if ~isempty(child)&&bdIsLoaded(child),close_system(child,0);end
end

function info=compiler_info(language)
configs=mex.getCompilerConfigurations(language,'Selected');assert(numel(configs)==1);c=configs(1);
info=struct('name',c.Name,'version',c.Version,'manufacturer',c.Manufacturer,'location',c.Location);
end
function result=target_inventory(build,folder,mdl,child)
files=dir(fullfile(build,'**','*'));entries=repmat(struct('path','','sha256',''),0,1);hasParent=false;
for k=1:numel(files)
 if files(k).isdir,continue;end
 [~,name,ext]=fileparts(files(k).name);
 if ~ismember(ext,{'.dll','.mk','.c','.h','.rtw','.tlc'}),continue;end
 file=fullfile(files(k).folder,files(k).name);relative=strrep(strrep(file,[build filesep],''),'\','/');
 entries(end+1)=struct('path',relative,'sha256',teach_hash(file)); %#ok<AGROW>
 if strcmp(name,mdl)&&strcmp(ext,'.dll'),hasParent=true;end
end
assert(hasParent,'Generated parent model DLL is missing.');result=struct('folder',build,'files',entries,'parent_target_exists',hasParent,'child_model',child,'no_claim_of_queried_compiled_port_dimensions',true);
teach_writejson(fullfile(folder,'generated_target_inventory.json'),result);
end
