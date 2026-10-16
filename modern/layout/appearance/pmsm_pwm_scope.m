function result=pmsm_pwm_scope(action,mdl)
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
 pmsm_electrical_scope('install',mdl);
 dirty=get_param(mdl,'Dirty');parent=[mdl '/时序观测'];
 state=struct('parent',parent,'scope',-1,'created',[], ...
  'open_fcn',get_param(parent,'OpenFcn'),'mask_display',get_param(parent,'MaskDisplay'), ...
  'pre_save',get_param(mdl,'PreSaveFcn'));
 try
  variables={'obs_carrier_fast','log_Tcm_requested','log_Tcm_applied','obs_dead_gates','obs_adc_timing','obs_pwm_timing'};
  for k=1:numel(variables)
   logs=find_system(mdl,'LookUnderMasks','all','FollowLinks','off','BlockType','ToWorkspace','VariableName',variables{k});
   assert(isscalar(logs),'观测日志必须唯一：%s',variables{k});
   ph=get_param(logs{1},'PortHandles');src=get_param(get_param(ph.Inport(1),'Line'),'SrcPortHandle');
   owner=get_param(logs{1},'Parent');tag=sprintf('NativePWM_%d',k);
   h=make('simulink/Signal Routing/Goto',[owner '/' tag],'GotoTag',tag,'TagVisibility','global','Position',[2400 100+40*k 2540 124+40*k]);
   add_line(owner,src,get_param(h,'PortHandles').Inport,'autorouting','on');
  end
  % Column-major: comparison/ADC above, gates/CCR below. No synthetic events.
  groups={ {1,'u(1)*1e6','carrier';2,'u(1)*1e6','Tcm_req_A';3,'u(1)*1e6','Tcm_act_A'},'载波与A相阈值','μs'; ...
   {4,'u(1)','AH';4,'u(2)','AL'},'A相门极','状态'; ...
   {5,'u(2)','ADC_trig';5,'u(6)','JEOS'},'ADC事件','状态'; ...
   {6,'u(3)','UEV';6,'u(4)','CCR_write';6,'u(5)','CCR_latch'},'CCR事件','状态'};
  % Clone the model's already migrated native Scope. A fresh library Scope
  % can defer its web-scope migration until simulation and drop early styles.
  state.scope=make([mdl '/跟踪观测/控制响应'],[parent '/PWM与采样'],'NumInputPorts','4','Position',[2300 100 2390 400],'SampleTime','timing_h');
  dest=get_param(state.scope,'PortHandles');
  for k=1:4
   y=100+180*(k-1);rows=groups{k,1};
   bus=make('simulink/Signal Routing/Bus Creator',[parent '/时序汇总' num2str(k)],'Inputs',num2str(size(rows,1)),'Position',[2200 y 2205 y+110]);bp=get_param(bus,'PortHandles');
   for j=1:size(rows,1)
    pos=y+35*(j-1);
    from=make('simulink/Signal Routing/From',[parent '/时序来源' num2str(k) '_' num2str(j)],'GotoTag',sprintf('NativePWM_%d',rows{j,1}),'Position',[1850 pos 1980 pos+22]);
    pick=make('simulink/User-Defined Functions/Fcn',[parent '/' rows{j,3}],'Expr',rows{j,2},'Position',[2040 pos 2110 pos+22]);
    add_line(parent,get_param(from,'PortHandles').Outport,get_param(pick,'PortHandles').Inport,'autorouting','on');
    ln=add_line(parent,get_param(pick,'PortHandles').Outport,bp.Inport(j),'autorouting','on');set_param(ln,'Name',rows{j,3});
   end
   add_line(parent,bp.Outport,dest.Inport(k),'autorouting','on');
  end
  c=get_param(state.scope,'ScopeConfiguration');c.LayoutDimensions=[2 2];c.Position=[120 80 1120 800];
  c.FrameBasedProcessing=false;c.TimeSpan='0.0002';c.TimeSpanOverrunAction='Scroll';c.TimeUnits='Metric';c.TimeAxisLabels='Bottom';c.MaximizeAxes='Off';
  c.OpenAtSimulationStart=false;c.DataLogging=true;c.DataLoggingVariableName='native_pwm_scope';
  c.DataLoggingSaveFormat='Dataset';c.DataLoggingLimitDataPoints=true;c.DataLoggingMaxPoints='64000';c.DataLoggingDecimateData=false;
  for k=1:4
   c.ActiveDisplay=num2str(k);c.Title=groups{k,2};c.YLabel=groups{k,3};c.ShowGrid=true;c.ShowLegend=true;c.ShowTimeAxisLabel=true;
  end
  fixedRanges(c,mdl);
  set_param(parent,'OpenFcn','pmsm_pwm_scope(''open'');','MaskDisplay','disp(''PWM与采样'');');
  set_param(mdl,'PreSaveFcn',"error('pmsm:PWMScopeView','请先依次移除PWM观测、电气观测、控制观测和布局显示层，再保存计算模型。');",'Dirty',dirty);
 catch err
  pmsm_pwm_scope('remove',mdl);rethrow(err);
 end
end
result=struct('path',getfullname(state.scope),'layout',[2 2],'style','blackonwhite');
if strcmp(action,'open')
 dirty=get_param(mdl,'Dirty');open_system(state.scope);drawnow;
 pmsm_scope_style(getfullname(state.scope),'pwm');drawnow;
 c=get_param(state.scope,'ScopeConfiguration');fixedRanges(c,mdl);set_param(mdl,'Dirty',dirty);
end
function fixedRanges(c,mdl)
% Binary signals have a stable physical scale; threshold range follows Ts.
ws=get_param(mdl,'ModelWorkspace');period=getVariable(ws,'Ts');
for k=1:4
 c.ActiveDisplay=num2str(k);c.AxesScaling='Manual';
 if k==1,c.YLimits=[-1 period*5e5*1.05+1];else,c.YLimits=[-.1 1.1];end
end
c.ActiveDisplay='1';
end
 function h=make(library,path,varargin)
  assert(getSimulinkBlockHandle(path)<0,'观测名称已存在：%s',path);
  h=add_block(library,path,varargin{:},'Tag','PMSMNativePWMScope','BackgroundColor','white');state.created(end+1)=h;
  if strcmp(get_param(h,'BlockType'),'Scope'),set_param(h,'OpenFcn','','StopFcn','');end
 end
end
