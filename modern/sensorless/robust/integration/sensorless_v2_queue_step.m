function [s,values,permit,reason]=sensorless_v2_queue_step(s,t,theta,omega,observer_valid,input_valid,timing_valid,c)
%#codegen
% Capture exactly once at JEOS. Publish the captured result at readiness,
% independently of later changes to held inputs while the job is computing.
tick=round(t/c.h_s);N=round(c.period_s/c.h_s);
first=round((c.adc_trigger_s+c.adc_sync_s+3*c.adc_rank_s)/c.h_s);
capture=tick>=first&&mod(tick-first,N)==0;
if ~input_valid||~timing_valid,s.fault_latched=true;s.observed_unlocked=false;end
if capture&&tick~=s.last_capture
 cycle=round((tick-first)/N);e=sensorless_event_plan(cycle,0,c.interference_s,c);
 s.pending=struct('sequence',cycle,'reference_time_s',tick*c.h_s,...
  'available_time_s',e.observer_available_s,'theta_rad',theta,'omega_e_rad_s',omega,...
  'input_valid',input_valid,'observer_valid',observer_valid,'timing_valid',timing_valid);
 s.has_pending=true;s.last_capture=tick;
end
present=s.has_pending&&tick>=round(s.pending.available_time_s/c.h_s);
% Query the next eligible application of the latest control frame. During
% computation keep the old packet's intended actuation time if still future.
cycle=max(0,floor((tick-first)/N));e=sensorless_event_plan(cycle,0,c.interference_s,c);
apply=e.actual_pwm_apply_s;
if t>apply
 spacing=c.period_s/(2-double(c.update_mode));apply=ceil((t+1e-15)/spacing)*spacing;
end
[s.output,o]=sensorless_publish_step(s.output,s.pending,present,t,apply,c,input_valid,timing_valid);
if present
 s.has_pending=false;
 if s.fault_latched
  if ~s.pending.observer_valid,s.observed_unlocked=true;
  elseif s.observed_unlocked&&input_valid&&timing_valid&&s.pending.input_valid&&s.pending.timing_valid
   s.fault_latched=false;
  end
 end
end
permit=o.control_permit;reason=double(o.reason);
if s.fault_latched,permit=false;reason=double(bitor(uint16(reason),uint16(512)));end
values=[o.sequence;o.reference_time_s;o.available_time_s;o.age_s;...
 o.theta_sample_rad;o.theta_now_rad;o.theta_pwm_rad;o.raw_speed_rpm;...
 o.control_theta_sample_rad;o.control_theta_pwm_rad;o.control_speed_rpm;apply;double(present)];
if ~permit,values(9:11)=0;end
end
