function gates=startup_gate(request,control)
%#codegen
% control: enabled, current permit, speed permit, PWM permit.
gates=reshape(request,1,6);
if control(1)==0,return;end
if control(4)==0,gates=zeros(1,6);
elseif control(2)==0,gates=[0 1 0 1 0 1];
end
end
