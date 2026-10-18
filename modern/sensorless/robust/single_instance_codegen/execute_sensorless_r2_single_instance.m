function report=execute_sensorless_r2_single_instance(buildFolder,folder)
% Reopen the serialized hierarchy in a separate stopped MATLAB process.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);
for part={'','sensorless','sensorless/robust','sensorless/robust/integration','sensorless/robust/performance','sensorless/robust/execution_v3',...
 'sensorless/robust/phase_guard','sensorless/robust/faults','sensorless/robust/scenarios','sensorless/robust/literal_plant',...
 'sensorless/robust/execution_v8','sensorless/robust/constructor','sensorless/robust/model_reference','sensorless/robust/generated_backend','sensorless/robust/portable_model','sensorless/robust/portable_execution','sensorless/robust/continuous_codegen','sensorless/robust/single_instance_codegen','teaching','control','timing','deadtime','framework','layout/appearance'}
 addpath(fullfile(modern,part{1}));
end
assert(~isfolder(folder));mkdir(folder);loaded=load(fullfile(buildFolder,'handoff.mat'),'state');state=loaded.state;mdl=state.mdl;child=state.child;
assert(~bdIsLoaded(mdl)&&~bdIsLoaded(child));cleanup=onCleanup(@()close_private(mdl,child));
record=jsondecode(fileread(fullfile(buildFolder,'record.json')));assert(strcmp(record.status,'passed'));
assert(strcmp(record.handoff_sha256,teach_hash(fullfile(buildFolder,'handoff.mat'))));
buildRecord=record;record.folder=strrep(folder,'\','/');record.builder_process_id=buildRecord.process_id;record.process_id=matlabProcessID;record.status='running';
copyfile(fullfile(buildFolder,'source'),fullfile(folder,'source'));mkdir(fullfile(folder,'contracts'));
for k=1:numel(record.contracts)
 target=fullfile(folder,record.contracts(k).path);if ~isfolder(fileparts(target)),mkdir(fileparts(target));end
 copyfile(fullfile(buildFolder,record.contracts(k).path),target);
end
record.builder_proof=struct('layer_restored',buildRecord.layer_restored,'reference_restored',buildRecord.reference_restored,...
 'callbacks_restored',buildRecord.callbacks_restored,'saved_exports_unchanged',buildRecord.saved_exports_unchanged,'bridge_metadata_restored',buildRecord.bridge_metadata_restored);
record.layer_restored=false;record.reference_restored=false;record.callback_restored=false;record.callbacks_restored=false;
record.saved_exports_unchanged=false;record.bridge_metadata_restored=false;record.native_endpoint_verified=false;record.metrics_passed=false;
sensorless_v2_guard_sources(record);
copyfile(fullfile(buildFolder,'direct_graph.json'),fullfile(folder,'direct_graph.json'));
copyfile(fullfile(buildFolder,'handoff.mat'),fullfile(folder,'handoff.mat'));
report=struct('kind','single_instance_continuous_codegen_adapter','phase','load','all_passed',false,...
 'process_id',matlabProcessID,'builder_process_id',buildRecord.process_id,'matlab_version',version,...
 'simulation_starts',0,'compile_requested',false,'R2_passed',false);
assert(report.process_id~=report.builder_process_id);
assert(strcmp(version,record.matlab_version));record.stopped_handoff_only=false;
copyfile([mfilename('fullpath') '.m'],fullfile(folder,'probe_source.m.txt'));report.probe_sha256=teach_hash([mfilename('fullpath') '.m']);
try
 assert(strcmp(teach_hash(state.parentFile),state.parent_sha256)&&strcmp(teach_hash(state.reference.child_file),state.child_sha256));
 addpath(fileparts(state.reference.child_file));stage('before_parent_load');load_system(state.parentFile);stage('after_parent_load');
 if ~bdIsLoaded(child),stage('before_child_load');load_system(state.reference.child_file);end
 set_param(0,'CurrentSystem',mdl);stage('check_serialized_state');
 ws=get_param(mdl,'ModelWorkspace');childWs=get_param(child,'ModelWorkspace');
 report.parent_model_file_source=strcmp(ws.DataSource,'Model File');report.child_model_file_source=strcmp(childWs.DataSource,'Model File');
 report.parent_exact=isequaln(state.parentWorkspace,values(ws));report.child_exact=isequaln(state.childWorkspace,values(childWs));
 report.workspace_count=numel(values(ws));report.callbacks_empty=isempty(get_param(mdl,'InitFcn'))&&isempty(get_param(mdl,'PreSaveFcn'))&&isempty(get_param(child,'InitFcn'));
 root=[mdl '/无感观测'];report.backup_exact=isequaln(state.backup,get_param(root,'UserData'));
 report.backup_persistent=strcmp(get_param(root,'UserDataPersistent'),'on');
 graph=check_sensorless_r2_generated_graph(mdl,state.configured,state.reference);teach_writejson(fullfile(folder,'graph.json'),graph);
 report.graph_passed=graph.passed;
 assert(report.parent_model_file_source&&report.child_model_file_source&&report.parent_exact&&report.child_exact&&report.workspace_count==86&&report.callbacks_empty&&report.backup_exact&&report.backup_persistent&&report.graph_passed);
 report.bridge_adaptation_verified=sensorless_r2_bridge_codegen('verify',mdl,state.bridgeBackup);assert(report.bridge_adaptation_verified);
 references=find_system(mdl,'LookUnderMasks','all','BlockType','ModelReference','ModelName',child);
 report.single_reference_metadata_verified=numel(references)==1&&strcmp(get_param(child,'ModelReferenceNumInstancesAllowed'),'Single');assert(report.single_reference_metadata_verified);
 report.compile_requested=true;stage('prepare_continuous_codegen');
 generation=fullfile(base,'.build','single_instance_codegen',char(java.util.UUID.randomUUID));
 Simulink.fileGenControl('set','CacheFolder',fullfile(generation,'c'),'CodeGenFolder',fullfile(generation,'g'),'createDir',true);
 record.generation_paths=struct('cache',fullfile(generation,'c'),'codegen',fullfile(generation,'g'));
 record.compiler=struct('C',compiler_info('C'),'CXX',compiler_info('C++'),'private_preferences',prefdir);
 report.normal_compile_pairs_requested=1;stage('verify_actual_continuous_rate');
 feval(mdl,[],[],[],'compile');terminate=onCleanup(@()feval(mdl,[],[],[],'term'));
 report.bridge_compiled_sample_time=get_param([mdl '/Universal Bridge/续流'],'CompiledSampleTime');assert(isequal(report.bridge_compiled_sample_time,[0 0]));
 clear terminate;
 assert(isequaln(state.parentWorkspace,values(ws))&&isequaln(state.childWorkspace,values(childWs)));
 stage('build_generated_target_once');
 rtp=Simulink.BlockDiagram.buildRapidAcceleratorTarget(mdl);save(fullfile(folder,'runtime_parameters.mat'),'rtp');
 record.generated_target=target_inventory(generation,folder,mdl);
 record.workspace_unchanged_by_compile=isequaln(state.parentWorkspace,values(ws))&&isequaln(state.childWorkspace,values(childWs));assert(record.workspace_unchanged_by_compile);
 report.simulation_starts=1;record.simulation_starts=1;stage('execute_generated_target_once');timer=tic;testcase=record.effective_case;
 out=sim(mdl,'SimulationMode','rapid-accelerator','StopTime',num2str(testcase.duration_s,17));record.elapsed_s=toc(timer);assert(isempty(out.ErrorMessage));
 stage('archive_before_postprocessing');signals=struct;
 for key=out.who',series=out.get(key{1});if isa(series,'timeseries'),signals.(key{1})=series;end,end
 save(fullfile(folder,'signals.mat'),'-struct','signals','-v7.3');record.raw_sha256=teach_hash(fullfile(folder,'signals.mat'));record.log_count=numel(fieldnames(signals));
 for key=fieldnames(signals)',series=signals.(key{1});assert(all(isfinite(series.Time),'all')&&all(isfinite(series.Data),'all'));end
 counters=signals.obs_sless_r2_native_counters;data=teach_values(counters);
 record.native_endpoint_verified=abs(counters.Time(end)-testcase.duration_s)<1e-12&&abs(data(end,1)-testcase.duration_s)<1e-12&&data(end,12)==round(testcase.duration_s/62.5e-9)+1;assert(record.native_endpoint_verified);
 record.workspace_unchanged_by_simulation=isequaln(state.parentWorkspace,values(ws))&&isequaln(state.childWorkspace,values(childWs));assert(record.workspace_unchanged_by_simulation);clear out;
 record.execution=struct('mode','rapid-accelerator','single_sim_call',true,'duration_s',testcase.duration_s,'no_graph_construction_in_executor',true,'continuous_bridge_inheritance_verified',true);
 stage('restore_from_persisted_backup');ws.DataSource=state.parentDataSource;ws.MATLABCode=state.parentCode;
 sensorless_r2_reference_model('remove',mdl);report.layer_restored=isequaln(state.configured,teach_snapshot(mdl));assert(report.layer_restored);
 if ~isempty(state.pwm),sensorless_r2_restore_fault_pwm(state.pwm);end
 if ~isempty(state.plant),sensorless_r2_restore_literals(mdl,state.plant);end
 record.bridge_metadata_restored=sensorless_r2_bridge_codegen('restore',mdl,state.bridgeBackup);assert(record.bridge_metadata_restored);
 set_param(mdl,'InitFcn',state.originalInit);if ~isempty(state.dynamic),sensorless_n3_restore(mdl,state.dynamic);end
 sensorless_n3_restore(mdl,state.stimulus);
 report.original_restored=isequaln(state.original,teach_snapshot(mdl))&&isequaln(state.fixed,pmsm_reference('capture'));assert(report.original_restored);
 report.files_unchanged=strcmp(teach_hash(state.parentFile),state.parent_sha256)&&strcmp(teach_hash(state.reference.child_file),state.child_sha256);
 assert(report.files_unchanged);sensorless_v2_guard_sources(record);
 record.saved_exports_unchanged=report.files_unchanged;record.callbacks_restored=strcmp(get_param(mdl,'InitFcn'),state.originalInit);
 record.layer_restored=report.layer_restored;record.reference_restored=report.original_restored;record.callback_restored=strcmp(get_param(mdl,'InitFcn'),state.originalInit);
 original=state.original;save(fullfile(folder,'restoration.mat'),'original','-v7.3');
 stage('metrics');if ismember(record.case_id,{'missing_five','reset_one','deadline_jitter'}),metrics=analyse_sensorless_r2_fault(signals,testcase);else,metrics=analyse_sensorless_r2_scenario(signals,testcase);end
 teach_writejson(fullfile(folder,'metrics.json'),metrics);record.metrics_passed=metrics.all_passed;record.phase='completed';record.status='completed_performance_failed';if metrics.all_passed,record.status='passed';end
 report.all_passed=metrics.all_passed;report.phase='completed';teach_writejson(fullfile(folder,'report.json'),report);teach_writejson(fullfile(folder,'record.json'),record);
catch err
 report.phase_at_error=report.phase;report.phase='failed';report.error_identifier=err.identifier;teach_writejson(fullfile(folder,'report.json'),report);record.status='failed_execution';record.error=getReport(err,'extended','hyperlinks','off');teach_writejson(fullfile(folder,'record.json'),record);rethrow(err);
end
 function stage(label),report.phase=label;record.phase=label;teach_writejson(fullfile(folder,'record.json'),record);teach_writejson(fullfile(folder,'report.json'),report);fprintf('STAGED_EXECUTION %s\n',label);end
end
function result=values(ws)
entries=whos(ws);names=sort({entries.name});result=repmat(struct('name','','value',[]),numel(names),1);
for k=1:numel(names),result(k)=struct('name',names{k},'value',getVariable(ws,names{k}));end
end
function close_private(mdl,child)
if bdIsLoaded(mdl),close_system(mdl,0);end
if bdIsLoaded(child),close_system(child,0);end
end

function info=compiler_info(language)
configs=mex.getCompilerConfigurations(language,'Selected');assert(numel(configs)==1);c=configs(1);info=struct('name',c.Name,'version',c.Version,'manufacturer',c.Manufacturer,'location',c.Location);
end
function result=target_inventory(build,folder,mdl)
files=dir(fullfile(build,'**','*'));entries=repmat(struct('path','','sha256',''),0,1);hasParent=false;
for k=1:numel(files)
 if files(k).isdir,continue;end
 [~,name,ext]=fileparts(files(k).name);if ~ismember(ext,{'.dll','.mk','.c','.h','.rtw','.tlc'}),continue;end
 file=fullfile(files(k).folder,files(k).name);relative=strrep(strrep(file,[build filesep],''),'\','/');entries(end+1)=struct('path',relative,'sha256',teach_hash(file)); %#ok<AGROW>
 if strcmp(name,mdl)&&strcmp(ext,'.dll'),hasParent=true;end
end
assert(hasParent);result=struct('folder',build,'files',entries,'parent_target_exists',hasParent);teach_writejson(fullfile(folder,'generated_target_inventory.json'),result);
end
