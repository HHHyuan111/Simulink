function path=pmsm_encoder_view(value)
% Open the real, reversible module in the original model for teaching.
if nargin<1,value=[];end
p=pmsm_experiment_plan('encoder_angle',value);mdl='PMSM_FOC_R2026a';
if ~bdIsLoaded(mdl),load_system(fullfile(fileparts(fileparts(mfilename('fullpath'))),[mdl '.slx']));end
if pmsm_encoder_model('installed',mdl),pmsm_encoder_model('remove',mdl);end
assert(isequaln(pmsm_reference('capture'),p.baseline_state),'先恢复固定参考，再展开编码器。');
pmsm_reference('restore');path=pmsm_encoder_model('install',mdl);cfg=p.encoder_configurations(3);
for key=fieldnames(cfg)',set_param(path,key{1},cfg.(key{1}));end
open_system(path);set_param(path,'ZoomFactor','FitSystem');
end
