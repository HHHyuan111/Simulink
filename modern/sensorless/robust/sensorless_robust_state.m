function s=sensorless_robust_state
% Explicit state; no persistent variables and no motor truth.
s.deadtime=struct('last_tick',-1,'previous_request',false(6,1),...
 'rise_tick',zeros(6,1),'armed',false(6,1),'gates',false(6,1));
packet=struct('sequence',-1,'reference_time_s',0,'available_time_s',0,...
 'theta_rad',0,'omega_e_rad_s',0,'input_valid',false,'observer_valid',false,'timing_valid',false);
s.output=struct('has_packet',false,'packet',packet);
end
