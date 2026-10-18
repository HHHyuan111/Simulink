function [theta,omega,quality,adc_valid,timing_valid,reset,missing,jitter]=sless_r2_queue_fixture_block(t)
%#codegen
% Independent integer schedule for queue isolation; no motor/observer truth.
h=62.5e-9;k=round(t/h);omega=3000/60*2*pi*5;theta=mod(omega*t,2*pi);
loss=4800462;healthy=4804462;restart=9600462;resetEnd=9601262;
missing=k>=loss&&k<healthy;reset=k>=restart&&k<resetEnd;
quality=k>=800000&&~(k>=loss&&k<healthy+480000)&&~(k>=restart&&k<resetEnd+480000);
adc_valid=~missing;timing_valid=true;jitter=0;
if k>=11200000,jitter=1e-6;end
end
