function record=sensorless_r2_initialize_stopped(mdl)
% Run the exact trusted model callback while stopped, then disable it for
% compilation. No model-context substitution and no numerical edits.
assert(strcmp(get_param(mdl,'SimulationStatus'),'stopped'));
assert(strcmp(bdroot,mdl),'sensorless:R2RootContext','Unexpected root outside compilation.');
initializationText=get_param(mdl,'InitFcn');assert(~isempty(initializationText));
eval(initializationText);
first=workspace_values(get_param(mdl,'ModelWorkspace'));
eval(initializationText);
second=workspace_values(get_param(mdl,'ModelWorkspace'));
assert(isequaln(first,second),'sensorless:R2InitIdempotence','Initialization is not idempotent.');
record=struct('exact_callback',initializationText,'initialization_outside_compile',true,...
 'idempotent_workspace',true,'variables',numel(first));
set_param(mdl,'InitFcn','');
end
function values=workspace_values(ws)
entries=whos(ws);names=sort({entries.name});values=struct('name',{},'value',{});
for k=1:numel(names),values(k)=struct('name',names{k},'value',getVariable(ws,names{k}));end
end
