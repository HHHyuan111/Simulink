function result=sensorless_r2_event_audit(events,counters,h)
% Offline interval oracle, using state transitions rather than the DUT loop.
assert(size(events,2)==16&&size(counters,2)==12&&all(diff(events(:,1))>0));
ticks=round(events(:,1)/h);assert(all(abs(events(:,1)-ticks*h)<1e-12));
bad=events(:,2)>.5;duration=diff(ticks);total=sum(duration(bad(1:end-1)));maximum=0;run=0;
for k=1:numel(duration)
 if bad(k),run=run+duration(k);maximum=max(maximum,run);else,run=0;end
end
permit=events(:,3)>.5;totalPermit=sum(duration(permit(1:end-1)));
last=counters(end,:);assert(abs(events(end,1)-last(1))<1e-12);
assert(round(last(2)/h)==maximum&&round(last(3)/h)==total&&round(last(4)/h)==totalPermit);
angle=atan2(sin(events(:,10)-events(:,11)),cos(events(:,10)-events(:,11)))*180/pi;
relative=abs(events(:,12)-events(:,13))./max(abs(events(:,13)),1);
expected=permit&(abs(angle)>8|relative>.03);
assert(isequaln(bad,expected));assert(max(abs(angle-events(:,8)))<1e-10&&max(abs(relative-events(:,9)))<1e-12);
result=struct('events',size(events,1),'false_valid_longest_s',maximum*h,'false_valid_total_s',total*h,...
 'permit_total_s',totalPermit*h,'native_counters_equal_event_oracle',true,'event_error_formula_equal',true,'all_passed',true);
end
