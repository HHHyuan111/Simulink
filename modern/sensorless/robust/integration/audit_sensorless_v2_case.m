function m=audit_sensorless_v2_case(signals,record,testcase)
% Independent equations on actual Simulink logs. Does not call the new
% measurement/voltage/publication DUT functions to generate expected output.
c=sensorless_v2_config_rt(record.config_vector);Ts=c.period_s;h=c.h_s;
t=signals.obs_sless_v2_input_i.Time;measured=teach_values(signals.log_iabc_meas);adc=teach_values(signals.log_iabc_adc);
assert(isequaln(t,signals.log_iabc_meas.Time)&&isequaln(t,signals.log_iabc_adc.Time));
actual=teach_values(signals.obs_sless_v2_input_i);abc=teach_values(signals.obs_sless_v2_current_ABC);meta=teach_values(signals.obs_sless_v2_measurement);
N=numel(t);expected=zeros(N,2);expectedABC=zeros(N,3);bias=zeros(3,1);last=zeros(3,1);has_last=false;
rd=exp(-2*pi*c.digital_hz*Ts);adcValid=teach_values(signals.obs_sless_v2_sample_valid)>0;
for k=1:N
 ages=[.3125;1.8125;3.3125]*1e-6;ends=t(k)-ages;
 bias=rd*bias+(1-rd)*c.bias_ABC.*(1-exp(-2*pi*c.analog_hz*ends));
 calibrated=(measured(k,:)'-bias)./c.gain_ABC;derivative=zeros(3,1);
 if has_last,derivative=(calibrated-last)/Ts;end
 aligned=calibrated+ages.*derivative;expectedABC(k,:)=aligned';
 expected(k,:)=[(2*aligned(1)-aligned(2)-aligned(3))/3 (aligned(2)-aligned(3))/sqrt(3)];
 if adcValid(k),last=calibrated;has_last=true;else,last=zeros(3,1);has_last=false;end
 assert(max(abs(meta(k,1:3)'-ends))<1e-12&&max(abs(meta(k,4:6)'-ages))<1e-12);
end
m=struct('calibration_alignment_max_A',max(abs([expected-actual expectedABC-abc]),[],'all'));
assert(m.calibration_alignment_max_A<=1e-10);
% Native bridge output, frontend RC, previous-interval RL weighting and Hd.
native=teach_values(signals.obs_sless_v2_voltage_native);nt=signals.obs_sless_v2_voltage_native.Time;
assert(size(native,2)==36&&max(abs(native(:,1)-nt))<1e-12);
assert(all(diff(round(nt/h))==1));m.native_samples=numel(nt);
% Edge-run oracle for delay insertion; independent of the R0 state machine.
upper=native(:,29)>=native(:,26:28);request=false(size(native,1),6);request(:,1:2:5)=upper;request(:,2:2:6)=~upper;
expectedGates=false(size(request));rows=(0:size(request,1)-1)';delay=ceil(c.deadtime_hat_s/h-1e-9);
for channel=1:6
 rising=request(:,channel)&~[false;request(1:end-1,channel)];lastRise=cummax(rows.*double(rising));
 expectedGates(:,channel)=request(:,channel)&rows-lastRise>=delay;
end
assert(isequaln(expectedGates,native(:,8:13)>.5));
% All unambiguous circuit states use an independent direct rail/diode
% equation; ambiguous samples stay in all diagnostics and interval oracles.
ip=native(:,14:16);ip=ip-mean(ip,2);
poles=zeros(size(ip));high=expectedGates(:,1:2:5);low=expectedGates(:,2:2:6);
for channel=1:3
 on=high(:,channel)|low(:,channel);off=~on;bus=native(:,30);
 poles(on,channel)=(double(high(on,channel))-.5).*bus(on)-c.Ron_hat_ohm*ip(on,channel);
 poles(off,channel)=-sign(ip(off,channel)).*(bus(off)/2+c.Vf_hat_V);
end
known=~any(native(:,20:22)>0,2);C=[2/3 -1/3 -1/3;0 1/sqrt(3) -1/sqrt(3)];
m.bridge_unambiguous_max_V=max(abs(poles(known,:)*C'-native(known,2:3)),[],'all');assert(m.bridge_unambiguous_max_V<=1e-10);
ra=exp(-2*pi*c.analog_hz*h);rho=exp(-c.R_hat*h/c.L_hat);nPeriod=round(Ts/h);
filtered=filter(1-ra,[1 -ra],[zeros(1,2);native(1:end-1,2:3)]);
m.native_filter_max_V=max(abs(filtered-native(:,4:5)),[],'all');assert(m.native_filter_max_V<=1e-10);
u=teach_values(signals.obs_sless_v2_input_v);unc=teach_values(signals.obs_sless_v2_voltage_uncertainty);
filtered_unc=filter(1-ra,[1 -ra],[zeros(1,2);native(1:end-1,6:7)]);
assert(max(abs(filtered_unc-native(:,35:36)),[],'all')<1e-10);
previous=zeros(1,2);previous_unc=zeros(1,2);errors=zeros(max(0,N-1),4);weights=(1-rho)*rho.^((nPeriod-1):-1:0)/(1-rho^nPeriod);
for k=2:N
 at=round(t(k)/h)+1;range=at-nPeriod:at-1;
 previous=rd*previous+(1-rd)*(weights*filtered(range,:));previous_unc=rd*previous_unc+(1-rd)*(weights*filtered_unc(range,:));bound=previous_unc;
 errors(k-1,:)=[u(k,:)-previous unc(k,:)-bound];
end
m.voltage_interval_max_V=max(abs(errors),[],'all');assert(m.voltage_interval_max_V<=1e-10);
assert(all(unc>=0,'all'));m.maximum_path_uncertainty_V=max(unc,[],'all');
m.ambiguous_native_fraction=mean(any(native(:,20:22)>0,2));
% Compare physical PWM write events with the independently enumerated budget.
pwm=teach_values(signals.obs_pwm_timing);pt=signals.obs_pwm_timing.Time;
write=pt(pwm(:,4)>.5);jeos=t;
assert(numel(write)==numel(jeos));expectedwrite=jeos+3e-6+5e-6+testcase.interference_s;
m.ccr_write_max_time_error_s=max(abs(write-expectedwrite));assert(m.ccr_write_max_time_error_s<=1e-12);
pub=teach_values(signals.obs_sless_v2_publication);qt=signals.obs_sless_v2_publication.Time;
permit=teach_values(signals.obs_sless_v2_control_permit)>0;reason=teach_values(signals.obs_sless_v2_deny_reason);
av=teach_values(signals.obs_sless_v2_adc_valid)>0;tv=teach_values(signals.obs_sless_v2_timing_valid)>0;
assert(isequaln(nt,qt));assert(all(~permit(~av|~tv)));assert(all(pub(~permit,9:11)==0,'all'));
assert(isequaln(permit,reason==0));edges=find(pub(:,13)>.5);theta=teach_values(signals.obs_sless_v2_theta);
assert(numel(edges)==N);
m.available_max_time_error_s=max(abs(qt(edges)-(jeos+3e-6)));assert(m.available_max_time_error_s<=1e-12);
assert(all(pub(1:edges(1)-1,1)==-1));
for k=1:N
 at=edges(k);assert(pub(at,1)==k-1);assert(abs(pub(at,2)-jeos(k))<1e-12&&abs(pub(at,3)-qt(at))<1e-12);
 assert(abs(atan2(sin(pub(at,5)-theta(k)),cos(pub(at,5)-theta(k))))<1e-12);
 if k<N,assert(all(pub(at:edges(k+1)-1,1)==k-1));end
end
% Rail oracle on the pre-digital actual ADC branch, not obs_adc_codes.
rail=any(abs(adc)>=c.adc_span_A-2*c.adc_span_A/2^c.adc_bits,2);
assert(isequaln(meta(:,7)>0,rail));m.rail_frames=sum(rail);m.invalid_window_frames=sum(meta(:,8)<.5);
m.invalid_timing_frames=sum(meta(:,9)<.5);m.control_permit_fraction=mean(permit);m.observer_packets=numel(edges);
if strcmp(testcase.id,'rail'),assert(m.rail_frames>0);end
if strcmp(testcase.id,'window'),assert(m.invalid_window_frames>0);end
if strcmp(testcase.id,'deadline'),assert(m.invalid_timing_frames==N&&~any(permit));end
m.all_passed=true;m.scope='R1 causal integration only; 20ms startup does not establish lock or steady accuracy';
end
