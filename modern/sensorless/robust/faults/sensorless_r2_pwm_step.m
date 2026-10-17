function [s,applied,diag]=sensorless_r2_pwm_step(s,t,request,cfg,program)
%#codegen
% Physical actor: update wins ties; budgets bind to their own ADC job.
% Consume the request at the write, matching the original local actor.
applied=s.active;diag=zeros(1,12);if cfg(1)==0,return;end
h=cfg(2);N=round(cfg(3)/h);tick=round(t/h);phase=mod(tick,N);jeos=round((cfg(4)+cfg(7)+3*cfg(6))/h);
if phase==jeos&&tick~=s.last_capture
 assert(~s.job_pending,'sensorless:R2UnsupportedOverlap','Interrupt-job overlap is outside this actor; do not overwrite a job.');
 extra=0;
 for k=1:5
  if k<=program(6)&&t>=program(8+3*(k-1))-1e-12,extra=program(9+3*(k-1))+program(10+3*(k-1));end
 end
 s.reference=floor(tick/N)*cfg(3)+jeos*h;s.write_tick=tick+round((cfg(8)+extra)/h);s.job_pending=true;s.last_capture=tick;
end
update=phase==0||(cfg(9)==0&&phase==N/2);write=s.job_pending&&tick==s.write_tick&&tick~=s.last_write;latched=false;
if update&&s.pending,s.active=s.shadow;s.active_seq=s.shadow_seq;s.pending=false;latched=true;s.delay=t-s.stamp;end
if write
 duty=max(0,min(1,1-2*reshape(request,1,3)/cfg(3)));ccr=floor(duty*cfg(10)+1e-9);
 s.shadow=cfg(3)/2*(1-ccr/cfg(10));s.shadow_seq=s.shadow_seq+1;s.pending=true;s.stamp=s.reference;s.job_pending=false;s.last_write=tick;
end
applied=s.active;cnt=2*min(phase,N-phase)/N*cfg(10);
diag=[cnt double(phase>=N/2) double(update) double(write) double(latched) ...
 s.shadow_seq s.active_seq double(s.pending) s.delay s.shadow];
end
