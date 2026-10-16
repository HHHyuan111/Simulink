function [phase,diagnostic] = bridge_freewheel(gates,state,Vdc,cfg)
%#codegen
% Static switched bridge for the present non-salient floating-star PMSM.
% cfg = [pole pairs, flux, zero-current band, drop enable, Ron, Vf].
% Positive current flows from pole to motor. During both-OFF, positive
% current uses the lower diode; negative current uses the upper diode.
x=reshape(state,1,4);g=reshape(gates,1,6);bus=max(Vdc,0);
theta=cfg(1)*x(4)+[0 -2*pi/3 2*pi/3];
current=x(1)*cos(theta)-x(2)*sin(theta);
emf=-cfg(1)*x(3)*cfg(2)*sin(theta);
pole=zeros(1,3);path=zeros(1,3);fixed=false(1,3);
ron=cfg(4)*cfg(5);vf=cfg(4)*cfg(6);
for k=1:3
 hi=g(2*k-1)>0.5;lo=g(2*k)>0.5;assert(~(hi&&lo));
 if hi,pole(k)=bus/2-ron*current(k);fixed(k)=true;
 elseif lo,pole(k)=-bus/2-ron*current(k);fixed(k)=true;
 elseif current(k)>cfg(3),pole(k)=-bus/2-vf;path(k)=-1;fixed(k)=true;
 elseif current(k)<-cfg(3),pole(k)=bus/2+vf;path(k)=1;fixed(k)=true;
 end
end
% Near zero, a disconnected phase follows its open-circuit EMF until a
% diode rail is reached. Small current band is a declared numerical model,
% not a device capacitance or exact diode complementarity solver.
neutral=0;
for pass=1:4
 count=sum(double(fixed));if count>0,neutral=sum((pole-emf).*double(fixed))/count;end
 changed=false;
 for k=1:3
  if ~fixed(k)
   pole(k)=emf(k)+neutral;
   if pole(k)>bus/2+vf,pole(k)=bus/2+vf;path(k)=1;fixed(k)=true;changed=true;
   elseif pole(k)<-bus/2-vf,pole(k)=-bus/2-vf;path(k)=-1;fixed(k)=true;changed=true;
   end
  end
 end
 if ~changed,break;end
end
% For near-zero open phases the neutral above enforces zero derivative;
% all fixed phases satisfy the usual floating-star mean subtraction.
phase=pole-sum(pole)/3;
diagnostic=[path pole current];
end
