function verify_observation_saved
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);mdl='PMSM_FOC_R2026a';source=fullfile(root,[mdl '.slx']);
assert(~bdIsLoaded(mdl),'Use a fresh MATLAB session.');report=jsondecode(fileread(fullfile(folder,'observation_validation.json')));
assert(report.all_passed&&strcmp(teach_hash(source),report.after_sha256));
load_system(source);guard=onCleanup(@()close_system(mdl,0));
settings=teach_settings(mdl);
for k=1:numel(settings),for p=settings(k).parameters(:)',if endsWith(p.name,'_on'),assert(strcmp(p.value,'off'));end,end,end
fprintf('OBS_RELOAD_DEFAULT_1S\n');o=sim(mdl);
reference=load(fullfile(root,'.build','speed_loop_stage1','after_sim.mat'),'corrected');names=reference.corrected.who;checked={};
for k=1:numel(names)
 name=names{k};a=reference.corrected.get(name);if ~isa(a,'timeseries'),continue;end;b=o.get(name);
 assert(isequaln(a.Time,b.Time)&&isequaln(a.Data,b.Data),'1s baseline changed: %s',name);checked{end+1}=name; %#ok<AGROW>
end
assert(numel(checked)==12);fprintf('OBS_RELOAD_1S_12_SIGNALS_IDENTICAL\n');
unresolved=find_system(mdl,'LookUnderMasks','all','FollowLinks','off','LinkStatus','unresolved');assert(isempty(unresolved));
snap=teach_snapshot(mdl);assert(numel(snap.regions)==9);for k=1:9,assert(isequal(snap.regions(k).position(3:4)-snap.regions(k).position(1:2),[860 580]));end
result=struct('model_sha256',teach_hash(source),'matlab',version,'default_1s_identical_signals',{checked}, ...
 'unresolved_links',0,'equal_regions',9,'region_size',[860 580], ...
 'total_blocks',numel(snap.blocks),'root_blocks',numel(find_system(mdl,'SearchDepth',1,'Type','Block')),'all_passed',true);
teach_writejson(fullfile(folder,'observation_reload_check.json'),result);
report.root_blocks=result.root_blocks;teach_writejson(fullfile(folder,'observation_validation.json'),report);
clear o reference
fprintf('OBS_DEMO_CHECK\n');[outputs,record]=run_observation_demo('firmware_io');
assert(numel(outputs)==3&&record.pi_gains_unchanged&&~record.complete_board_emulation);
assert(isequaln(settings,teach_settings(mdl)));assert(strcmp(teach_hash(source),result.model_sha256));
fprintf('OBSERVATION_RELOAD_AND_DEMO_PASS\n');
end
