function sensorless_n3_restore(mdl,backup)
% Restore stimulus, workspace and numerical settings after observer removal.
for d=backup.destinations(:)'
 line=get_param(d,'Line');if line>=0,delete_line(line);end
end
for k=numel(backup.added):-1:1
 ph=get_param(backup.added{k},'PortHandles');ports=[ph.Inport ph.Outport];
 lines=unique(arrayfun(@(p)get_param(p,'Line'),ports));
 for line=lines(lines>=0),delete_line(line);end
 delete_block(backup.added{k});
end
if ~isempty(backup.destinations)
 ph=get_param([mdl '/speed_ref'],'PortHandles');
 for d=backup.destinations(:)',add_line(mdl,ph.Outport,d,'autorouting','on');end
end
set_param([mdl '/speed_ref'],'Value',backup.speed);
keys={'Before','After','Time'};for k=1:3,set_param([mdl '/T_load1'],keys{k},backup.load{k});end
for s=backup.settings(:)',for p=s.parameters(:)',set_param([mdl '/' s.block],p.name,p.value);end,end
set_param(mdl,'FixedStep',backup.fixedstep);
ws=get_param(mdl,'ModelWorkspace');clear(ws);
for v=backup.workspace(:)',assignin(ws,v.name,v.value);end
end
