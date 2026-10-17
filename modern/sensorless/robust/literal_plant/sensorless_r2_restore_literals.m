function sensorless_r2_restore_literals(mdl,backup)
assert(strcmp(get_param(mdl,'SimulationStatus'),'stopped'));
for entry=backup.expressions(:)',set_param(entry.path,'Expr',entry.value);end
end
