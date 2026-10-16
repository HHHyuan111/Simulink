function [ialpha,ibeta] = fcn(ia,ib,ic)

% Clark 
ialpha = 2/3*ia - 1/3*ib - 1/3*ic;
ibeta = sqrt(3)/3*ib - sqrt(3)/3*ic;

