function [applied,diag] = timing_pwm(t,request,cfg)
%#codegen
% cfg: on, h, Ts, trigger, aperture, rank, sync, compute, update mode, ARR.
% mode=0: RCR=0 update at both extrema; mode=1: underflow-only comparison.
% If a write coincides with UEV, UEV wins and the new CCR waits for the next UEV.
persistent shadow active pending shadow_seq active_seq writes stamp delay
if isempty(shadow)
 shadow=cfg(3)/4*ones(1,3);active=shadow;pending=false;
 shadow_seq=0;active_seq=0;writes=0;stamp=0;delay=0;
end
applied=active;diag=zeros(1,12);
if cfg(1)==0,return;end
h=cfg(2);N=round(cfg(3)/h);tick=round(t/h);phase=mod(tick,N);
jeos=round((cfg(4)+cfg(7)+3*cfg(6))/h);wr=jeos+round(cfg(8)/h);
update=(phase==0 || (cfg(9)==0 && phase==N/2));write=(phase==wr);
latched=false;
if update && pending
 active=shadow;active_seq=shadow_seq;pending=false;latched=true;delay=t-stamp;
end
if write
 duty=max(0,min(1,1-2*reshape(request,1,3)/cfg(3)));
 ccr=floor(duty*cfg(10)+1e-9);
 shadow=cfg(3)/2*(1-ccr/cfg(10));shadow_seq=shadow_seq+1;
 writes=writes+1;pending=true;stamp=floor(tick/N)*cfg(3)+jeos*h;
end
applied=active;
cnt=2*min(phase,N-phase)/N*cfg(10);
diag=[cnt double(phase>=N/2) double(update) double(write) double(latched) ...
 shadow_seq active_seq double(pending) delay shadow];
end
