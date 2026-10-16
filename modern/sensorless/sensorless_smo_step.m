function [next,d]=sensorless_smo_step(previous,imeas,vprevious,c,sample_valid,reset)
% Two-axis implicit saturation correction, at the current sample timestamp.
% vprevious: RL-weighted physical voltage in [t[k-1],t[k]].
imeas=reshape(imeas,2,1);vprevious=reshape(vprevious,2,1);
if reset
 next=struct('i',zeros(2,1),'z',zeros(2,1));
 d=struct('residual',zeros(2,1),'prediction',zeros(2,1),'corrected',false);return;
end
prediction=c.a*previous.i+c.b*vprevious;
if sample_valid
 delta=prediction-imeas;residual=zeros(2,1);
 for axis=1:2
  if abs(delta(axis))<=c.boundary_A+c.b*c.Kslide_V
   residual(axis)=delta(axis)/(1+c.b*c.g);
  else
   residual(axis)=delta(axis)-c.b*c.Kslide_V*sign(delta(axis));
  end
 end
 z=c.Kslide_V*max(-1,min(1,residual/c.boundary_A));
 next=struct('i',imeas+residual,'z',z);
else
 % No artificial new measurement correction; model prediction only.
 next=struct('i',prediction-c.b*previous.z,'z',previous.z);
 residual=zeros(2,1);
end
d=struct('residual',residual,'prediction',prediction,'corrected',logical(sample_valid));
end
