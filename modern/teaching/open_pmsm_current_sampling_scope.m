function result=open_pmsm_current_sampling_scope
teach=fileparts(mfilename('fullpath'));root=fileparts(teach);
addpath(root,fullfile(root,'layout','appearance'));
if ~bdIsLoaded('PMSM_FOC_R2026a'),open_pmsm_model;end
result=pmsm_current_sampling_scope('open');
if pmsm_signal_chain_view('installed'),pmsm_signal_chain_view('refresh');end
end
