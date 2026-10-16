function publish_deadtime_stage4
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);addpath(fullfile(root,'teaching'));
work=fullfile(root,'.build','deadtime_stage');mdl='PMSM_FOC_R2026a';file=fullfile(root,[mdl '.slx']);candidate=fullfile(work,[mdl '.slx']);
recordFile=fullfile(folder,'deadtime_stage4_results.json');r=jsondecode(fileread(recordFile));
assert(r.all_passed&&r.root_geometry_preserved&&r.original_scripts_preserved);assert(strcmp(teach_hash(candidate),r.model_sha256));
allowedHashes={r.source_sha256,r.model_sha256};if isfield(r,'validated_algorithm_model_sha256'),allowedHashes{end+1}=r.validated_algorithm_model_sha256;end
assert(ismember(teach_hash(file),allowedHashes),'Main model has changed; do not overwrite.');
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
if bdIsLoaded(mdl)
 h=get_param(mdl,'Handle');assert(strcmp(get_param(h,'SimulationStatus'),'stopped'));mw=get_param(h,'ModelWorkspace');values=struct;
 for v=whos(mw)',values.(v.name)=getVariable(mw,v.name);end
 save(fullfile(work,['desktop_workspace_' stamp '.mat']),'values');
 if strcmp(get_param(h,'Dirty'),'on'),save_system(h,fullfile(work,['PMSM_FOC_desktop_' stamp '.slx']));end
 close_system(h,0);
end
copyfile(candidate,file);assert(strcmp(teach_hash(file),r.model_sha256));
r.publication_status='published';r.published_at=char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));teach_writejson(recordFile,r);
copyfile(fullfile(work,'candidate.png'),fullfile(root,'layout','flat_tidy.png'));
open_system(file);set_param(mdl,'ZoomFactor','FitSystem');fprintf('DEADTIME_GUI_READY %s\n',r.model_sha256);
end
