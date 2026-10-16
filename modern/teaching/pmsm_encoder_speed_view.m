function path=pmsm_encoder_speed_view(value)
if nargin<1,value=[];end
p=pmsm_experiment_plan('encoder_speed',value);mdl='PMSM_FOC_R2026a';
if ~bdIsLoaded(mdl),load_system(fullfile(fileparts(fileparts(mfilename('fullpath'))),[mdl '.slx']));end
if pmsm_encoder_speed_model('installed',mdl),pmsm_encoder_speed_model('remove',mdl);end
if pmsm_encoder_model('installed',mdl),pmsm_encoder_model('remove',mdl);end
assert(isequaln(pmsm_reference('capture'),p.baseline_state),'先恢复固定参考。');pmsm_reference('restore');
pmsm_encoder_model('install',mdl);cfg=p.encoder_configurations;
for key=fieldnames(cfg)',set_param([mdl '/角度设置/编码器'],key{1},cfg.(key{1}));end
path=pmsm_encoder_speed_model('install',mdl);cfg=p.speed_configuration;
for key=fieldnames(cfg)',set_param(path,key{1},cfg.(key{1}));end
open_system(path);set_param(path,'ZoomFactor','FitSystem');
end
