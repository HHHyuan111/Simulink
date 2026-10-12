function release_timing_gui
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);mdl='PMSM_FOC_R2026a';
if ~bdIsLoaded(mdl),return;end
assert(strcmp(get_param(mdl,'SimulationStatus'),'stopped'));
h=get_param(mdl,'Handle');
work=fullfile(root,'.build','timing_stage');stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
ws=get_param(mdl,'ModelWorkspace');values=struct;for v=whos(ws)',values.(v.name)=getVariable(ws,v.name);end
save(fullfile(work,['desktop_workspace_' stamp '.mat']),'values');
if strcmp(get_param(h,'Dirty'),'on'),save_system(h,fullfile(work,['PMSM_FOC_desktop_' stamp '.slx']));end
close_system(h,0);fprintf('TIMING_GUI_RELEASED\n');
end
