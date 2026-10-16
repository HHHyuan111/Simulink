function result=run_timing_feedback
% Independent worker; existing event architecture, only computation time differs.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'teaching'));
m='PMSM_FOC_R2026a';assert(~bdIsLoaded(m));load_system(fullfile(root,[m '.slx']));guard=onCleanup(@()close_system(m,0));pmsm_reference('restore');
hash=teach_hash(fullfile(root,[m '.slx']));
r=run_pmsm_experiment('timing_deadline',[5 10.5 15],.2);pmsm_experiment_verify(r.folder);
assert(strcmp(hash,teach_hash(fullfile(root,[m '.slx']))));
result=struct('passed',true,'folder',r.folder,'record_sha256',teach_hash(fullfile(r.folder,'record.json')),'model_sha256',hash);
teach_writejson(fullfile(root,'signal_chain','timing_feedback_latest.json'),result);disp('TIMING_FEEDBACK_COMPLETE');
end
