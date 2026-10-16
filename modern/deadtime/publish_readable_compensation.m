function publish_readable_compensation
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);addpath(fullfile(root,'teaching'));
work=fullfile(root,'.build','readable_compensation');mdl='PMSM_FOC_R2026a';file=fullfile(root,[mdl '.slx']);candidate=fullfile(work,[mdl '.slx']);recordFile=fullfile(folder,'readable_compensation_results.json');r=jsondecode(fileread(recordFile));
assert(r.all_passed&&r.root_geometry_preserved&&r.settings_preserved);assert(strcmp(teach_hash(candidate),r.model_sha256));assert(ismember(teach_hash(file),{r.source_sha256,r.model_sha256}),'Canonical changed; inspect before overwriting.');
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
if bdIsLoaded(mdl)
 h=get_param(mdl,'Handle');assert(strcmp(get_param(h,'SimulationStatus'),'stopped'));mw=get_param(h,'ModelWorkspace');values=struct;code=mw.MATLABCode;settings=teach_settings(mdl);
 for v=whos(mw)',values.(v.name)=getVariable(mw,v.name);end
 save(fullfile(work,['desktop_workspace_' stamp '.mat']),'values','code','settings');
 if strcmp(get_param(h,'Dirty'),'on'),save_system(h,fullfile(work,['PMSM_FOC_desktop_' stamp '.slx']));end
 close_system(h,0);
end
copyfile(candidate,file);assert(strcmp(teach_hash(file),r.model_sha256));r.publication_status='published';r.published_at=char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));teach_writejson(recordFile,r);
open_system(file);set_param(mdl,'ZoomFactor','FitSystem');open_system([mdl '/限压'],'force');set_param([mdl '/限压'],'ZoomFactor','FitSystem');
open_system([mdl '/限压/死区补偿']);set_param([mdl '/限压/死区补偿'],'ZoomFactor','FitSystem');fprintf('READABLE_COMPENSATION_GUI_READY %s\n',r.model_sha256);
end
