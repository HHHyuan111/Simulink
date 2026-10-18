function result=sensorless_r2_portable_storage(mdl,child,parentFile,reference)
% Persist only an attempt-owned hierarchy; never weaken the source save guard.
root=[mdl '/无感观测'];loaded=get_param(mdl,'FileName');
assert(strcmpi(char(java.io.File(loaded).getCanonicalPath),char(java.io.File(parentFile).getCanonicalPath)));
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));allowed=char(java.io.File(fullfile(base,'runs')).getCanonicalPath);
assert(startsWith(lower(char(java.io.File(parentFile).getCanonicalPath)),[lower(allowed) filesep]));
expectedGuard='error(''sensorless:SaveGuard'',''请先退出无感观测，再保存原模型。'');';
guard=get_param(mdl,'PreSaveFcn');assert(strcmp(guard,expectedGuard),'Unexpected save callback: export stopped.');
assert(isempty(get_param(mdl,'InitFcn'))&&isempty(get_param(child,'InitFcn')));
ws=get_param(mdl,'ModelWorkspace');childWs=get_param(child,'ModelWorkspace');parentValues=values(ws);childValues=values(childWs);
assert(numel(parentValues)==86&&isequaln(parentValues,childValues));
result=struct('kind','exact_model_file_workspace_handoff','original_data_source',ws.DataSource,...
 'original_code',ws.MATLABCode,'owned_guard_before',guard,'guard_cleared_only_on_owned_copy',true);
ws.DataSource='Model File';clear(ws);assign_values(ws,parentValues);
childWs.DataSource='Model File';clear(childWs);assign_values(childWs,childValues);
assert(isequaln(parentValues,values(ws))&&isequaln(childValues,values(childWs)));
save_system(child,reference.child_file);reference.child_model_sha256=teach_hash(reference.child_file);
backup=get_param(root,'UserData');backup.reference_adapter=reference;set_param(root,'UserData',backup,'UserDataPersistent','on');
set_param(mdl,'PreSaveFcn','');save_system(mdl,parentFile);
assert(isequaln(parentValues,values(ws))&&isequaln(childValues,values(childWs)));
result.reference=reference;result.parent_workspace_count=numel(parentValues);result.child_workspace_count=numel(childValues);
result.exact_values_preserved=true;result.restore_backup_persistent=strcmp(get_param(root,'UserDataPersistent'),'on');
assert(result.restore_backup_persistent);
end
function result=values(ws)
entries=whos(ws);names=sort({entries.name});result=repmat(struct('name','','value',[]),numel(names),1);
for k=1:numel(names),result(k)=struct('name',names{k},'value',getVariable(ws,names{k}));end
end
function assign_values(ws,entries)
for k=1:numel(entries),assignin(ws,entries(k).name,entries(k).value);end
end
