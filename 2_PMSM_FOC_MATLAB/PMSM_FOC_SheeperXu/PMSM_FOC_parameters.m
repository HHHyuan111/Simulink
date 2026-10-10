%------------------------------------------------------------
%Parameters of PMSM_FOC_AEEICWork 2023/11
%Simulink Document: PMSM_FOC
%Editor: SheeperXu
%Data: 2023/12/5
%------------------------------------------------------------
clear all;
clc;
%------------------------------------------------------------
%   Simulation variables
%------------------------------------------------------------
T = 1e-6; %Simulation Period

% Machine Parameters
Pn = 200;    %额定功率(W)
Un=24; %额定电压(V)
In=9.2; %额定电流(A)
n=3000; %额定转速(r/min)
p=4; %极对数
J=0.21e-4; %转动惯量(kgm^2)
F=0.0001; %阻尼系数(Nms)


fN=p*n/60; %额定频率（Hz)=np/60
wN=2*pi*fN; 
% Electrical Parameters
Vdc=24; %DC Voltage(s)
%Resistance
Rs=0.14; %电枢电阻(om)
%Inductance
Ld=0.12e-3; %直轴电感(H)
Lq=0.12e-3; %交轴电感(H)
Ls=Ld; %隐极式，电枢电感(H)
%Flux linkage
phis=0.0054; %永磁磁链(Wb)
%Rotary Encoder
RE=1024; 
rr=2*pi/1024; %resolution ratio

Tn=1.5*p*phis*In; %额定Te
%------------------------------------------------------------
%   Control variables
%------------------------------------------------------------
ki_p = 0.8;    %内环 p  0.8
ki_i =1;     %内环 i  15

fc=20e3;%SVPWM-Carrier PWM frequency(Hz)
Ts = 1/fc; % Carrior Period(s)
dt =Ts; %Sampling Period(s)

w_sb=2*pi*fN*1.2;  %外环i  0.0106

fcb=1000 %Hz Current Loop BandWidth
fwb=50 %Hz Rotation Speed Loop BandWidth
% From: Control_Loop_Calculation.m
%------------------------------------------------------------
%   PI variables
%------------------------------------------------------------
wc=2*pi*1000; % BandWidht of Current Loop
wsc=2*pi*50; % BandWidth of Speed Loop
K=30/pi*1.5*phis*p;
%----------------
%转速w
%----------------
kp_w=J*wsc/K;     
ki_w=kp_w*wsc/5;  
% Another One
% h=2.1;
% kp_w=pi*J/225/p/phis/Ts/10^(h/2);
% ki_w=pi*J/1125/p/phis/Ts^2/10^(3*h/2);

ks_w=1.5*kp_w;
Bm=0;
uplimit_w=1.2*Tn;
downlimit_w=-1.2*Tn;
%----------------
%%电流id
%----------------
kp_id=Ld*wc;
ki_id=Rs*wc;
ks_id=1.5*kp_id;
uplimit_id=Vdc/sqrt(3);
downlimit_id=-Vdc/sqrt(3);
%----------------
%电流iq
%----------------
kp_iq=Lq*wc;
ki_iq=Rs*wc;
ks_iq=1.5*kp_iq;
uplimit_iq=Vdc/sqrt(3);
downlimit_iq=-Vdc/sqrt(3);

