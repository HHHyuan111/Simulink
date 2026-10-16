function result=pmsm_deadtime_scope(action,mdl,view)
% Read-only teaching observer of the existing detailed inverter.
persistent state
if nargin<1,action='install';end;if nargin<2,mdl='PMSM_FOC_R2026a';end
key=['PMSMDeadtimeScope_' mdl];
if isempty(state)&&bdIsLoaded(mdl)&&isappdata(groot,key),state=getappdata(groot,key);end
if ~isempty(state)&&(~bdIsLoaded(mdl)||(state.scope>=0&&~ishandle(state.scope))),state=[];if isappdata(groot,key),rmappdata(groot,key);end,end
if ~isempty(state)&&~isfield(state,'view'),state.view='gates';end
if nargin<3,if isempty(state),view='gates';else,view=state.view;end,end
assert(ismember(view,{'gates','effects','compensation'}));
result=[];if strcmp(action,'installed'),result=~isempty(state);return;end
if strcmp(action,'mode'),result=view;return;end
if strcmp(action,'remove')
 if isempty(state),return;end
 assert(strcmp(get_param(mdl,'SimulationStatus'),'stopped'));dirty=get_param(mdl,'Dirty');if state.scope>=0&&ishandle(state.scope),close_system(state.scope);drawnow;end
 for h=state.created(end:-1:1)
  if ~ishandle(h),continue;end
  ph=get_param(h,'PortHandles');parent=get_param(h,'Parent');
  for port=ph.Inport(:)',ln=get_param(port,'Line');if ln>=0,delete_line(parent,get_param(ln,'SrcPortHandle'),port);end,end
  for port=ph.Outport(:)',ln=get_param(port,'Line');if ln>=0,delete_line(ln);end,end
  delete_block(h);
 end
 state=[];if isappdata(groot,key),rmappdata(groot,key);end;set_param(mdl,'Dirty',dirty);return;
end
assert(ismember(action,{'install','open'})&&bdIsLoaded(mdl),'请先打开原模型。');
if ~isempty(state)&&~strcmp(state.view,view),pmsm_deadtime_scope('remove',mdl);end
if isempty(state)
 assert(strcmp(get_param(mdl,'SimulationStatus'),'stopped'),'先停止仿真。');dirty=get_param(mdl,'Dirty');
 state=struct('scope',-1,'created',[],'view',view);parent=[mdl '/死区教学'];
 try
  make('built-in/SubSystem',parent,'Position',[2300 1950 2460 2000],'OpenFcn','pmsm_deadtime_scope(''open'');','ShowName','off');
  mask=Simulink.Mask.create(parent);mask.Display='disp(''死区教学'');';
  if strcmp(view,'gates'),variables={'obs_dead_requested','obs_dead_gates','obs_current_fast','obs_dead_bridge'};
  elseif strcmp(view,'effects'),variables={'obs_current_fast','obs_state','obs_id_ref','log_iq_ref','log_TL','log_Te'};
  else,variables={'log_iabc_meas','obs_dead_comp','log_iq_ref','obs_state'};end
  for k=1:numel(variables)
   logs=find_system(mdl,'LookUnderMasks','all','BlockType','ToWorkspace','VariableName',variables{k});assert(isscalar(logs));
   ph=get_param(logs{1},'PortHandles');src=get_param(get_param(ph.Inport,'Line'),'SrcPortHandle');owner=get_param(logs{1},'Parent');
   h=make('simulink/Signal Routing/Goto',[owner '/死区教学来源' num2str(k)],'GotoTag',['NativeDeadtime_' num2str(k)],'TagVisibility','global');
   add_line(owner,src,get_param(h,'PortHandles').Inport,'autorouting','on');
  end
  % Scope display order is column-major: upper/lower above current/voltage.
  if strcmp(view,'gates')
   sample='dead_h';span='0.0001';scopeName='看懂死区';scopeTag='PMSMNativeDeadtimeScope';
   groups={{1,'u(1)','上管请求';2,'u(1)','上管实际'},'A相上管','状态';...
   {3,'u(1)','A相电流'},'A相电流','A';...
   {1,'u(2)','下管请求';2,'u(2)','下管实际'},'A相下管','状态';...
   {1,'Vdc*u(1)','理想桥臂电压';4,'u(4)','实际桥臂电压'},'A桥臂极点电压','V'};
  elseif strcmp(view,'effects')
   sample='T';span='0.02';scopeName='死区影响';scopeTag='PMSMNativeDeadtimeEffectsScope';
   groups={{1,'u(1)','A相';1,'u(2)','B相';1,'u(3)','C相'},'三相电流','A';...
    {3,'u(1)','id给定';2,'u(1)','id实际'},'d轴电流','A';...
    {4,'u(1)','iq给定';2,'u(2)','iq实际'},'q轴电流','A';...
    {5,'u(1)','负载转矩';6,'u(1)','电磁转矩'},'转矩','N·m'};
  else
   sample='timing_control_sample';span='0.02';scopeName='补偿作用';scopeTag='PMSMNativeDeadtimeCompScope';
   groups={{1,'u(1)','A相测量电流';0,'dead_comp_cfg(4)','正阈值';0,'-dead_comp_cfg(4)','负阈值'},'电流与阈值','A';...
    {2,'u(1)','A相补偿电压'},'补偿电压','V';...
    {2,'u(6)','A相极性'},'极性判定','状态';...
    {3,'u(1)','iq给定';4,'u(2)','iq实际'},'q轴电流','A'};
  end
  state.scope=make([mdl '/跟踪观测/总览'],[parent '/看懂死区'],'NumInputPorts','4','SampleTime',sample,...
   'Position',[680 140 760 460],'OpenFcn','','StopFcn','');dest=get_param(state.scope,'PortHandles');
  for k=1:4
   rows=groups{k,1};y=80+(k-1)*150;bus=make('simulink/Signal Routing/Bus Creator',[parent '/汇总' num2str(k)],'Inputs',num2str(size(rows,1)),'Position',[600 y 605 y+90]);bp=get_param(bus,'PortHandles');
   for j=1:size(rows,1)
    if rows{j,1}==0
     pick=make('simulink/Sources/Constant',[parent '/' rows{j,3}],'Value',rows{j,2},'Position',[250 y+35*j 360 y+35*j+24]);
    else
     from=make('simulink/Signal Routing/From',[parent '/来源' num2str(k) '_' num2str(j)],'GotoTag',['NativeDeadtime_' num2str(rows{j,1})],'Position',[40 y+35*j 170 y+35*j+24]);
     pick=make('simulink/User-Defined Functions/Fcn',[parent '/' rows{j,3}],'Expr',rows{j,2},'Position',[250 y+35*j 360 y+35*j+24]);
     add_line(parent,get_param(from,'PortHandles').Outport,get_param(pick,'PortHandles').Inport,'autorouting','on');
    end
    source=get_param(pick,'PortHandles').Outport;
    if strcmp(view,'gates')&&k==4
     on=make('simulink/Sources/Constant',[parent '/详细桥启用' num2str(j)],'Value','dead_gate_on');off=make('simulink/Sources/Constant',[parent '/非详细桥无数据' num2str(j)],'Value','NaN');
     sw=make('simulink/Signal Routing/Switch',[parent '/桥臂电压有效' num2str(j)],'Criteria','u2 ~= 0','Position',[450 y+30+50*j 500 y+75+50*j]);sp=get_param(sw,'PortHandles');
     add_line(parent,source,sp.Inport(1));add_line(parent,get_param(on,'PortHandles').Outport,sp.Inport(2));add_line(parent,get_param(off,'PortHandles').Outport,sp.Inport(3));source=sp.Outport;
    end
    ln=add_line(parent,source,bp.Inport(j),'autorouting','on');set_param(ln,'Name',rows{j,3});
   end
   add_line(parent,bp.Outport,dest.Inport(k),'autorouting','on');
  end
  set_param(state.scope,'Tag',scopeTag);
  c=get_param(state.scope,'ScopeConfiguration');c.Name=scopeName;c.LayoutDimensions=[2 2];c.Position=[80 60 1120 800];
  c.FrameBasedProcessing=false;c.TimeSpan=span;c.TimeUnits='Metric';c.TimeDisplayOffset='0';c.TimeSpanOverrunAction='Scroll';c.TimeAxisLabels='Bottom';c.MaximizeAxes='Off';
  c.OpenAtSimulationStart=false;c.DataLogging=true;c.DataLoggingVariableName='native_deadtime_scope';c.DataLoggingSaveFormat='Dataset';
  c.DataLoggingLimitDataPoints=true;c.DataLoggingMaxPoints='32000';c.DataLoggingDecimateData=false;
  for k=1:4,c.ActiveDisplay=num2str(k);c.Title=groups{k,2};c.YLabel=groups{k,3};c.ShowGrid=true;c.ShowLegend=true;c.ShowTimeAxisLabel=true;c.AxesScaling='Auto';end
  if strcmp(view,'gates'),for k=[1 3],c.ActiveDisplay=num2str(k);c.AxesScaling='Manual';c.YLimits=[-.1 1.1];end,end;c.ActiveDisplay='1';
  if strcmp(view,'compensation'),c.ActiveDisplay='3';c.AxesScaling='Manual';c.YLimits=[-1.2 1.2];c.ActiveDisplay='1';end
  path=getfullname(state.scope);set_param(state.scope,'OpenFcn',sprintf('pmsm_scope_open(''%s'');',path),'StopFcn',sprintf('pmsm_scope_theme(''%s'',true);',path));
  setappdata(groot,key,state);set_param(mdl,'Dirty',dirty);
 catch err,pmsm_deadtime_scope('remove',mdl);rethrow(err);end
end
result=struct('path',getfullname(state.scope),'layout',[2 2],'view',view,...
 'time_span_s',str2double(get_param(state.scope,'ScopeConfiguration').TimeSpan),'sample_time',get_param(state.scope,'SampleTime'));
if strcmp(action,'open'),pmsm_scope_open(result.path);end
 function h=make(lib,path,varargin)
  assert(getSimulinkBlockHandle(path)<0,'观测名称已存在：%s',path);
  h=add_block(lib,path,varargin{:},'Tag','PMSMNativeDeadtimeScope','BackgroundColor','white');state.created(end+1)=h;
 end
end
