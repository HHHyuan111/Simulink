function [values,permit,reason]=sless_v2_queue_block(t,theta,omega,observer_valid,input_valid,timing_valid,cfg)
%#codegen
persistent s
if isempty(s),s=sensorless_v2_queue_state;end
c=sensorless_v2_config_rt(cfg);
[s,values,permit,reason]=sensorless_v2_queue_step(s,t,theta,omega,observer_valid,input_valid,timing_valid,c);
end
