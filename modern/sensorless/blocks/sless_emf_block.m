function [emf,vector,raw_angle,phase,magnitude]=sless_emf_block(injection,omega_previous,direction,valid,reset,cfg)
%#codegen
persistent previous
if isempty(previous),previous=zeros(2,1);end
c=sensorless_rt_config(cfg);
if reset,omega_previous=0;end
[previous,diag]=sensorless_emf_step(previous,injection,omega_previous,direction,c,valid,reset);
emf=previous;vector=diag.vector;raw_angle=diag.raw_theta;
phase=diag.phase_correction;magnitude=diag.magnitude;
end
