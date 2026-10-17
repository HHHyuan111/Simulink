function sensorless_r2_restore_fault_pwm(backup)
rt=sfroot;c=rt.find('-isa','Stateflow.EMChart','Path',backup.path);ports=get_param(backup.constant,'PortHandles');
delete_line(get_param(ports.Outport,'Line'));delete_block(backup.constant);c.Script=backup.script;
% Editing a MATLAB Function signature can shift its internal SFunction5px.
% Restore the captured layout as well as script and connections.
for item=backup.layout(:)',set_param(item.path,'Position',item.position);end
end
