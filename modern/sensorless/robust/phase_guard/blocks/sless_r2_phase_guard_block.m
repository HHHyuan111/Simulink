function [packet_valid,diagnostic]=sless_r2_phase_guard_block(theta,vector,quality,sample_valid,reset,cfg)
%#codegen
[packet_valid,diagnostic]=sensorless_r2_phase_guard(theta,vector,quality,sample_valid,reset,cfg(16));
end
