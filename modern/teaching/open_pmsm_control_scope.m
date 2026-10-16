function result=open_pmsm_control_scope
% Open the existing model's native Scope, not a separate plotting interface.
teach=fileparts(mfilename('fullpath'));root=fileparts(teach);addpath(root,fullfile(root,'layout','appearance'));
if ~bdIsLoaded('PMSM_FOC_R2026a'),open_pmsm_model;end
result=pmsm_native_scope('open');
end
