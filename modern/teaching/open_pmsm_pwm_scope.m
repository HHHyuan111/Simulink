function result=open_pmsm_pwm_scope
teach=fileparts(mfilename('fullpath'));root=fileparts(teach);
addpath(root,fullfile(root,'layout','appearance'));
if ~bdIsLoaded('PMSM_FOC_R2026a'),open_pmsm_model;end
result=pmsm_pwm_scope('open');
end
