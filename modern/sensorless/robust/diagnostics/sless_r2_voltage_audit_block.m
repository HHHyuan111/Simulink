function [counters,prefix,enable]=sless_r2_voltage_audit_block(t,weighted,interval,ready,native,uncertainty,anchor)
%#codegen
persistent count boundaries rejected maxVoltage maxUncertainty
if isempty(count),count=0;boundaries=0;rejected=0;maxVoltage=0;maxUncertainty=0;end
k=round(t/62.5e-9);assert(k==count);count=count+1;
prefix=[t;weighted;interval;double(ready);native;uncertainty];v=prefix(2:end);
assert(all(isfinite(prefix)));assert(ready==(k>=1262));
boundary=k>=462&&mod(k-462,800)==0;assert(v(37)==double(boundary));
gates=v(13:18)>.5;assert(~any(gates(1:2:5)&gates(2:2:6)));
assert(all(uncertainty>=-1e-12));
if ready,assert(abs(interval(2)-interval(1)-50e-6)<=1e-12);end
if boundary,boundaries=boundaries+1;if ~anchor,rejected=rejected+1;end,end
maxVoltage=max(maxVoltage,max(abs(weighted)));maxUncertainty=max(maxUncertainty,max(uncertainty));
counters=[t;count;boundaries;rejected;maxVoltage;double(ready);maxUncertainty];enable=k<=2400;
end
