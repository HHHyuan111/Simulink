function path=pmsm_speed_feedback_view(value)
if nargin<1,value=[];end
p=pmsm_experiment_plan('speed_feedback',value);mdl='PMSM_FOC_R2026a';
if ~bdIsLoaded(mdl),load_system(fullfile(fileparts(fileparts(mfilename('fullpath'))),[mdl '.slx']));end
if pmsm_encoder_model('installed',mdl),pmsm_encoder_model('remove',mdl);end
assert(isequaln(pmsm_reference('capture'),p.baseline_state),'先恢复固定参考。');pmsm_reference('restore');
pmsm_encoder_model('install',mdl);pmsm_encoder_speed_model('install',mdl);path=pmsm_speed_feedback_model('install',mdl);
cfg=p.encoder_configurations(1);for key=fieldnames(cfg)',set_param([mdl '/角度设置/编码器'],key{1},cfg.(key{1}));end
cfg=p.speed_configuration;for key=fieldnames(cfg)',set_param([mdl '/角度设置/编码器/测速'],key{1},cfg.(key{1}));end
set_param(path,'feedback_on','on','window_choice','2');open_system(path);set_param(path,'ZoomFactor','FitSystem');
end
