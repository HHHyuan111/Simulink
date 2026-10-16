function y = fcn(u,dutyA,dutyB,dutyC)

ref = u;              % 载波
CMPA = 1-dutyA;
CMPB = 1-dutyB;
CMPC = 1-dutyC;
Ta1=0;
Ta2=0;
Tb1=0;
Tb2=0;
Tc1=0;
Tc2=0;
if ref>=CMPA            % ref 就是一个三角波发生器  A相PWM波形成  累加的过程中 Taon 大于了三角波  就 A相下桥臂通 上桥臂关
    Ta1=1;            % 此时对应的epwm模块的逻辑是，在上升过程中，当CMPA = TPRD时，置为1；在下降的过程中，当CMPA = TPRD时，置为0；
    Ta2=0;                   %所以输入的值越大实际占空比越小；
elseif ref<CMPA
    Ta1=0;
    Ta2=1;
end

if ref>=CMPB
    Tb1=1;
    Tb2=0;
elseif ref<CMPB
    Tb1=0;
    Tb2=1;
end

if ref>=CMPC
    Tc1=1;
    Tc2=0;
elseif ref<CMPC
    Tc1=0;
    Tc2=1;
end

y=[Ta1;Ta2;Tb1;Tb2;Tc1;Tc2];

