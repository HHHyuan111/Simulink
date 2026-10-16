function [gates,blank] = gate_deadtime(t,request,cfg)
%#codegen
% cfg = [enable, event grid, programmed deadtime]. Fall immediately;
% delay each rising edge. A pulse shorter than deadtime is suppressed.
persistent previous rise armed active
if isempty(previous)
 previous=zeros(1,6);rise=zeros(1,6);armed=false(1,6);active=zeros(1,6);
end
r=double(reshape(request,1,6)>0.5);gates=r;blank=zeros(1,3);
if cfg(1)==0,return;end
assert(all(r(1:2:5)+r(2:2:6)<=1));
tick=round(t/cfg(2));delay=round(cfg(3)/cfg(2));
for k=1:6
 if r(k)==0
  active(k)=0;armed(k)=false;
 elseif previous(k)==0
  rise(k)=tick;armed(k)=true;active(k)=0;
 end
 if armed(k)&&tick-rise(k)>=delay,active(k)=1;armed(k)=false;end
end
previous=r;gates=active;
assert(all(gates(1:2:5)+gates(2:2:6)<=1));
blank=1-gates(1:2:5)-gates(2:2:6);
end
