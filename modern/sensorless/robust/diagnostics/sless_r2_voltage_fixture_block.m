function [threshold,carrier,bus,diag,current,vector,omega,direction,anchor]=sless_r2_voltage_fixture_block(t)
%#codegen
% Synthetic independent PWM and rotating-input fixture; no physical plant.
k=round(t/62.5e-9);omega=3000/60*2*pi*5;direction=1;bus=24;
cycle=floor(k/800);a=omega*cycle*50e-6;phase=mod(k,800);
threshold=.5+.4*sin([a a-2*pi/3 a+2*pi/3]);carrier=1-abs(2*phase/800-1);
diag=zeros(1,12);diag(7)=cycle;
angle=omega*t;current=2*sin([angle;angle-2*pi/3;angle+2*pi/3]);
vector=6*[cos(a);sin(a)];anchor=~((k>=4800462&&k<4804462)||(k>=9600462&&k<9601262));
end
