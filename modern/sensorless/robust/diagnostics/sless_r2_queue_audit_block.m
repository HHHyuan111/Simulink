function [counters,trace,enable]=sless_r2_queue_audit_block(t,values,permit,reason,diagnostic)
%#codegen
% Check every native call; record only completions, heartbeat and fault onset.
persistent count publications permitted maxError vetoes
if isempty(count),count=0;publications=0;permitted=0;maxError=0;vetoes=0;end
h=62.5e-9;k=round(t/h);assert(k==count);count=count+1;
assert(all(isfinite(values))&&all(isfinite(diagnostic))&&isfinite(reason));
expectedEpoch=double(k>=4800462)+double(k>=9600462);assert(diagnostic(1)==expectedEpoch);
if values(13)>.5,publications=publications+1;end
if permit
    permitted=permitted+1;truth=mod(3000/60*2*pi*5*t,2*pi);
    error=abs(atan2(sin(values(6)-truth),cos(values(6)-truth)));maxError=max(maxError,error);
    assert(error<=1e-10&&abs(values(11)-3000)<=1e-9);
else
    assert(all(values(9:11)==0));
end
onset=k==4800462||k==9600462;
if onset
 assert(~permit);bit=uint16(2048);if k==9600462,bit=uint16(1024);end
 assert(bitand(uint16(reason),bit)~=0);vetoes=vetoes+1;
end
counters=[t;count;publications;permitted;maxError;expectedEpoch;vetoes];
trace=[t;values;double(permit);reason;diagnostic];
enable=mod(k,800)==0||values(13)>.5||onset;
end
