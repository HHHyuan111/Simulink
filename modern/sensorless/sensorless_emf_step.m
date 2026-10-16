function [filtered,o]=sensorless_emf_step(previous,z,omega,direction,c,update,reset)
% Separate extraction filter and causal full-chain phase correction.
if reset,filtered=zeros(2,1);else
 filtered=previous;
 if update,filtered=c.filter_r*previous+(1-c.filter_r)*z;end
end
omega=max(-c.omega_limit_rad_s,min(c.omega_limit_rad_s,omega));
angle=omega*c.sample_s;
phase=angle+atan2(c.observer_pole*sin(angle),1-c.observer_pole*cos(angle))...
 +atan2(c.filter_r*sin(angle),1-c.filter_r*cos(angle));
% Gobs assumes e[k-1] is constant. A rotating physical EMF instead has
% RL-weighted interval factor W=(exp(j*angle)-a)/(L*b*(R/L+j*omega)).
% Its argument must be subtracted once, not hidden in a fixed extra delay.
if strcmp(c.interval_convention,'rl_weighted_rotating')
 phase=phase-atan2(sin(angle),cos(angle)-c.a)+atan2(omega,c.R_hat/c.L_hat);
end
rawvector=direction*[filtered(2);-filtered(1)];
rotation=[cos(phase),-sin(phase);sin(phase),cos(phase)];
vector=rotation*rawvector;
o=struct('vector',vector,'raw_theta',mod(atan2(rawvector(2),rawvector(1)),2*pi),...
 'phase_correction',phase,'magnitude',hypot(filtered(1),filtered(2)));
end
