function [values,permit,reason,diagnostic]=sless_r2_queue_block(t,theta,omega,observer_valid,input_valid,timing_valid,cfg,reset,missing,jitter)
%#codegen
persistent s
if isempty(s),s=sensorless_r2_fault_queue_state;end
c=sensorless_v2_config_rt(cfg);
[s,values,permit,reason,diagnostic]=sensorless_r2_fault_queue_step(s,t,theta,omega,observer_valid,input_valid,timing_valid,reset,missing,jitter,c);
end
