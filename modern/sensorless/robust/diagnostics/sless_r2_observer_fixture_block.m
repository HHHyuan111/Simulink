function [threshold,carrier,bus,measured,adc,adc_diag,pwm_diag,truth_theta,truth_speed]=sless_r2_observer_fixture_block(t)
%#codegen
% Synthetic external inputs only. Observer feedback is never replaced.
[threshold,carrier,bus,pwm_diag,current,~,omega,~,~]=sless_r2_voltage_fixture_block(t);
threshold=threshold*25e-6;carrier=carrier*25e-6;measured=current;adc=current;
adc_diag=zeros(1,15);adc_diag(7:9)=1;truth_theta=mod(omega*t,2*pi);truth_speed=3000;
end
