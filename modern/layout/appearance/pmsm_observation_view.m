function result=pmsm_observation_view(action,mdl)
% Reversible callbacks/navigation; never changes Scope inputs or layouts.
persistent state
if nargin<1,action='install';end
if nargin<2,mdl='PMSM_FOC_R2026a';end
cacheKey=['PMSMObservationState_' mdl];
if isempty(state)&&bdIsLoaded(mdl)&&isappdata(groot,cacheKey),state=getappdata(groot,cacheKey);end
if ~isempty(state)&&~bdIsLoaded(state.model),state=[];end
if strcmp(action,'installed'),result=~isempty(state)&&strcmp(state.model,mdl);return;end
if strcmp(action,'remove')
 if isempty(state),result=false;return;end
 for k=1:numel(state.scopes)
  s=state.scopes(k);if getSimulinkBlockHandle(s.path)>0,set_param(s.path,'OpenFcn',s.open,'StopFcn',s.stop);end
 end
 for p=state.created,if getSimulinkBlockHandle(p{1})>0,delete_block(p{1});end,end
 set_param(mdl,'PreSaveFcn',state.pre_save);state=[];if isappdata(groot,cacheKey),rmappdata(groot,cacheKey);end;result=true;return;
end
assert(strcmp(action,'install')&&bdIsLoaded(mdl)&&strcmp(get_param(mdl,'SimulationStatus'),'stopped'));
dirty=get_param(mdl,'Dirty');
if isempty(state)
 state=struct('model',mdl,'pre_save',get_param(mdl,'PreSaveFcn'),...
  'scopes',struct('path',{},'open',{},'stop',{}),'created',{{}});
 try
  for row={'时域观测','time',1800;'频域分析','frequency',1960;...
    '电流频谱','current_fft',2120;'d轴频响','d_loop',2280;'q轴频响','q_loop',2440;'速度频响','speed_loop',2600}'
   path=[mdl '/' row{1}];state.created{end+1}=path;
   if getSimulinkBlockHandle(path)<0,add_block('built-in/SubSystem',path);
   else
    cb=get_param(path,'OpenFcn');assert(strcmp(get_param(path,'BlockType'),'SubSystem')&&...
     (startsWith(cb,'open_pmsm_observations(')||startsWith(cb,'pmsm_observation_launch(')),'导航名称被其他模块占用。');
   end
   set_param(path,'Position',[row{3} 20 row{3}+140 80],...
    'BackgroundColor','[0.72 0.84 0.96]','FontName','Microsoft YaHei','FontSize','18','ShowName','off',...
    'OpenFcn',sprintf('pmsm_observation_launch(''%s'');',row{2}),'Tag','PMSMObservationShortcut');
   mask=Simulink.Mask.get(path);if isempty(mask),mask=Simulink.Mask.create(path);end;mask.Display=['disp(''' row{1} ''')'];
  end
  set_param(mdl,'PreSaveFcn',"error('pmsm:ObservationView','请先移除观测显示层，再保存计算基线。');");
 catch err,pmsm_observation_view('remove',mdl);rethrow(err);end
end
scopes=find_system(mdl,'LookUnderMasks','all','FollowLinks','off','BlockType','Scope');
for k=1:numel(scopes)
 path=scopes{k};if any(strcmp({state.scopes.path},path)),continue;end
 old=struct('path',path,'open',get_param(path,'OpenFcn'),'stop',get_param(path,'StopFcn'));
 state.scopes(end+1)=old;
 set_param(path,'OpenFcn',sprintf('pmsm_scope_open(''%s'');',path),...
  'StopFcn',sprintf('%s\npmsm_scope_theme(''%s'',true);',old.stop,path));
 c=get_param(path,'ScopeConfiguration');c.Position=[80 60 1120 800];
end
setappdata(groot,cacheKey,state);set_param(mdl,'Dirty',dirty);result=struct('scope_count',numel(state.scopes),'bounds',[80 60 1120 800]);
end
