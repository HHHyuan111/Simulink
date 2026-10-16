function [theta,omega,error,integral,saturated,speed]=sless_pll_block(vector,magnitude,direction,valid,reset,enabled,cfg)
%#codegen
persistent previous
if isempty(previous),previous=struct('theta',0,'integral',0,'omega',0);end
c=sensorless_rt_config(cfg);
permission=enabled~=0&&valid&&direction~=0&&magnitude>=c.validity.emf_off_below_V;
[previous,diag]=sensorless_pll_step(previous,vector,c,permission,reset);
theta=diag.theta;omega=diag.omega;error=diag.error;
integral=diag.integral;saturated=diag.saturated;speed=omega/c.pole_pairs*60/(2*pi);
end
