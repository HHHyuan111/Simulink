function [id,iq] = fcn(ialpha,ibeta,theta)

% Park
id = ialpha * cos(theta)  + ibeta * sin(theta);
iq = -ialpha* sin(theta) + ibeta*cos(theta);

