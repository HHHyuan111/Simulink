function [front,missing,reset,jitter,interference,reference]=sless_r2_profile_block(t,base,program)
%#codegen
[front,missing,reset,jitter,interference,reference]=sensorless_r2_fault_profile(t,base,program);
end
