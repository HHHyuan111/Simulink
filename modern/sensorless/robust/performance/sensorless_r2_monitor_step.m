function [s,counters,event,changed]=sensorless_r2_monitor_step(s,t,pub,permit,reason,adc_valid,timing_valid,reset,truth_theta,truth_rpm,h,Ts)
%#codegen
% Every native grid tick is evaluated. Integer durations are accumulated
% over [previous tick,current tick); the final heartbeat closes the trace.
tick=round(t/h);assert(abs(t-tick*h)<1e-12);
if tick>s.last_tick
 if s.last_tick>=0
  assert(tick==s.last_tick+1,'sensorless:R2MonitorGrid','Evaluation skipped a native tick.');
  if s.last_bad,s.run=s.run+uint64(1);s.total_bad=s.total_bad+uint64(1);else,s.run=uint64(0);end
  s.max_run=max(s.max_run,s.run);
  if s.last_permit,s.total_permit=s.total_permit+uint64(1);end
 end
end
angle=atan2(sin(pub(6)-truth_theta),cos(pub(6)-truth_theta))*180/pi;
relative=abs(pub(8)-truth_rpm)/max(abs(truth_rpm),1);
bad=permit&&(abs(angle)>8||relative>.03);
violation=permit&&(~adc_valid||~timing_valid||reset||reason~=0||pub(4)>60e-6+1e-12||pub(3)>t+1e-12);
values_bad=~permit&&any(pub(9:11)~=0);
if tick>s.last_tick
 if violation,s.violation_ticks=s.violation_ticks+uint64(1);end
 if permit&&abs(truth_rpm)<=250,s.low_permit_ticks=s.low_permit_ticks+uint64(1);end
 if values_bad,s.value_violation_ticks=s.value_violation_ticks+uint64(1);end
end
if permit,s.max_angle_permit_deg=max(s.max_angle_permit_deg,abs(angle));s.max_relative_permit=max(s.max_relative_permit,relative);end
changed=tick==0||mod(tick,round(Ts/h))==0||pub(13)>.5||bad~=s.last_bad||permit~=s.last_permit||...
 reason~=s.last_reason||adc_valid~=s.last_adc||timing_valid~=s.last_timing||reset~=s.last_reset;
s.last_tick=tick;s.last_bad=bad;s.last_permit=permit;s.last_reason=reason;s.last_adc=adc_valid;s.last_timing=timing_valid;s.last_reset=reset;
counters=[t;double(s.max_run)*h;double(s.total_bad)*h;double(s.total_permit)*h;double(s.violation_ticks);...
 double(s.low_permit_ticks);double(s.value_violation_ticks);s.max_angle_permit_deg;s.max_relative_permit;...
 double(bad);double(s.run)*h;double(tick+1)];
event=[t;double(bad);double(permit);reason;double(adc_valid);double(timing_valid);pub(4);angle;relative;...
 pub(6);truth_theta;pub(8);truth_rpm;pub(1);pub(13);double(reset)];
end
