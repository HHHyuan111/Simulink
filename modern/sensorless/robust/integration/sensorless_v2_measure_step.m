function [s,current,calibrated,valid,adc_valid,timing_valid,meta]=sensorless_v2_measure_step(s,t,measured,adc,diag,c)
%#codegen
% Measurements are already analog+digitally filtered by the local plant.
% Subtract the estimated bias step response; do not invert either LPF.
cycle=round((t-(c.adc_trigger_s+c.adc_sync_s+3*c.adc_rank_s))/c.period_s);
e=sensorless_event_plan(max(0,cycle),0,c.interference_s,c);
times=reshape(e.adc_aperture_end_ABC_s,3,1);ages=t-times;
rd=exp(-2*pi*c.digital_hz*c.period_s);
bias_analog=c.bias_ABC.*(1-exp(-2*pi*c.analog_hz*max(0,times)));
s.bias_filter=rd*s.bias_filter+(1-rd)*bias_analog;
calibrated=(reshape(measured,3,1)-s.bias_filter)./c.gain_ABC;
derivative=zeros(3,1);
if s.count>0,derivative=(calibrated-s.previous)/c.period_s;end
aligned=calibrated+ages.*derivative;
current=[(2*aligned(1)-aligned(2)-aligned(3))/3;(aligned(2)-aligned(3))/sqrt(3)];
lsb=2*c.adc_span_A/2^c.adc_bits;
rail=any(abs(reshape(adc,3,1))>=c.adc_span_A-lsb);
window_good=~c.window_on||all(diag(7:9)>.5);
adc_valid=~rail&&window_good;timing_valid=e.timing_valid;
valid=adc_valid&&timing_valid;
meta=[times;ages;double(rail);double(window_good);double(timing_valid);double(s.count>0);mean(aligned);norm(ages.*derivative)];
% A bad frame never supplies a derivative for the next good frame.
if valid,s.previous=calibrated;s.count=s.count+1;else,s.count=0;s.previous=zeros(3,1);end
calibrated=aligned;
end
