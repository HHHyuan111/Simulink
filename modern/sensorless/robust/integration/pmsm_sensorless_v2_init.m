function pmsm_sensorless_v2_init(mdl)
% Numerical only: never write Mask or diagram properties during compile.
pmsm_sensorless_init_n3(mdl);
c=sensorless_robust_config;ws=get_param(mdl,'ModelWorkspace');
extra=getVariable(ws,'sless_v2_interference_s');
n=getVariable(ws,'sless_cfg');
v=sensorless_v2_config_values(n(1),n(2),str2double(get_param([mdl '/采样设置'],'adc_span')),...
 str2double(get_param([mdl '/采样设置'],'adc_bits')),strcmp(get_param([mdl '/时序设置'],'window_on'),'on'),extra);
assert(abs(getVariable(ws,'timing_h')-c.h_s)<1e-15);
assert(max(abs(getVariable(ws,'timing_control_sample')-[c.period_s c.adc_trigger_s+3*c.adc_rank_s]))<1e-15);
assignin(ws,'sless_v2_cfg',v);
end
