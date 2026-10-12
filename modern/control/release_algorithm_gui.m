function release_algorithm_gui
% Preserve the desktop model before releasing its file lock for publication.
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);mdl='PMSM_FOC_R2026a';
if ~bdIsLoaded(mdl),return;end
h=get_param(mdl,'Handle');assert(strcmp(get_param(h,'SimulationStatus'),'stopped'));
work=fullfile(root,'.build','algorithm_stage');stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
workspace=get_param(mdl,'ModelWorkspace');values=struct;for variable=whos(workspace)',values.(variable.name)=getVariable(workspace,variable.name);end
save(fullfile(work,['desktop_workspace_' stamp '.mat']),'values');
if strcmp(get_param(h,'Dirty'),'on'),save_system(h,fullfile(work,['PMSM_FOC_desktop_' stamp '.slx']));end
close_system(h,0);fprintf('ALGORITHM_GUI_RELEASED\n');
end
