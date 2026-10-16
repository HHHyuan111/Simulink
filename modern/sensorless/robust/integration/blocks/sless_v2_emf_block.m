function [emf,vector,raw_angle,phase,magnitude,front_phase]=sless_v2_emf_block(injection,omega_previous,direction,valid,reset,cfg,front_cfg)
%#codegen
persistent previous
if isempty(previous),previous=zeros(2,1);end
c=sensorless_rt_config(cfg);f=sensorless_v2_config_rt(front_cfg);
if reset,omega_previous=0;end
[previous,d]=sensorless_emf_step(previous,injection,omega_previous,direction,c,valid,reset);
[front_phase,~]=sensorless_v2_front_phase(omega_previous,f);
emf=previous;rotation=[cos(front_phase) -sin(front_phase);sin(front_phase) cos(front_phase)];
vector=rotation*d.vector;raw_angle=d.raw_theta;phase=d.phase_correction;magnitude=d.magnitude;
end
