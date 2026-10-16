function r=rebuild_pmsm_system_report(origin)
% Derived-only recovery in a NEW folder. The original failure remains failed.
here=fileparts(mfilename('fullpath'));root=fileparts(here);addpath(fullfile(root,'teaching'));
originalRecord=fullfile(origin,'record.json');r=jsondecode(fileread(originalRecord));
assert(strcmp(r.status,'failed')&&contains(r.error,'报告')&&numel(r.cases)==2);
assert(r.restored_reference&&r.original_structure_preserved&&strcmp(r.model_sha256,teach_hash(fullfile(root,'PMSM_FOC_R2026a.slx'))));
assert(strcmp(r.reference_sha256,teach_hash(fullfile(root,'teaching','reference_v1','manifest.json'))));
allowed={'framework/pmsm_system_analysis.m','framework/render_pmsm_system_baseline.m','framework/repeat_pmsm_system_baseline.m'};changes={};simulationSources=r.source_files;
for k=1:numel(r.source_files)
 f=r.source_files(k);now=teach_hash(fullfile(root,f.path));
 if ~strcmp(now,f.sha256),assert(ismember(f.path,allowed),'仿真或配置源码已变化，不允许仅重建报告：%s',f.path);changes{end+1}=f.path;r.source_files(k).sha256=now;end
end
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));u=char(java.util.UUID.randomUUID);r.id=[stamp '_system_report_' u(1:8)];
r.folder=fullfile(here,'runs',r.id);mkdir(r.folder);r.status='running';r=rmfield(r,'error');
r.report_replay=struct('origin_folder',origin,'origin_record_sha256',teach_hash(originalRecord),...
 'simulation_source_files',simulationSources,'changed_derived_sources',{changes},...
 'replay_script_sha256',teach_hash([mfilename('fullpath') '.m']),'copied_inputs',struct('path',{},'sha256',{}));
for name={'plan.json','reference_manifest.json','reference.mat','factor.mat'}
 src=fullfile(origin,name{1});digest=teach_hash(src);copyfile(src,fullfile(r.folder,name{1}));
 assert(strcmp(digest,teach_hash(fullfile(r.folder,name{1}))));
 r.report_replay.copied_inputs(end+1)=struct('path',name{1},'sha256',digest);
end
teach_writejson(fullfile(r.folder,'record.json'),r);
try
 render_pmsm_system_baseline(r.folder);
 names={'plan.json','reference_manifest.json','reference.mat','factor.mat','analysis.json','metrics.csv','response.png','feedback.png','currents.png'};
 r.files=struct('path',{},'sha256',{});for name=names,r.files(end+1)=struct('path',name{1},'sha256',teach_hash(fullfile(r.folder,name{1})));end
 assert(strcmp(r.report_replay.origin_record_sha256,teach_hash(originalRecord)));
 for f=r.report_replay.copied_inputs(:)',assert(strcmp(f.sha256,teach_hash(fullfile(origin,f.path))));end
 r.status='completed';teach_writejson(fullfile(r.folder,'record.json'),r);verify_pmsm_system_baseline(r.folder);
 teach_writejson(fullfile(here,'latest.json'),struct('id',r.id,'folder',r.folder));
 fprintf('SYSTEM_REPORT_REBUILT %s\n',r.folder);
catch err
 r.status='failed';r.error=err.message;teach_writejson(fullfile(r.folder,'record.json'),r);rethrow(err);
end
end
