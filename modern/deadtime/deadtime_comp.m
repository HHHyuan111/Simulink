function [dq,diagnostic] = deadtime_comp(current,theta,Vdc,cfg)
%#codegen
% cfg = [enable, compensated deadtime, PWM period, current hysteresis].
% Uses measured current ONLY. Positive phase current needs positive voltage
% correction. Correction enters BEFORE the existing final dq circle limit.
persistent polarity
if isempty(polarity),polarity=zeros(1,3);end
dq=zeros(1,2);diagnostic=zeros(1,8);
if cfg(1)==0,return;end
i=reshape(current,1,3);
for k=1:3
 if i(k)>cfg(4),polarity(k)=1;
 elseif i(k)<-cfg(4),polarity(k)=-1;
 end
end
abc=max(Vdc,0)*cfg(2)/cfg(3)*polarity;abc=abc-sum(abc)/3;
alpha=(2*abc(1)-abc(2)-abc(3))/3;beta=(abc(2)-abc(3))/sqrt(3);
dq=[alpha*cos(theta)+beta*sin(theta),-alpha*sin(theta)+beta*cos(theta)];
diagnostic=[abc dq polarity];
end
