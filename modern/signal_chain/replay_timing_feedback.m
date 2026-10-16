function result=replay_timing_feedback
root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'teaching'));
m='PMSM_FOC_R2026a';assert(~bdIsLoaded(m));load_system(fullfile(root,[m '.slx']));guard=onCleanup(@()close_system(m,0));pmsm_reference('restore');
latest=jsondecode(fileread(fullfile(root,'signal_chain','timing_feedback_latest.json')));
[r,v]=repeat_pmsm_experiment(latest.folder);assert(v.all_exact);
result=struct('passed',true,'source_folder',latest.folder,'repeat_folder',r.folder,'comparison',v);
teach_writejson(fullfile(root,'signal_chain','timing_feedback','replay.json'),result);disp('TIMING_FEEDBACK_REPLAY_VALIDATED');
end
