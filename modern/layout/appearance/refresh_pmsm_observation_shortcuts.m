function refresh_pmsm_observation_shortcuts
here=fileparts(mfilename('fullpath'));root=fileparts(fileparts(here));addpath(fullfile(root,'teaching'),here);m='PMSM_FOC_R2026a';
if pmsm_observation_view('installed')&&numel(find_system(m,'SearchDepth',1,'Tag','PMSMObservationShortcut'))==6,return;end
assert(bdIsLoaded(m)&&strcmp(get_param(m,'SimulationStatus'),'stopped'));cfg=pmsm_config('read');mw=get_param(m,'ModelWorkspace');code=mw.MATLABCode;dirty=get_param(m,'Dirty');
% One-time migration from the pre-cache view. Only restore owned wrappers.
if ~pmsm_observation_view('installed')&&getSimulinkBlockHandle([m '/时域观测'])>0
 defaults=jsondecode(fileread(fullfile(here,'observation_source_callbacks.json')));
 scopes=find_system(m,'LookUnderMasks','all','BlockType','Scope');saved=struct('path',{},'open',{},'stop',{});
 for k=1:numel(scopes)
  path=scopes{k};open=get_param(path,'OpenFcn');stop=get_param(path,'StopFcn');sid=Simulink.ID.getSID(path);sid=extractAfter(sid,':');
  saved(end+1)=struct('path',path,'open',open,'stop',stop);
  if strcmp(open,sprintf('pmsm_scope_open(''%s'');',path))
   ix=find(strcmp({defaults.sid},sid));original='';if ~isempty(ix),original=defaults(ix).open;end
   set_param(path,'OpenFcn',original);
  end
  suffix=sprintf('\npmsm_scope_theme(''%s'',true);',path);if endsWith(stop,suffix),set_param(path,'StopFcn',stop(1:end-numel(suffix)));end
 end
 backup=fullfile(root,'.build');if ~isfolder(backup),mkdir(backup);end;teach_writejson(fullfile(backup,'pre_shortcut_migration_callbacks.json'),saved);
 for name={'时域观测','频域分析'}
  path=[m '/' name{1}];assert(startsWith(get_param(path,'OpenFcn'),'open_pmsm_observations('));
 end
 if pmsm_presentation('installed')
  set_param(m,'PreSaveFcn',"error('pmsm:PresentationSave','布局配置已自动保存在脚本中。修改计算模型前，请先执行 pmsm_presentation(''remove'')，再保存新的基线版本。');");
 else,set_param(m,'PreSaveFcn','');end
end
if pmsm_observation_view('installed'),pmsm_observation_view('remove');end
pmsm_observation_view('install');set_param(m,'Dirty',dirty);
assert(isequaln(cfg,pmsm_config('read'))&&strcmp(code,mw.MATLABCode));
fprintf('MODEL_SHORTCUTS_READY configuration preserved\n');

end
