function [weighted,interval,ready,native,uncertainty]=sless_r2_voltage_block(t,threshold,carrier,bus,diag,current,vector_previous,omega_previous,direction,cfg,anchor_valid)
%#codegen
persistent s
if isempty(s),s=sensorless_v2_voltage_state;end
c=sensorless_v2_config_rt(cfg);
[s,weighted,interval,ready,native,uncertainty]=sensorless_r2_voltage_step(s,t,threshold,carrier,bus,diag(7),current,vector_previous,omega_previous,direction,c,anchor_valid);
end
