function result=pmsm_native_scope(action,mdl)
% Reversible native Scope view on the original observation subsystem.
% No controller, motor, logging source or numerical setting is changed.
persistent state
if nargin<1,action='install';end
if nargin<2,mdl='PMSM_FOC_R2026a';end
result=[];
if ~isempty(state)&&(~bdIsLoaded(state.model)||~ishandle(state.scope)),state=[];end
if strcmp(action,'installed'),result=~isempty(state)&&strcmp(state.model,mdl);return;end
if strcmp(action,'forget'),state=[];return;end
if strcmp(action,'remove')
 if isempty(state),return;end
 assert(strcmp(get_param(mdl,'SimulationStatus'),'stopped'),'先停止仿真。');
 dirty=get_param(mdl,'Dirty');scope=state.scope;
 % The original Scope stays untouched; only this temporary observer closes.
 close_system(scope);drawnow;disconnect(scope);
 % Delete connections explicitly: delete_block alone can leave dangling line
 % segments that reconnect when a later block is placed at the same position.
 for h=state.created(end:-1:1)
  if ~ishandle(h),continue;end
  disconnect(h);ports=get_param(h,'PortHandles');
  for port=ports.Outport(:)'
   line=get_param(port,'Line');if line>=0,delete_line(line);end
  end
  delete_block(h);
 end
 set_param(state.parent,'MaskDisplay',state.mask_display);
 set_param(state.parent,'OpenFcn',state.open_fcn);set_param(mdl,'PreSaveFcn',state.pre_save);
 set_param(mdl,'Dirty',dirty);state=[];return;
end
assert(ismember(action,{'install','open'}),'未知Scope操作。');
assert(bdIsLoaded(mdl),'请先打开原仿真模型。');
if isempty(state)
 assert(strcmp(get_param(mdl,'SimulationStatus'),'stopped'),'先停止仿真。');
 parent=[mdl '/跟踪观测'];originalScope=get_param([parent '/总览'],'Handle');dirty=get_param(mdl,'Dirty');
 state=struct('model',mdl,'scope',-1,'parent',parent, ...
  'mask_display',get_param(parent,'MaskDisplay'), ...
  'open_fcn',get_param(parent,'OpenFcn'),'pre_save',get_param(mdl,'PreSaveFcn'), ...
  'created',[]);
 try
  % A separate native observer avoids resizing/restyling the original
  % seven-input/eight-cell Scope and its R2026a dialog cache.
  scope=make(getfullname(originalScope),[parent '/控制响应'],'NumInputPorts','4','Position',[1900 200 1990 500]);state.scope=scope;
  % Tap the exact source already used by obs_state, including detailed-bridge mode.
  logs=find_system(mdl,'LookUnderMasks','all','FollowLinks','off','BlockType','ToWorkspace','VariableName','obs_state');
  assert(isscalar(logs),'电机状态记录必须唯一。');ph=get_param(logs{1},'PortHandles');src=get_param(get_param(ph.Inport(1),'Line'),'SrcPortHandle');
  plant=get_param(logs{1},'Parent');gotoName=[plant '/控制观测状态'];
  h=make('simulink/Signal Routing/Goto',gotoName,'GotoTag','NativeControlState','TagVisibility','global','Position',[1120 720 1260 744]);
  sourceName=get_param(get_param(src,'Parent'),'Name');sourcePort=get_param(src,'PortNumber');
  add_line(plant,[sourceName '/' num2str(sourcePort)],'控制观测状态/1','autorouting','on');
  f=make('simulink/Signal Routing/From',[parent '/真实状态'],'GotoTag','NativeControlState','Position',[1420 20 1550 44]);
  for k=1:2
   names={'真实id','真实iq'};
   h=make('simulink/User-Defined Functions/Fcn',[parent '/' names{k}],'Expr',sprintf('u(%d)',k),'Position',[1620 10+55*(k-1) 1690 40+55*(k-1)]);
   add_line(parent,get_param(f,'PortHandles').Outport,get_param(h,'PortHandles').Inport,'autorouting','on');
  end
  groups={ {'n_ref','nref';'n_true','speed'},'转速','rpm'; ...
   {'id_ref','ObsIdRef';'id_true','@真实id';'id_fb','id'},'d轴电流','A'; ...
   {'Te','Te';'TL','TL'},'转矩','N·m'; ...
   {'iq_ref','iq_ref';'iq_true','@真实iq';'iq_fb','iq'},'q轴电流','A'};
  set_param(scope,'NumInputPorts','4','Position',[1900 200 1990 500]);dest=get_param(scope,'PortHandles');
  for k=1:4
   rows=groups{k,1};y=150+180*(k-1);
   bus=make('simulink/Signal Routing/Bus Creator',[parent '/' groups{k,2} '_汇总'],'Inputs',num2str(size(rows,1)),'Position',[1770 y 1775 y+100]);
   bp=get_param(bus,'PortHandles');
   for j=1:size(rows,1)
    if startsWith(rows{j,2},'@'),from=get_param([parent '/' rows{j,2}(2:end)],'Handle');
    else,from=make('simulink/Signal Routing/From',[parent '/' rows{j,1}],'GotoTag',rows{j,2},'Position',[1420 y+35*(j-1) 1540 y+22+35*(j-1)]);end
    ln=add_line(parent,get_param(from,'PortHandles').Outport,bp.Inport(j),'autorouting','on');set_param(ln,'Name',rows{j,1});
   end
   add_line(parent,bp.Outport,dest.Inport(k),'autorouting','on');
  end
  c=get_param(scope,'ScopeConfiguration');c.Name='控制响应';c.Position=[80 60 1120 800];
  c.LayoutDimensions=[2 2];c.FrameBasedProcessing=false;c.TimeSpan='Auto';c.TimeUnits='Seconds';
  c.TimeDisplayOffset='0';c.TimeAxisLabels='Bottom';c.MaximizeAxes='Off';c.AxesScaling='Auto';
  c.DataLogging=true;c.DataLoggingVariableName='native_control_scope';c.DataLoggingSaveFormat='Dataset';
  c.DataLoggingLimitDataPoints=false;c.DataLoggingDecimateData=false;c.OpenAtSimulationStart=false;
  for k=1:4
   c.ActiveDisplay=num2str(k);c.Title=groups{k,2};c.YLabel=groups{k,3};c.ShowGrid=true;c.ShowLegend=true;c.ShowTimeAxisLabel=true;c.AxesScaling='Auto';
  end
  c.ActiveDisplay='1';set_param(parent,'MaskDisplay','disp(''控制响应'');','OpenFcn','pmsm_native_scope(''open'');');
  set_param(mdl,'PreSaveFcn',"error('pmsm:NativeScopeView','Scope观测设置已保存在脚本中。修改计算基线前，请先移除原生Scope显示层和布局。');");
  set_param(mdl,'Dirty',dirty);
 catch err
  pmsm_native_scope('remove',mdl);set_param(mdl,'Dirty',dirty);rethrow(err);
 end
end
result=struct('path',getfullname(state.scope),'layout',[2 2],'style','blackonwhite', ...
 'signal_names',{{'n_ref','n_true','id_ref','id_true','id_fb','Te','TL','iq_ref','iq_true','iq_fb'}});
if strcmp(action,'open')
 dirty=get_param(mdl,'Dirty');open_system(state.scope);
 % Use the style helper shipped with MATLAB, including the native web Scope.
 % Apply on every open so a restored observation view uses the same theme.
 pmsm_scope_style(getfullname(state.scope),'control');
 drawnow;c=get_param(state.scope,'ScopeConfiguration');
 for k=1:4,c.ActiveDisplay=num2str(k);c.AxesScaling='Auto';end
 c.ActiveDisplay='1';
 set_param(mdl,'Dirty',dirty);
end
 function h=make(library,path,varargin)
  assert(getSimulinkBlockHandle(path)<0,'观测块名称已存在：%s',path);
  h=add_block(library,path,varargin{:},'Tag','PMSMNativeControlScope','BackgroundColor','white');state.created(end+1)=h;
  if strcmp(get_param(h,'BlockType'),'Scope'),set_param(h,'OpenFcn','','StopFcn','');end
 end
end
function disconnect(scope)
ph=get_param(scope,'PortHandles');parent=get_param(scope,'Parent');
for p=ph.Inport(:)'
 ln=get_param(p,'Line');if ln>=0,src=get_param(ln,'SrcPortHandle');delete_line(parent,src,p);end
end
end
