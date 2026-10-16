function result=validate_feedback_effects_replay
root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'teaching'));
m='PMSM_FOC_R2026a';assert(~bdIsLoaded(m),'请在独立MATLAB进程执行。');
load_system(fullfile(root,[m '.slx']));guard=onCleanup(@()close_system(m,0));pmsm_reference('restore');
latest=jsondecode(fileread(fullfile(root,'signal_chain','feedback_effects_latest.json')));assert(latest.passed);
result=struct('passed',true,'checks',{{}});
for folder={latest.delay2_folder,latest.filter500_folder}
 [r,v]=repeat_pmsm_experiment(folder{1});assert(v.all_exact);
 result.checks{end+1}=struct('source_folder',folder{1},'repeat_folder',r.folder,'comparison',v);
end
teach_writejson(fullfile(root,'signal_chain','feedback_effects_replay.json'),result);disp('FEEDBACK_EFFECTS_REPLAY_VALIDATED');
end
