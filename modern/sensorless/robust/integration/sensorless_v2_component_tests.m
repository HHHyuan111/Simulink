function [metrics,raw]=sensorless_v2_component_tests
% Independent analytic oracles for adaptation (not motor accuracy claims).
v=sensorless_v2_config_values(.105125,.0001037615,20,12,false,0);c=sensorless_v2_config_rt(v);
raw=struct;metrics=struct;
% DC step: independently propagate the physical calibrated-current and bias
% responses through the known direct-feedthrough digital difference equation.
s=sensorless_v2_measure_state;rd=exp(-2*pi*c.digital_hz*c.period_s);
expected=zeros(3,1);measured=zeros(3,1);dc=[2;-1;-1];raw.calibration=zeros(300,10);
for k=0:299
 e=sensorless_event_plan(k,0,0,c);physical=dc.*(1-exp(-2*pi*c.analog_hz*e.adc_aperture_end_ABC_s));
 offset=c.bias_ABC.*(1-exp(-2*pi*c.analog_hz*e.adc_aperture_end_ABC_s));
 expected=rd*expected+(1-rd)*physical;measured=rd*measured+(1-rd)*(c.gain_ABC.*physical+offset);
 [s,ab,~,ok,~,~,~]=sensorless_v2_measure_step(s,e.reference_time_s,measured,measured,ones(1,15),c);
 % Undo the DUT's declared age advance only in this algebraic calibration
 % oracle; compare the stored unaligned calibration with filtered truth.
 error=s.previous-expected;raw.calibration(k+1,:)=[e.reference_time_s;ab;error;expected;double(ok)]';
end
metrics.calibration_max_A=max(abs(raw.calibration(:,4:6)),[],'all');assert(metrics.calibration_max_A<=1e-10);
% Ramp/sine age extrapolation. Known analytic signal used only as test oracle.
f=c;f.gain_ABC=ones(3,1);f.bias_ABC=zeros(3,1);ph=[0;-2*pi/3;2*pi/3];
freq=[-250 -166.6666666666667 -83.33333333333333 83.33333333333333 166.6666666666667 250];
raw.alignment=zeros(6*1000,8);idx=0;maxerr=0;
for hz=freq
 s=sensorless_v2_measure_state;
 for k=0:999
  e=sensorless_event_plan(k,0,0,f);x=5*sin(2*pi*hz*e.adc_aperture_end_ABC_s+ph);
  [s,~,aligned,~,~,~,m]=sensorless_v2_measure_step(s,e.reference_time_s,x,x,ones(1,15),f);
  truth=5*sin(2*pi*hz*e.reference_time_s+ph);err=aligned-truth;idx=idx+1;
  raw.alignment(idx,:)=[hz e.reference_time_s aligned' err'];
  if m(10)>0,maxerr=max(maxerr,max(abs(err)));end
 end
end
metrics.sine_alignment_max_A=maxerr;assert(maxerr<=.03);
s=sensorless_v2_measure_state;raw.ramp=zeros(20,4);
for k=0:19
 e=sensorless_event_plan(k,0,0,f);slope=[100;-40;-60];x=slope.*e.adc_aperture_end_ABC_s;
 [s,~,y,~,~,~,~]=sensorless_v2_measure_step(s,e.reference_time_s,x,x,ones(1,15),f);
 raw.ramp(k+1,:)=[e.reference_time_s (y-slope*e.reference_time_s)'];
end
metrics.ramp_alignment_max_A=max(abs(raw.ramp(2:end,2:end)),[],'all');assert(metrics.ramp_alignment_max_A<=1e-10);
raw.phase=zeros(41,4);
for k=1:41
 w=(k-21)*100;[p,m]=sensorless_v2_front_phase(w,c);wa=2*pi*c.analog_hz;
 H=wa/(wa+1j*w)*(1-rd)/(1-rd*exp(-1j*w*c.period_s));
 raw.phase(k,:)=[w p angle(H*exp(1j*p)) m-abs(H)];
end
metrics.phase_max_rad=max(abs(raw.phase(:,3)));assert(metrics.phase_max_rad<=1e-12);
assert(max(abs(raw.phase(:,4)))<1e-12);
% Configured rails: actual ADC input, independent of legacy diagnostic codes.
raw.rail=zeros(6,3);levels=[0 19.98 19.995 20 -20 -19.995];
for k=1:6
 s=sensorless_v2_measure_state;e=sensorless_event_plan(0,0,0,f);a=[levels(k);0;0];
 [~,~,~,~,ok,~,~]=sensorless_v2_measure_step(s,e.reference_time_s,zeros(3,1),a,ones(1,15),f);
 expected=abs(levels(k))<20-40/4096;raw.rail(k,:)=[levels(k) double(ok) double(expected)];assert(ok==expected);
end
% Native bridge/filtered-voltage integration. Independent dot-product
% quadrature of archived native values, not a second call to the DUT.
s=sensorless_v2_voltage_state;raw.voltage_native=zeros(4801,36);raw.voltage_weighted=zeros(4801,2);raw.voltage_unc=zeros(4801,2);
for k=0:4800
 t=k*c.h_s;carrier=abs(mod(t,c.period_s)-c.period_s/2);
 current=[2;-1;-1];threshold=[8e-6 14e-6 20e-6];
 [s,u,~,~,n,b]=sensorless_v2_voltage_step(s,t,threshold,carrier,24,floor(t/c.period_s),current,zeros(2,1),0,1,c);
 raw.voltage_native(k+1,:)=n';raw.voltage_weighted(k+1,:)=u';raw.voltage_unc(k+1,:)=b';
end
ra=exp(-2*pi*c.analog_hz*c.h_s);rho=exp(-c.R_hat*c.h_s/c.L_hat);N=round(c.period_s/c.h_s);
native=raw.voltage_native;input=[zeros(1,2);native(1:end-1,2:3)];
filtered=filter(1-ra,[1 -ra],input);metrics.native_filter_max_V=max(abs(filtered-native(:,4:5)),[],'all');
assert(metrics.native_filter_max_V<1e-10);
filtered_unc=filter(1-ra,[1 -ra],[zeros(1,2);native(1:end-1,6:7)]);
assert(max(abs(filtered_unc-native(:,35:36)),[],'all')<1e-10);
boundaries=find(native(:,32)>0);previous=zeros(1,2);previous_unc=zeros(1,2);errors=[];
weights=(1-rho)*rho.^((N-1):-1:0)/(1-rho^N);
for k=2:numel(boundaries)
 at=boundaries(k);range=at-N:at-1;average=weights*filtered(range,:);previous=rd*previous+(1-rd)*average;
 previous_unc=rd*previous_unc+(1-rd)*(weights*filtered_unc(range,:));uncertainty=previous_unc;
 errors(end+1,:)=[raw.voltage_weighted(at,:)-previous raw.voltage_unc(at,:)-uncertainty]; %#ok<AGROW>
end
raw.voltage_oracle_errors=errors;metrics.interval_max_V=max(abs(errors),[],'all');assert(metrics.interval_max_V<1e-10);
% Capture -> availability: changing theta after capture must not leak.
q=sensorless_v2_queue_state;raw.queue=zeros(1601,17);first=462;ready=510;
for k=0:1600
 t=k*c.h_s;queue_theta=.1;if k>first,queue_theta=2;end
 input_valid=~(k>=600&&k<610);observer_valid=true;if k>=1262,observer_valid=false;end
 [q,y,permit,reason]=sensorless_v2_queue_step(q,t,queue_theta,100,observer_valid,input_valid,true,c);
 raw.queue(k+1,:)=[t y' double(permit) reason double(input_valid)];
end
assert(all(raw.queue(1:ready,2)==-1));assert(raw.queue(ready+1,2)==0&&raw.queue(ready+1,6)==.1);
assert(all(raw.queue(601:end,15)==0));assert(all(raw.queue(601:end,10:12)==0,'all'));
% Quality history must be rebuilt after an invalid sample; no retained lock.
n=sensorless_parameters;s=sensorless_state(n);q=sensorless_v2_queue_state;raw.recovery=zeros(1500,9);
for k=1:1500
 good=k~=800;[s,locked,state]=sensorless_validity_step(s,zeros(2,1),0,3,false,good,1,false,n);
 e=sensorless_event_plan(k-1,0,0,c);
 [q,y,before,reason_before]=sensorless_v2_queue_step(q,e.reference_time_s,.2,100,locked,good,true,c);
 [q,y,after,reason_after]=sensorless_v2_queue_step(q,e.observer_available_s,.2,100,locked,good,true,c);
 raw.recovery(k,:)=[k double(good) double(locked) state s.history_count double(before) double(after) reason_before reason_after];
end
assert(find(raw.recovery(:,3)>0,1)==599);assert(~any(raw.recovery(800:1398,3)));assert(raw.recovery(1399,3)==1);
assert(find(raw.recovery(:,7)>0,1)==599);assert(~any(raw.recovery(800:1398,6:7),'all'));assert(raw.recovery(1399,7)==1);
metrics.calibration_frames=300;metrics.alignment_frames=6000;metrics.phase_cases=41;metrics.native_samples=4801;
metrics.rail_cases=6;metrics.queue_samples=1601;metrics.recovery_samples=1500;metrics.all_passed=true;
end
