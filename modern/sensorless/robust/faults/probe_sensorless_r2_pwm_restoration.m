function report=probe_sensorless_r2_pwm_restoration(folder)
% Diagnose structural restoration without observer installation or simulation.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);mdl='PMSM_FOC_R2026a';
for d={'','sensorless','sensorless/robust','sensorless/robust/faults','teaching','control','timing','deadtime','framework','layout/appearance'},addpath(fullfile(modern,d{1}));end
assert(~bdIsLoaded(mdl)&&~isfolder(folder));mkdir(folder);cleanup=onCleanup(@()close_private(mdl));
load_system(fullfile(modern,[mdl '.slx']));pmsm_reference('restore');before=teach_snapshot(mdl);
backup=sensorless_r2_fault_pwm_model(mdl,zeros(1,22));sensorless_r2_restore_fault_pwm(backup);after=teach_snapshot(mdl);
save(fullfile(folder,'snapshots.mat'),'before','after','backup','-v7.3');report=struct('simulation_called',false,'all_passed',isequaln(before,after),'differences',{{}});
for k=1:numel(before.blocks)
 b=before.blocks(k);index=find(strcmp({after.blocks.path},b.path));
 if ~isscalar(index),report.differences{end+1}=struct('path',b.path,'field','missing_or_duplicate');continue;end
 for key=fieldnames(b)'
  if ~isequaln(b.(key{1}),after.blocks(index).(key{1})),report.differences{end+1}=struct('path',b.path,'field',key{1},'before',b.(key{1}),'after',after.blocks(index).(key{1}));end
 end
end
report.added_paths=setdiff({after.blocks.path},{before.blocks.path});report.scripts_equal=isequaln(before.scripts,after.scripts);
teach_writejson(fullfile(folder,'report.json'),report);
end
function close_private(mdl)
if bdIsLoaded(mdl),close_system(mdl,0);end
end
