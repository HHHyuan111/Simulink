function [s,values,permit,reason,diagnostic]=sensorless_r2_fault_queue_step(s,t,theta,omega,quality,adc_valid,timing_valid,reset,missing,jitter,c)
%#codegen
assert(c.observer_exec_s>=c.h_s);tick=round(t/c.h_s);N=round(c.period_s/c.h_s);
first=round((c.adc_trigger_s+c.adc_sync_s+3*c.adc_rank_s)/c.h_s);
reset_rise=reset&&~s.last_reset;loss_rise=missing&&~s.last_missing;
if reset_rise||loss_rise
 s.queue=sensorless_v2_queue_state;s.queue.fault_latched=true;s.epoch=s.epoch+uint64(1);
 if reset_rise,s.integrity_latched=false;end
end
capture=tick>=first&&mod(tick-first,N)==0;
if missing&&capture,s.queue.last_capture=tick;end
new_capture=capture&&~missing&&tick~=s.queue.last_capture;
[s.queue,values,permit,reason]=sensorless_v2_queue_step(s.queue,t,theta,omega,quality,adc_valid&&~missing&&~reset,timing_valid,c);
if new_capture&&s.queue.has_pending
 s.queue.pending.available_time_s=(tick+ceil(c.observer_exec_s/c.h_s-1e-9)+round(jitter/c.h_s))*c.h_s;
end
accepted=values(13)>.5&&bitand(uint16(reason),uint16(96))==0;
if bitand(uint16(reason),uint16(96))~=0,s.integrity_latched=true;end
if reset
 if adc_valid&&~missing,reason=double(bitand(uint16(reason),bitcmp(uint16(2))));end
 reason=double(bitor(uint16(reason),uint16(1024)));
end
if missing,reason=double(bitor(uint16(reason),uint16(2048)));end
if s.integrity_latched,permit=false;reason=double(bitor(uint16(reason),uint16(4096)));end
if ~permit,values(9:11)=0;end
s.last_missing=missing;s.last_reset=reset;
diagnostic=[double(s.epoch);double(missing);double(reset);double(s.integrity_latched);double(accepted);...
 s.queue.pending.sequence;s.queue.pending.reference_time_s;s.queue.pending.available_time_s];
end
