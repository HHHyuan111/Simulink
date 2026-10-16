function [phase,magnitude]=sensorless_v2_front_phase(omega,c)
%#codegen
% Continuous analog RC and local direct-feedthrough discrete digital IIR.
% Voltage matching uses a native ZOH RC approximation; O(h) discrepancy is
% retained in R2 physical performance, not hidden by truth-fitted rotation.
w=max(-c.omega_limit_rad_s,min(c.omega_limit_rad_s,omega));
rd=exp(-2*pi*c.digital_hz*c.period_s);a=w*c.period_s;
phase=atan2(w,2*pi*c.analog_hz)+atan2(rd*sin(a),1-rd*cos(a));
magnitude=(2*pi*c.analog_hz)/hypot(2*pi*c.analog_hz,w)*(1-rd)/hypot(1-rd*cos(a),rd*sin(a));
end
