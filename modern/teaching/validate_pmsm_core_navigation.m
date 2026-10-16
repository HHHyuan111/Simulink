function report=validate_pmsm_core_navigation
here=fileparts(mfilename('fullpath'));root=fileparts(here);addpath(root,fullfile(root,'layout','appearance'));
m='PMSM_FOC_R2026a';assert(~bdIsLoaded(m));load_system(fullfile(root,[m '.slx']));guard=onCleanup(@()close_system(m,0));
mw=get_param(m,'ModelWorkspace');assignin(mw,'n',1234);cfg=pmsm_config('read');before=teach_snapshot(m);code=mw.MATLABCode;
hash=teach_hash(fullfile(root,[m '.slx']));referenceHash=teach_hash(fullfile(here,'reference_v1','manifest.json'));
scopes=find_system(m,'LookUnderMasks','all','BlockType','Scope');callbacks=cell(numel(scopes),2);
for k=1:numel(scopes),callbacks(k,:)={get_param(scopes{k},'OpenFcn'),get_param(scopes{k},'StopFcn')};end
panel=open_pmsm_observations('time');labels={'速度控制','电流采样','死区与补偿'};titles={'速度控制','电流采样','死区教学'};
for k=1:3
 b=findall(panel,'Type','uibutton','Text',labels{k});assert(isscalar(b));b.ButtonPushedFcn(b,[]);
 topic=findall(groot,'Type','figure','Name',titles{k});assert(isscalar(topic));
 assert(pmsm_observation_view('installed')&&isequaln(cfg,pmsm_config('read'))&&strcmp(code,mw.MATLABCode));delete(topic);
end
exportapp(panel,fullfile(root,'.build','core_teaching_navigation.png'));delete(panel);pmsm_observation_view('remove');
assert(isequaln(before,teach_snapshot(m))&&getVariable(mw,'n')==1234);
for k=1:numel(scopes),assert(strcmp(callbacks{k,1},get_param(scopes{k},'OpenFcn'))&&strcmp(callbacks{k,2},get_param(scopes{k},'StopFcn')));end
assert(strcmp(hash,teach_hash(fullfile(root,[m '.slx'])))&&strcmp(referenceHash,teach_hash(fullfile(here,'reference_v1','manifest.json'))));
report=struct('passed',true,'primary_topics',{labels},'callbacks_checked',3,'current_configuration_preserved',true,...
 'graph_restored',true,'model_sha256',hash,'reference_manifest_sha256',referenceHash);
teach_writejson(fullfile(here,'core_teaching_navigation_validation.json'),report);disp('CORE_TEACHING_NAVIGATION_VALIDATED');
end
