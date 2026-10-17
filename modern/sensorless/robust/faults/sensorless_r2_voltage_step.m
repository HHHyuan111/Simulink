function [s,weighted,interval,ready,native,uncertainty]=sensorless_r2_voltage_step(s,t,threshold,carrier,bus,sequence,aligned_ABC,vector_previous,omega_previous,direction,c,anchor_valid)
%#codegen
% Derived from frozen local R1; equations unchanged, current anchors admitted.
% Firmware-known applied thresholds -> estimated deadtime -> bridge ->
% analog filter -> RL interval -> digital filter. No terminal-voltage tap.
h=c.h_s;Ts=c.period_s;tick=round(t/h);N=round(Ts/h);
first=round((c.adc_trigger_s+c.adc_sync_s+3*c.adc_rank_s)/h);
rho=exp(-c.R_hat*h/c.L_hat);ra=exp(-2*pi*c.analog_hz*h);
rd=exp(-2*pi*c.digital_hz*Ts);
[~,front_magnitude]=sensorless_v2_front_phase(omega_previous,c);
e=zeros(2,1);
if direction~=0
 % Input vector already includes the separate front-end phase correction.
 corrected=vector_previous/max(.1,front_magnitude);
 e=direction*[-corrected(2);corrected(1)];
end
% Saturation here is an explicit estimator-domain bound, not a true EMF.
e=max(-bus,min(bus,e));emf_ABC=[e(1);-.5*e(1)+sqrt(3)/2*e(2);-.5*e(1)-sqrt(3)/2*e(2)];
if tick>s.last_tick
 assert(tick==s.last_tick+1,'sensorless:V2Grid','Native voltage tick skipped.');
 s.acc=rho*s.acc+(1-rho)*s.filtered;
 s.unc_acc=rho*s.unc_acc+(1-rho)*s.unc_filtered;
 s.filtered=ra*s.filtered+(1-ra)*s.u_previous;
 s.unc_filtered=ra*s.unc_filtered+(1-ra)*s.unc_previous;
 phase_u=[s.u_previous(1);-.5*s.u_previous(1)+sqrt(3)/2*s.u_previous(2);-.5*s.u_previous(1)-sqrt(3)/2*s.u_previous(2)];
 s.predicted_ABC=rho*s.predicted_ABC+(1-rho)/c.R_hat*(phase_u-emf_ABC);
end
boundary=tick>=first&&mod(tick-first,N)==0;
if boundary
 if s.started
  average=s.acc/(1-exp(-c.R_hat*Ts/c.L_hat));
  s.digital=rd*s.digital+(1-rd)*average;s.published=s.digital;
  s.unc_digital=rd*s.unc_digital+(1-rd)*s.unc_acc/(1-exp(-c.R_hat*Ts/c.L_hat));
  s.uncertainty=s.unc_digital;
  s.interval=[s.start_time;t];s.ready=true;
 else,s.interval=[t;t];s.started=true;
 end
 s.acc=zeros(2,1);s.unc_acc=zeros(2,1);s.start_time=t;
 s.published_ambiguous_duration=s.ambiguous_duration;s.ambiguous_duration=0;
 % A causal low-frequency lead estimate anchors the switching-sign model.
 % Its errors are not claimed bounded by the engineering sign allowance.
 if anchor_valid
  derivative=zeros(3,1);
  if s.anchor_count>0,derivative=(aligned_ABC-s.last_anchor)/Ts;end
  lag=1/(2*pi*c.analog_hz)+Ts*rd/(1-rd);
  s.predicted_ABC=max(-2*c.adc_span_A,min(2*c.adc_span_A,aligned_ABC+lag*derivative));
  s.last_anchor=aligned_ABC;s.anchor_count=s.anchor_count+1;
 else
  s.last_anchor=zeros(3,1);s.anchor_count=0;
 end
end
upper=carrier>=reshape(threshold,3,1);request=false(6,1);
request(1:2:5)=upper;request(2:2:6)=~upper;
[s.deadtime,gates,blank]=sensorless_deadtime_estimate_step(s.deadtime,t,request,c);
% Expand the ambiguous band without zeroing individual phases: zeroing one
% phase would inject a fictitious zero sequence and change other phases.
bridge_cfg=c;bridge_cfg.zero_current_A=c.zero_current_A+c.sign_allowance_A;
[u,d]=sensorless_bridge_estimate(gates,s.predicted_ABC,emf_ABC,bus,bridge_cfg);
pole_bound=zeros(3,1);
for k=1:3
 if d.ambiguous_phase(k),pole_bound(k)=bus/2+c.Vf_hat_V+abs(d.pole_voltage_V(k));end
end
bound=[2/3 1/3 1/3;0 1/sqrt(3) 1/sqrt(3)]*pole_bound;
if any(d.ambiguous_phase),s.ambiguous_duration=s.ambiguous_duration+h;end
s.u_previous=u;s.unc_previous=bound;s.last_tick=tick;
weighted=s.published;interval=s.interval;ready=s.ready;uncertainty=s.uncertainty;
native=[t;u;s.filtered;bound;double(gates);s.predicted_ABC;emf_ABC;double(d.ambiguous_phase);...
 double(blank);threshold(:);carrier;bus;sequence;double(boundary);double(ready);s.published_ambiguous_duration;s.unc_filtered];
end
