function result=run_feedback_effects
% Extend existing fixed experiments; preserve all old archives and the SLX.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'teaching'));
m='PMSM_FOC_R2026a';assert(~bdIsLoaded(m),'请在独立MATLAB进程执行。');
load_system(fullfile(root,[m '.slx']));guard=onCleanup(@()close_system(m,0));pmsm_reference('restore');
hash=teach_hash(fullfile(root,[m '.slx']));
fprintf('FEEDBACK_EFFECTS_DELAY2\n');delay=run_pmsm_experiment('sample_delay',2,.2);
fprintf('FEEDBACK_EFFECTS_FILTER500\n');lowpass=run_pmsm_experiment('digital_filter',500,.2);
pmsm_experiment_verify(delay.folder);pmsm_experiment_verify(lowpass.folder);
assert(strcmp(hash,teach_hash(fullfile(root,[m '.slx']))));
result=struct('passed',true,'model_sha256',hash,'delay2_folder',delay.folder,'filter500_folder',lowpass.folder,...
 'delay2_record_sha256',teach_hash(fullfile(delay.folder,'record.json')),...
 'filter500_record_sha256',teach_hash(fullfile(lowpass.folder,'record.json')));
teach_writejson(fullfile(root,'signal_chain','feedback_effects_latest.json'),result);disp('FEEDBACK_EFFECTS_RUNS_COMPLETE');
end
