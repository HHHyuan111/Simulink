function [voltage,diag]=sensorless_bridge_estimate(gates,current_ABC,emf_ABC,bus,c)
%#codegen
% Estimated switched bridge. Inputs are calibrated current and previous EMF.
% No rotor angle/speed, true motor state, terminal voltage or plant Ron/Vf.
assert(numel(gates)==6&&numel(current_ABC)==3&&numel(emf_ABC)==3);
assert(all(isfinite(gates(:)))&&all(isfinite(current_ABC(:)))&&all(isfinite(emf_ABC(:))));
assert(isscalar(bus)&&isfinite(bus)&&bus>=0&&c.Ron_hat_ohm>=0&&c.Vf_hat_V>=0);
g=reshape(gates,6,1)>.5;assert(~any(g(1:2:5)&g(2:2:6)),'sensorless:ShootThrough','Invalid gate state.');
i=reshape(current_ABC,3,1);zero_sequence=mean(i);i=i-zero_sequence;
e=reshape(emf_ABC,3,1);assert(abs(sum(e))<=1e-9*(1+max(abs(e))),'sensorless:EMFSequence','EMF must be a zero-sequence-free estimate.');
pole=zeros(3,1);path=zeros(3,1);fixed=false(3,1);ambiguous=false(3,1);
upper=bus/2+c.Vf_hat_V;lower=-bus/2-c.Vf_hat_V;
for k=1:3
 if g(2*k-1),pole(k)=bus/2-c.Ron_hat_ohm*i(k);fixed(k)=true;path(k)=2;
 elseif g(2*k),pole(k)=-bus/2-c.Ron_hat_ohm*i(k);fixed(k)=true;path(k)=-2;
 elseif i(k)>c.zero_current_A,pole(k)=lower;fixed(k)=true;path(k)=-1;
 elseif i(k)<-c.zero_current_A,pole(k)=upper;fixed(k)=true;path(k)=1;
 else,ambiguous(k)=true;
 end
end
for pass=1:4
 count=sum(double(fixed));neutral=0;
 if count>0,neutral=(sum(pole.*double(fixed))+sum(e.*double(~fixed)))/count;end
 changed=false;
 for k=1:3
  if ~fixed(k)
   pole(k)=e(k)+neutral;
   if pole(k)>upper,pole(k)=upper;fixed(k)=true;path(k)=1;changed=true;
   elseif pole(k)<lower,pole(k)=lower;fixed(k)=true;path(k)=-1;changed=true;
   end
  end
 end
 if ~changed,break;end
end
phase=pole-mean(pole);
voltage=[(2*phase(1)-phase(2)-phase(3))/3;(phase(2)-phase(3))/sqrt(3)];
diag=struct('phase_voltage_V',phase,'pole_voltage_V',pole,'path',path,...
 'ambiguous_phase',ambiguous,'current_zero_sequence_A',zero_sequence,...
 'voltage_confident',~any(ambiguous)&&abs(zero_sequence)<=c.zero_sequence_max_A);
end
