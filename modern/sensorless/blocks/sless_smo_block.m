function [estimate,residual,injection]=sless_smo_block(current,voltage,valid,reset,cfg)
%#codegen
persistent previous
if isempty(previous),previous=struct('i',zeros(2,1),'z',zeros(2,1));end
c=sensorless_rt_config(cfg);
[previous,diag]=sensorless_smo_step(previous,current,voltage,c,valid,reset);
estimate=previous.i;residual=diag.residual;injection=previous.z;
end
