function [front,missing,reset,jitter,interference,reference]=sensorless_r2_fault_profile(t,base,program)
%#codegen
h=base(1);N=round(base(2)/h);first=round((base(4)+base(7)+3*base(6))/h);tick=round(t/h);
reference=0;if tick>=first,reference=(first+floor((tick-first)/N)*N)*h;end
missing=false;reset=false;jitter=0;interference=0;
if program(1)==1,missing=reference>=program(2)-1e-12&&reference<program(3)-1e-12;
elseif program(1)==2,reset=reference>=program(4)-1e-12&&reference<program(5)-1e-12;
elseif program(1)==3
 for k=1:5
  if k<=program(6)&&reference>=program(8+3*(k-1))-1e-12,jitter=program(9+3*(k-1));interference=program(10+3*(k-1));end
 end
end
front=base;front(34)=base(34)+jitter+interference;
end
