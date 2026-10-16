function [ta_old,tb_old,tc_old]= fcn(Ualpha_ref,Ubeta_ref,Udc)

%%%%%%%%%%%%%%%%%%%%%%%%%%  SVPWM  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Us_ref = Ualpha_ref + Ubeta_ref*1j;     % 构造电压矢量
duty = abs(Us_ref)*sqrt(3)/Udc;         % 计算调制度
theta_Uref = mod(angle(Us_ref),2*pi);   % 取电压矢量角

%%%%%%%%%%%%%%%%%%%%%%%%%%% SVPWM %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Ta = 0.5;
Tb = 0.5;
Tc = 0.5;
sector = floor(theta_Uref/(pi/3));      % 取电压矢量所在扇区号
theta_Uref = theta_Uref - sector*pi/3;  % 取单个扇区内矢量角度
t1 = duty * sin(pi/3-theta_Uref);
t2 = duty * sin(theta_Uref);
if (sector==1)||(sector==3)||(sector==5)
    ttemp=t1;
    t1=t2;
    t2=ttemp;
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 此处改为T1 T2 T3是为了明确一个物理含义，t1 代表先跳变的一相；
% 例如 扇区 I 对应ABC三相的跳变顺序是  A - B - C ，所以按照Ta = T1,Tb = T2,Tc = T3
%  计算中间变量
T1=(1-t1-t2)/2;                       % 除去基本矢量所去的时间  再乘 1/2
T2=T1+t1;                           % 加上基本矢量1作用时间  
T3=T2+t2;                           % 加上基本矢量2作用时间   

%  切换时间
switch sector                             
    case 0                               % 如果在 I 区 
        Ta=T1;
        Tb=T2;
        Tc=T3;
    case 1
        Ta=T2;
        Tb=T1;
        Tc=T3;
    case 2
        Ta=T3;
        Tb=T1;
        Tc=T2;
    case 3
        Ta=T3;
        Tb=T2;
        Tc=T1;
    case 4
        Ta=T2;
        Tb=T3;
        Tc=T1;
    case 5
        Ta=T1;
        Tb=T3;
        Tc=T2;
end

    dutyA = 1-Ta;
    dutyB = 1-Tb;
    dutyC = 1-Tc;

%%%%%%%% 数值保存与传递 %%%%%%%
    ta_old = dutyA;
    tb_old = dutyB;
    tc_old = dutyC;
