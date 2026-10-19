function [values,permit,reason]=sless_direct_queue_block(t,theta,omega,observer_valid,input_valid,timing_valid,cfg)
%#codegen
% Normal JEOS capture and delayed publication, without injected events.
persistent queue integrity_latched
if isempty(queue),queue=sensorless_v2_queue_state;integrity_latched=false;end
c=sensorless_v2_config_rt(cfg);tick=round(t/c.h_s);N=round(c.period_s/c.h_s);
first=round((c.adc_trigger_s+c.adc_sync_s+3*c.adc_rank_s)/c.h_s);
new_capture=tick>=first&&mod(tick-first,N)==0&&tick~=queue.last_capture;
[queue,values,permit,reason]=sensorless_v2_queue_step(queue,t,theta,omega,observer_valid,input_valid,timing_valid,c);
if new_capture&&queue.has_pending
 queue.pending.available_time_s=(tick+ceil(c.observer_exec_s/c.h_s-1e-9))*c.h_s;
end
if bitand(uint16(reason),uint16(96))~=0,integrity_latched=true;end
if integrity_latched,permit=false;reason=double(bitor(uint16(reason),uint16(4096)));end
if ~permit,values(9:11)=0;end
end
