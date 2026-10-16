function backup=sensorless_n3_stimulus(mdl,testcase)
% Temporary request sources; restore without deleting any original block.
backup.speed=get_param([mdl '/speed_ref'],'Value');
backup.load=cellfun(@(k)get_param([mdl '/T_load1'],k),{'Before','After','Time'},'UniformOutput',false);
backup.settings=teach_settings(mdl);backup.added={};backup.destinations=[];
ws=get_param(mdl,'ModelWorkspace');backup.workspace=struct('name',{},'value',{});
for v=whos(ws)',backup.workspace(end+1)=struct('name',v.name,'value',getVariable(ws,v.name));end %#ok<AGROW>
backup.fixedstep=get_param(mdl,'FixedStep');
speed=0;if isfield(testcase,'speed_rpm'),speed=testcase.speed_rpm;else,speed=testcase.speed_initial_rpm;end
set_param([mdl '/speed_ref'],'Value',num2str(speed,17));
set_param([mdl '/T_load1'],'Before','.207','After','.207','Time','0');
if isfield(testcase,'events')
 events=testcase.events;if ~iscell(events),events=num2cell(events);end
 speedEvents=events(cellfun(@(e)strcmp(e.type,'speed'),events));
 if ~isempty(speedEvents)
  ph=get_param([mdl '/speed_ref'],'PortHandles');ln=get_param(ph.Outport,'Line');
  backup.destinations=get_param(ln,'DstPortHandle');delete_line(ln);
  sumPath=[mdl '/N3_速度请求'];add_block('simulink/Math Operations/Sum',sumPath,...
   'Position',[100 1760 135 1810],'Inputs',repmat('+',1,numel(speedEvents)+1));backup.added{end+1}=sumPath;
  sp=get_param(sumPath,'PortHandles');add_line(mdl,ph.Outport,sp.Inport(1),'autorouting','on');
  previous=speed;
  for k=1:numel(speedEvents)
   block=[mdl '/N3_转速阶跃' num2str(k)];e=speedEvents{k};
   add_block('simulink/Sources/Step',block,'Position',[20 1800+70*k 70 1835+70*k],...
    'Time',num2str(e.time_s,17),'Before','0','After',num2str(e.value_rpm-previous,17),'SampleTime','0');
   backup.added{end+1}=block;bp=get_param(block,'PortHandles');
   add_line(mdl,bp.Outport,sp.Inport(k+1),'autorouting','on');previous=e.value_rpm;
  end
  for d=backup.destinations(:)',add_line(mdl,sp.Outport,d,'autorouting','on');end
 end
 loadEvent=events(cellfun(@(e)strcmp(e.type,'load'),events));
 if ~isempty(loadEvent)
  assert(isscalar(loadEvent));loadEvent=loadEvent{1};set_param([mdl '/T_load1'],'Time',num2str(loadEvent.time_s,17),'After',num2str(loadEvent.value_Nm,17));
 end
end
if strcmp(testcase.configuration.bridge,'same_detailed_freewheel')
 set_param([mdl '/时序设置'],'real_on','on','window_on','off');
 set_param([mdl '/功率设置'],'gate_on','on','gate_us',num2str(testcase.configuration.gate_deadtime_us),...
  'comp_on','off','dead_on','off','drop_on','off');
end
end
