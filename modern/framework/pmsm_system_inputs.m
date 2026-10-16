function result=pmsm_system_inputs(action,mdl,schedule)
% Reversible speed-step insertion; load step is a SimulationInput override.
path=[mdl '/整机给定'];
if strcmp(action,'installed'),result=getSimulinkBlockHandle(path)>0;return;end
if strcmp(action,'remove')
 if getSimulinkBlockHandle(path)<0,result=false;return;end
 b=get_param(path,'UserData');ph=get_param(path,'PortHandles');line=get_param(ph.Outport,'Line');
 if line>=0,delete_line(line);end
 delete_block(path);
 if getSimulinkBlockHandle(b.terminator)>0
  tp=get_param(b.terminator,'PortHandles');tl=get_param(tp.Inport,'Line');if tl>=0,delete_line(tl);end;delete_block(b.terminator);
 end
 for dst=b.destinations(:)'
  dl=get_param(dst,'Line');if dl<0,add_line(mdl,b.source,dst,'autorouting','on');else,assert(get_param(dl,'SrcPortHandle')==b.source);end
 end
 set_param(get_param(b.source,'Line'),'Name',b.name);set_param(mdl,'Dirty',b.dirty);result=true;return
end
assert(strcmp(action,'install')&&getSimulinkBlockHandle(path)<0);
ph=get_param(Simulink.ID.getHandle([mdl ':592']),'PortHandles');line=get_param(ph.Outport,'Line');
b=struct('source',ph.Outport,'destinations',get_param(line,'DstPortHandle'),'name',get_param(line,'Name'),'dirty',get_param(mdl,'Dirty'),'terminator',[mdl '/原给定保留']);
add_block('simulink/Sources/Step',path,'Position',[30 270 100 300],...
 'Time',num2str(schedule.speed_step_s,17),'Before',num2str(schedule.speed_before_rpm,17),...
 'After',num2str(schedule.speed_after_rpm,17),'SampleTime','timing_speed_sample');
set_param(path,'UserData',b);delete_line(line);out=get_param(path,'PortHandles');
add_block('simulink/Sinks/Terminator',b.terminator,'Position',[110 190 130 210]);tp=get_param(b.terminator,'PortHandles');add_line(mdl,b.source,tp.Inport,'autorouting','on');
for dst=b.destinations(:)',add_line(mdl,out.Outport,dst,'autorouting','on');end
result=path;
end
