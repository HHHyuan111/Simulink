function [s,current,calibrated,valid,adc_valid,timing_valid,meta]=sensorless_r2_ingress_step(s,t,measured,adc,diag,c,missing,reset)
%#codegen
% Missing inputs cannot alter calibration/current states. The known bias
% model alone advances; no unavailable ADC value is read in that branch.
if reset,s.count=0;s.previous=zeros(3,1);end
if missing
 [s,~,~,~,~,timing_valid,meta]=sensorless_v2_measure_step(s,t,zeros(3,1),zeros(3,1),zeros(1,15),c);
 s.count=0;s.previous=zeros(3,1);current=zeros(2,1);calibrated=zeros(3,1);valid=false;adc_valid=false;
 meta(7:8)=-1;meta(10:12)=0;
else
 [s,current,calibrated,valid,adc_valid,timing_valid,meta]=sensorless_v2_measure_step(s,t,measured,adc,diag,c);
end
if reset,s.count=0;s.previous=zeros(3,1);valid=false;end
end
