function refresh_algorithm_gui
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);addpath(fullfile(root,'teaching'));
mdl='PMSM_FOC_R2026a';file=fullfile(root,[mdl '.slx']);record=jsondecode(fileread(fullfile(folder,'algorithm_stage2_results.json')));
assert(record.all_passed&&strcmp(teach_hash(file),record.model_sha256));
if bdIsLoaded(mdl)
 h=get_param(mdl,'Handle');assert(strcmp(get_param(h,'SimulationStatus'),'stopped'));
 if strcmp(get_param(h,'Dirty'),'on')
  work=fullfile(root,'.build','algorithm_stage');backup=fullfile(work,['PMSM_FOC_desktop_' char(datetime('now','Format','yyyyMMdd_HHmmss')) '.slx']);save_system(h,backup);fprintf('ALGORITHM_GUI_BACKUP %s\n',backup);
 end
 close_system(h,0);
end
open_system(file);set_param(mdl,'ZoomFactor','FitSystem');fprintf('ALGORITHM_GUI_READY %s\n',record.model_sha256);
end
