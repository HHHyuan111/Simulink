function sensorless_r2_restore_plant(mdl,backup)
assert(strcmp(get_param(mdl,'SimulationStatus'),'stopped'));
for entry=backup.expressions(:)',set_param(entry.path,'Expr',entry.value);end
ws=get_param(mdl,'ModelWorkspace');clear(ws);
for entry=backup.workspace(:)',assignin(ws,entry.name,entry.value);end
end
