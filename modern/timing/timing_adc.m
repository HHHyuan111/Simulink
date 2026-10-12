function [sample,diag,codes] = timing_adc(t,current,gates,cfg)
%#codegen
% cfg: on, window, hold-invalid, h, Ts, trigger, aperture, rank, sync, guard, speed divider.
% Quantized event grid; outputs are published together at JEOS, in A/B/C order.
persistent captured delivered valid elapsed aperture_ok last_good raw_codes
if isempty(captured)
 captured=zeros(1,3);delivered=zeros(1,3);valid=zeros(1,3);
 elapsed=zeros(1,3);aperture_ok=ones(1,3);last_good=zeros(1,3);raw_codes=2048*ones(1,3);
end
sample=delivered;codes=raw_codes;diag=zeros(1,15);
if cfg(1)==0,return;end
h=cfg(4);N=round(cfg(5)/h);tick=round(t/h);phase=mod(tick,N);
tr=round((cfg(6)+cfg(9))/h);ap=round(cfg(7)/h);rank=round(cfg(8)/h);
guard=ceil(cfg(10)/h);pulse=zeros(1,5);
if phase==tr,pulse(1)=1;end
for k=1:3
 % Gates are sampled one grid tick earlier to avoid an algebraic gate loop.
 if gates(2*k)>0.5,elapsed(k)=elapsed(k)+1;else,elapsed(k)=0;end
 r=3-k;start=tr+r*rank;finish=start+ap;
 if phase==start,aperture_ok(k)=double(elapsed(k)>guard);end
 if phase>=start && phase<=finish && elapsed(k)<=guard,aperture_ok(k)=0;end
 if phase==finish
  valid(k)=aperture_ok(k);pulse(r+2)=1;
 end
 % Input read buffer is one tick old. Read on the following tick so the
 % captured physical value remains exactly at the aperture endpoint.
 if phase==finish+1
  captured(k)=current(k);
  % Low-side OFF has no phase-current observation. Zero is an explicit
  % teaching approximation, not a calibrated amplifier switching transient.
  if cfg(2)>0 && valid(k)==0,captured(k)=0;end
  if valid(k)>0,last_good(k)=captured(k);end
  if cfg(2)>0 && cfg(3)>0 && valid(k)==0,captured(k)=last_good(k);end
 end
end
jeos=tr+3*rank;
if phase==jeos
 delivered=captured;raw_codes=min(4095,max(0,round(2048+captured/(165/4096))));pulse(5)=1;
end
sample=delivered;codes=raw_codes;
% Phase, trigger, C/B/A hold pulses, JEOS, validity ABC, sampled ABC, sum.
diag=[phase*h pulse(1:4) pulse(5) valid delivered sum(delivered) ...
       double(mod(floor(tick/N),cfg(11))==cfg(11)-1 && phase==jeos) double(phase==jeos)];
end
