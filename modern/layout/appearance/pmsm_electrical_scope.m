function result=pmsm_electrical_scope(action,mdl)
% Reversible native observer. Tap existing logs; never change control paths.
persistent state
if nargin<1,action='install';end
if nargin<2,mdl='PMSM_FOC_R2026a';end
if ~isempty(state)&&(~bdIsLoaded(mdl)||(state.scope>=0&&~ishandle(state.scope))),state=[];end
result=[];
if strcmp(action,'installed'),result=~isempty(state);return;end
if strcmp(action,'remove')
 if isempty(state),return;end
 assert(strcmp(get_param(mdl,'SimulationStatus'),'stopped'),'先停止仿真。');
 dirty=get_param(mdl,'Dirty');if state.scope>=0&&ishandle(state.scope),close_system(state.scope);drawnow;end
 for h=state.created(end:-1:1)
  if ~ishandle(h),continue;end
  ph=get_param(h,'PortHandles');parent=get_param(h,'Parent');
  for p=ph.Inport(:)'
   ln=get_param(p,'Line');if ln>=0,delete_line(parent,get_param(ln,'SrcPortHandle'),p);end
  end
  for p=ph.Outport(:)'
   ln=get_param(p,'Line');if ln>=0,delete_line(ln);end
  end
  delete_block(h);
 end
 set_param(state.parent,'OpenFcn',state.open_fcn,'MaskDisplay',state.mask_display);
 set_param(mdl,'PreSaveFcn',state.pre_save,'Dirty',dirty);state=[];return;
end
assert(ismember(action,{'install','open'})&&bdIsLoaded(mdl),'请先打开原模型。');
if isempty(state)
 assert(strcmp(get_param(mdl,'SimulationStatus'),'stopped'),'先停止仿真。');
 pmsm_native_scope('install',mdl);
 dirty=get_param(mdl,'Dirty');parent=[mdl '/测量观测'];
 state=struct('parent',parent,'scope',-1,'created',[], ...
  'open_fcn',get_param(parent,'OpenFcn'),'mask_display',get_param(parent,'MaskDisplay'), ...
  'pre_save',get_param(mdl,'PreSaveFcn'));
 try
  variables={'log_iabc_true','log_iabc_meas','obs_voltage'};
  for k=1:3
   logs=find_system(mdl,'LookUnderMasks','all','FollowLinks','off','BlockType','ToWorkspace','VariableName',variables{k});
   assert(isscalar(logs),'观测日志必须唯一：%s',variables{k});
   ph=get_param(logs{1},'PortHandles');src=get_param(get_param(ph.Inport(1),'Line'),'SrcPortHandle');
   owner=get_param(logs{1},'Parent');tag=sprintf('NativeElectrical_%d',k);
   h=make('simulink/Signal Routing/Goto',[owner '/' tag],'GotoTag',tag,'TagVisibility','global','Position',[2400 100+40*k 2540 124+40*k]);
   add_line(owner,src,get_param(h,'PortHandles').Inport,'autorouting','on');
  end
  % Display indices are column-major: currents on top, voltages below.
  groups={1,[1 2 3],{'ia_true','ib_true','ic_true'},'三相电流','A'; ...
   3,[1 3],{'vd_req','vd_lim'},'d轴电压','V'; ...
   2,[1 2 3],{'ia_meas','ib_meas','ic_meas'},'测量电流','A'; ...
   3,[2 4],{'vq_req','vq_lim'},'q轴电压','V'};
  % Clone the model's already migrated native Scope. A fresh library Scope
  % can defer its web-scope migration until simulation and drop early styles.
  state.scope=make([mdl '/跟踪观测/控制响应'],[parent '/电流与电压'],'NumInputPorts','4','Position',[2300 100 2390 400],'SampleTime','dt');
  dest=get_param(state.scope,'PortHandles');
  for k=1:4
   y=100+180*(k-1);ix=groups{k,2};names=groups{k,3};
   bus=make('simulink/Signal Routing/Bus Creator',[parent '/电气汇总' num2str(k)],'Inputs',num2str(numel(ix)),'Position',[2200 y 2205 y+110]);bp=get_param(bus,'PortHandles');
   for j=1:numel(ix)
    pos=y+35*(j-1);
    from=make('simulink/Signal Routing/From',[parent '/电气来源' num2str(k) '_' num2str(j)],'GotoTag',sprintf('NativeElectrical_%d',groups{k,1}),'Position',[1850 pos 1980 pos+22]);
    pick=make('simulink/User-Defined Functions/Fcn',[parent '/' names{j}],'Expr',sprintf('u(%d)',ix(j)),'Position',[2040 pos 2110 pos+22]);
    add_line(parent,get_param(from,'PortHandles').Outport,get_param(pick,'PortHandles').Inport,'autorouting','on');
    ln=add_line(parent,get_param(pick,'PortHandles').Outport,bp.Inport(j),'autorouting','on');set_param(ln,'Name',names{j});
   end
   add_line(parent,bp.Outport,dest.Inport(k),'autorouting','on');
  end
  c=get_param(state.scope,'ScopeConfiguration');c.LayoutDimensions=[2 2];c.Position=[120 80 1120 800];
  c.FrameBasedProcessing=false;c.TimeSpan='Auto';c.TimeUnits='Seconds';c.TimeAxisLabels='Bottom';c.MaximizeAxes='Off';
  c.OpenAtSimulationStart=false;c.DataLogging=true;c.DataLoggingVariableName='native_electrical_scope';
  c.DataLoggingSaveFormat='Dataset';c.DataLoggingLimitDataPoints=false;c.DataLoggingDecimateData=false;
  for k=1:4
   c.ActiveDisplay=num2str(k);c.Title=groups{k,4};c.YLabel=groups{k,5};c.ShowGrid=true;c.ShowLegend=true;c.ShowTimeAxisLabel=true;c.AxesScaling='Auto';
  end
  c.ActiveDisplay='1';
  set_param(parent,'OpenFcn','pmsm_electrical_scope(''open'');','MaskDisplay','disp(''电流与电压'');');
  set_param(mdl,'PreSaveFcn',"error('pmsm:ElectricalScopeView','请先移除电气观测、控制观测和布局显示层，再保存计算模型。');",'Dirty',dirty);
 catch err
  pmsm_electrical_scope('remove',mdl);rethrow(err);
 end
end
result=struct('path',getfullname(state.scope),'layout',[2 2],'style','blackonwhite');
if strcmp(action,'open')
 dirty=get_param(mdl,'Dirty');open_system(state.scope);drawnow;
 pmsm_scope_style(getfullname(state.scope),'electrical');drawnow;
 c=get_param(state.scope,'ScopeConfiguration');for k=1:4,c.ActiveDisplay=num2str(k);c.AxesScaling='Auto';end
 c.ActiveDisplay='1';set_param(mdl,'Dirty',dirty);
end
 function h=make(library,path,varargin)
  assert(getSimulinkBlockHandle(path)<0,'观测名称已存在：%s',path);
  h=add_block(library,path,varargin{:},'Tag','PMSMNativeElectricalScope','BackgroundColor','white');state.created(end+1)=h;
  if strcmp(get_param(h,'BlockType'),'Scope'),set_param(h,'OpenFcn','','StopFcn','');end
 end
end
