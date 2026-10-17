function [counters,event,changed]=sless_r2_monitor_block(t,pub,permit,reason,adc_valid,timing_valid,reset,truth_theta,truth_rpm)
%#codegen
persistent s
if isempty(s),s=sensorless_r2_monitor_state;end
[s,counters,event,changed]=sensorless_r2_monitor_step(s,t,pub,permit,reason,adc_valid,timing_valid,reset,truth_theta,truth_rpm,62.5e-9,50e-6);
end
