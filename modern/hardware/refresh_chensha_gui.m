function refresh_chensha_gui
% Open the verified canonical file, preserving any unsaved desktop copy first.
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);addpath(fullfile(root,'teaching'));
mdl='PMSM_FOC_R2026a';file=fullfile(root,[mdl '.slx']);
record=jsondecode(fileread(fullfile(folder,'chensha_validation.json')));
assert(record.all_passed&&strcmp(teach_hash(file),record.model_sha256));
if bdIsLoaded(mdl)
 h=get_param(mdl,'Handle');assert(strcmp(get_param(h,'SimulationStatus'),'stopped'),'Finish the active simulation before refreshing.');
 if strcmp(get_param(h,'Dirty'),'on')
  work=fullfile(root,'.build','motor_profile_stage');if ~isfolder(work),mkdir(work);end
  backup=fullfile(work,['PMSM_FOC_desktop_' char(datetime('now','Format','yyyyMMdd_HHmmss')) '.slx']);
  save_system(h,backup);fprintf('MOTOR_GUI_BACKUP %s\n',backup);
 end
 close_system(h,0);
end
open_system(file);set_param(mdl,'ZoomFactor','FitSystem');mw=get_param(mdl,'ModelWorkspace');
print(['-s' mdl],'-dpng','-r120',fullfile(root,'layout','flat_tidy.png'));
fprintf('MOTOR_GUI_PROFILE %s | p=%g Rs=%g Ld=%g J=%g | speed=%g us\n', ...
 getVariable(mw,'MotorProfile'),getVariable(mw,'p'),getVariable(mw,'Rs'),getVariable(mw,'Ld'),getVariable(mw,'J'),1e6*getVariable(mw,'Ts_speed'));
end
