function [current,calibrated,valid,adc_valid,timing_valid,meta]=sless_r2_ingress_block(t,measured,adc,diag,cfg,missing,reset)
%#codegen
persistent s
if isempty(s),s=sensorless_v2_measure_state;end
c=sensorless_v2_config_rt(cfg);
[s,current,calibrated,valid,adc_valid,timing_valid,meta]=sensorless_r2_ingress_step(s,t,measured,adc,diag,c,missing,reset);
end
