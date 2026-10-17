function [applied,diag]=sless_r2_pwm_block(t,request,cfg,program)
%#codegen
persistent s
if isempty(s),s=sensorless_r2_pwm_state(cfg);end
[s,applied,diag]=sensorless_r2_pwm_step(s,t,request,cfg,program);
end
