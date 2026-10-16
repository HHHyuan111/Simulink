function[id,iq] = fcn(ia,ib,theta_act)
%%%%%%%%%%%%%%%%%%% theta 依据控制模式分流 %%%%%%%%%%%%%%%

    theta = theta_act;    

%%%%%%%%%%%%%%%%%%%%  clark + park %%%%%%%%%%%%%%%%%%%%%%%%%%%

ialpha = ia;                                         %3/2变换
ibeta = sqrt(3)/3*ia+2*sqrt(3)/3*ib;
id = ialpha * cos(theta)+ ibeta*sin(theta);          %帕克变换
iq = ialpha * -sin(theta)+ ibeta*cos(theta);

