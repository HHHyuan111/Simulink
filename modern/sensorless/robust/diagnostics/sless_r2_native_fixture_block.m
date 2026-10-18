function [pub,permit,reason,adc_valid,timing_valid,reset,truth_theta,truth_rpm]=sless_r2_native_fixture_block(t)
%#codegen
% Synthetic diagnostic only; deliberately exceeds the8deg error reference.
h=62.5e-9;tick=round(t/h);truth_rpm=3000;truth_theta=mod(500*pi*t,2*pi);
adc_valid=~(tick>=4800000&&tick<4804000);reset=tick>=9600462&&tick<9601262;timing_valid=true;
permit=tick>=800000&&adc_valid&&~reset;reason=0;
if tick<800000,reason=1;elseif ~adc_valid,reason=2;elseif reset,reason=1024;end
pub=zeros(13,1);pub(1)=-1;pub(6)=truth_theta;pub(8)=truth_rpm;
if tick>=510
 sequence=floor((tick-510)/800);reference=(462+800*sequence)*h;
 pub(1)=sequence;pub(2)=reference;pub(3)=reference+3e-6;pub(4)=t-reference;
 pub(13)=double(mod(tick-510,800)==0);
end
if tick>=3200000&&tick<3232001,pub(6)=truth_theta+8*pi/180+1e-9;end
pub(5)=pub(6);pub(7)=pub(6);pub(12)=t;
if permit,pub(9:11)=[pub(6);pub(6);truth_rpm];end
end
