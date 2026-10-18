function report=verify_sensorless_r2_portable(buildFolder,folder)
% Reopen the serialized hierarchy in a separate stopped MATLAB process.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);
for part={'','sensorless','sensorless/robust','sensorless/robust/integration','sensorless/robust/performance','sensorless/robust/execution_v3',...
 'sensorless/robust/phase_guard','sensorless/robust/faults','sensorless/robust/scenarios','sensorless/robust/literal_plant',...
 'sensorless/robust/execution_v8','sensorless/robust/constructor','sensorless/robust/model_reference','sensorless/robust/generated_backend','sensorless/robust/portable_model','teaching','control','timing','deadtime','framework','layout/appearance'}
 addpath(fullfile(modern,part{1}));
end
assert(~isfolder(folder));mkdir(folder);loaded=load(fullfile(buildFolder,'handoff.mat'),'state');state=loaded.state;mdl=state.mdl;child=state.child;
assert(~bdIsLoaded(mdl)&&~bdIsLoaded(child));cleanup=onCleanup(@()close_private(mdl,child));
record=jsondecode(fileread(fullfile(buildFolder,'record.json')));assert(strcmp(record.status,'passed'));
assert(strcmp(record.handoff_sha256,teach_hash(fullfile(buildFolder,'handoff.mat'))));
report=struct('kind','independent_portable_model_reopen','phase','load','all_passed',false,...
 'process_id',matlabProcessID,'builder_process_id',record.process_id,'matlab_version',version,...
 'simulation_starts',0,'compile_requested',false,'R2_passed',false);
assert(report.process_id~=report.builder_process_id);
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
 stage('restore_from_persisted_backup');ws.DataSource=state.parentDataSource;ws.MATLABCode=state.parentCode;
 sensorless_r2_reference_model('remove',mdl);report.layer_restored=isequaln(state.configured,teach_snapshot(mdl));assert(report.layer_restored);
 set_param(mdl,'InitFcn',state.originalInit);sensorless_n3_restore(mdl,state.stimulus);
 report.original_restored=isequaln(state.original,teach_snapshot(mdl))&&isequaln(state.fixed,pmsm_reference('capture'));assert(report.original_restored);
 report.files_unchanged=strcmp(teach_hash(state.parentFile),state.parent_sha256)&&strcmp(teach_hash(state.reference.child_file),state.child_sha256);
 assert(report.files_unchanged);sensorless_v2_guard_sources(record);report.all_passed=true;stage('completed');
catch err
 report.phase_at_error=report.phase;report.phase='failed';report.error_identifier=err.identifier;teach_writejson(fullfile(folder,'report.json'),report);rethrow(err);
end
 function stage(label),report.phase=label;teach_writejson(fullfile(folder,'report.json'),report);fprintf('PORTABLE_REOPEN %s\n',label);end
end
function result=values(ws)
entries=whos(ws);names=sort({entries.name});result=repmat(struct('name','','value',[]),numel(names),1);
for k=1:numel(names),result(k)=struct('name',names{k},'value',getVariable(ws,names{k}));end
end
function close_private(mdl,child)
if bdIsLoaded(mdl),close_system(mdl,0);end
if bdIsLoaded(child),close_system(child,0);end
end
