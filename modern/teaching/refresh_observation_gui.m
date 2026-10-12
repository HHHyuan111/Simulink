function refresh_observation_gui
% Preserve any unsaved desktop state before loading the validated disk model.
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);mdl='PMSM_FOC_R2026a';
check=jsondecode(fileread(fullfile(folder,'observation_reload_check.json')));
assert(check.all_passed&&strcmp(teach_hash(fullfile(root,[mdl '.slx'])),check.model_sha256));
if bdIsLoaded(mdl)
 h=get_param(mdl,'Handle');
 if strcmp(get_param(h,'Dirty'),'on')
  backup=fullfile(root,'.build','observation_stage',['PMSM_FOC_desktop_' char(datetime('now','Format','yyyyMMdd_HHmmss')) '.slx']);
  save_system(h,backup);fprintf('OBS_GUI_BACKUP %s\n',backup);
 end
 close_system(h,0);
end
open_system(fullfile(root,[mdl '.slx']));set_param(mdl,'ZoomFactor','FitSystem');
fprintf('OBS_GUI_LOADED %s\n',get_param(mdl,'FileName'));
end
