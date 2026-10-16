function inspect_deadtime_source
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);addpath(fullfile(root,'teaching'));
work=fullfile(root,'.build','deadtime_stage');mdl='PMSM_FOC_R2026a';source=fullfile(root,[mdl '.slx']);
assert(strcmp(teach_hash(source),'db31d893ca9f0359e6b36e580056da9b74a46457f127da0c1bcccbab4775edec'));
copyfile(source,fullfile(work,'PMSM_FOC_before_deadtime.slx'));load_system(source);g=onCleanup(@()close_system(mdl,0));
before=teach_snapshot(mdl);mw=get_param(mdl,'ModelWorkspace');code=mw.MATLABCode;init=get_param(mdl,'InitFcn');
save(fullfile(work,'before.mat'),'before','code','init');
for name={'off','real'}
 copyfile(fullfile(root,'.build','timing_stage',[name{1} '.mat']),fullfile(work,['baseline_' name{1} '.mat']));
end
fprintf('DEADTIME_SOURCE_READY %d\n',numel(before.blocks));
end
