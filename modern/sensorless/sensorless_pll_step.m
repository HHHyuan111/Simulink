function [next,o]=sensorless_pll_step(previous,vector,c,enabled,reset)
% vector=[cos(theta);sin(theta)] times any positive amplitude.
% o.theta is at CURRENT input time; next.theta predicts the NEXT input time.
if reset
 next=struct('theta',0,'integral',0,'omega',0);
 o=struct('theta',0,'omega',0,'error',0,'integral',0,'saturated',false);return;
end
theta=previous.theta;mag=hypot(vector(1),vector(2));err=0;inte=previous.integral;
if enabled&&mag>0
 x=vector(1)/mag;y=vector(2)/mag;
 err=y*cos(theta)-x*sin(theta);
 trial=inte+c.pll_Ki*c.sample_s*err;raw=c.pll_Kp*err+trial;
 % Conditional integration: do not deepen output saturation.
 if abs(raw)<=c.omega_limit_rad_s||raw*(trial-inte)<=0,inte=trial;end
 raw=c.pll_Kp*err+inte;
else
 raw=previous.omega;
end
omega=max(-c.omega_limit_rad_s,min(c.omega_limit_rad_s,raw));
saturated=abs(raw)>c.omega_limit_rad_s;
next=struct('theta',mod(theta+c.sample_s*omega,2*pi),'integral',inte,'omega',omega);
o=struct('theta',theta,'omega',omega,'error',err,'integral',inte,'saturated',saturated);
end
