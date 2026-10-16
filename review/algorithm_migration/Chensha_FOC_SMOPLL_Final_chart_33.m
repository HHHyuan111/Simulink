function [Ualpha,Ubeta] = fcn(Uq,Ud,theta)

% iPark

Ualpha  = Ud*cos(theta) - Uq*sin(theta);
Ubeta = Ud*sin(theta) + Uq*cos(theta);


