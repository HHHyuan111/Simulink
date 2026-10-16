function [valid,state,history]=sless_validity_block(residual,error,magnitude,saturated,sample_valid,direction,reset,cfg)
%#codegen
persistent previous
c=sensorless_rt_config(cfg);
if isempty(previous),previous=sensorless_state(c);end
[previous,valid,state]=sensorless_validity_step(previous,residual,error,magnitude,saturated,sample_valid,direction,reset,c);
history=[previous.lock_count;previous.history_count;previous.unlock_count];
end
