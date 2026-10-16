function [s,gates,blank]=sensorless_deadtime_estimate_step(s,t,request,c)
%#codegen
% Rebuild estimated gate timing from firmware requests, never plant gates.
assert(isscalar(t)&&isfinite(t)&&t>=0&&numel(request)==6&&all(isfinite(request(:))));
tick=round(t/c.h_s);assert(abs(t-tick*c.h_s)<=1e-12,'sensorless:RobustGrid','Off-grid gate timestamp.');
r=reshape(request,6,1)>.5;assert(~any(r(1:2:5)&r(2:2:6)),'sensorless:ShootThrough','Invalid complementary request.');
if tick==s.last_tick
 assert(isequal(r,s.previous_request),'sensorless:SameTickMutation','Gate request changed on a repeated tick.');
else
 assert(tick==s.last_tick+1,'sensorless:RobustGrid','Skipped or reversed gate tick.');
 delay=ceil(c.deadtime_hat_s/c.h_s-1e-9);
 for k=1:6
  if ~r(k),s.gates(k)=false;s.armed(k)=false;
  elseif ~s.previous_request(k),s.rise_tick(k)=tick;s.armed(k)=true;s.gates(k)=false;
  end
  if s.armed(k)&&tick-s.rise_tick(k)>=delay,s.gates(k)=true;s.armed(k)=false;end
 end
 s.previous_request=r;s.last_tick=tick;
end
gates=s.gates;assert(~any(gates(1:2:5)&gates(2:2:6)));
blank=~gates(1:2:5)&~gates(2:2:6);
end
