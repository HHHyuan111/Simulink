function result=open_pmsm_electrical_scope
teach=fileparts(mfilename('fullpath'));root=fileparts(teach);
addpath(root,fullfile(root,'layout','appearance'));
if ~bdIsLoaded('PMSM_FOC_R2026a'),open_pmsm_model;end
pmsm_native_scope('install'); % Keep display guards in the documented order.
result=pmsm_electrical_scope('open');
end
