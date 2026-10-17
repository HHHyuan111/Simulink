function m=analyse_sensorless_r2_fault(s,testcase)
% Independent native/event and packet-reference oracles, no fixed-delay log.
h=62.5e-9;Ts=50e-6;first=28.875e-6;program=sensorless_r2_fault_program(testcase);
t=s.obs_sless_v2_theta.Time;theta=teach_values(s.obs_sless_v2_theta);truth=teach_values(s.obs_sless_v2_truth_theta);
speed=teach_values(s.obs_sless_v2_speed);actual=teach_values(s.obs_sless_v2_truth_speed);
events=teach_values(s.obs_sless_r2_native_events);counters=teach_values(s.obs_sless_r2_native_counters);
audit=sensorless_r2_event_audit(events,counters,h);
packets=teach_values(s.obs_sless_r2_actual_publications);pt=s.obs_sless_r2_actual_publications.Time;
assert(all(diff(pt)>0)&&size(packets,2)==13&&all(packets(:,13)==1));
index=round((packets(:,2)-first)/Ts)+1;assert(all(index>=1&index<=numel(t))&&all(diff(index)>0));
assert(max(abs(packets(:,2)-t(index)))<1e-12&&all(packets(:,1)==index-1));
assert(max(abs(atan2(sin(packets(:,5)-theta(index)),cos(packets(:,5)-theta(index)))))<1e-12);
permit=false(size(t));actualCompletion=nan(size(t));expectedDelay=zeros(size(pt));
eventTicks=round(events(:,1)/h);
for k=1:numel(pt)
 ref=packets(k,2);jitter=0;
 for j=1:program(6)
  if ref>=program(8+3*(j-1))-1e-12,jitter=program(9+3*(j-1));end
 end
 expectedDelay(k)=3e-6+jitter;
 e=find(eventTicks==round(pt(k)/h));assert(isscalar(e)&&events(e,15)==1);
 permit(index(k))=events(e,3)>.5;actualCompletion(index(k))=pt(k);
end
assert(max(abs(pt-packets(:,3)))<1e-12&&max(abs(pt-packets(:,2)-expectedDelay))<1e-12);
angle=atan2(sin(theta-truth),cos(theta-truth))*180/pi;relative=abs(speed-actual)./max(abs(actual),1);
checks=struct('event_counter_audit',audit.all_passed,'no_permission_violation',counters(end,5)==0,...
 'zero_forbidden_control_values',counters(end,7)==0,'native_false_valid',counters(end,2)<=.002+1e-12,...
 'packet_reference_and_completion',true,'physical_duration',abs(counters(end,1)-testcase.duration_s)<h/2&&numel(t)==round(testcase.duration_s/Ts));
queue=teach_values(s.obs_sless_r2_fault_queue);anchor=teach_values(s.obs_sless_r2_anchor_valid);
m=struct('id',testcase.id,'node','N3R2','event_audit',audit,'accepted_packets',numel(pt),...
 'false_valid_longest_s',counters(end,2),'max_permitted_angle_deg',counters(end,8),...
 'max_permitted_speed_relative',counters(end,9),'checks',checks,'all_passed',false);
if program(1)==1
 onset=program(2);healthy=program(3);during=t>=onset-1e-12&t<healthy-1e-12;
 checks.exactly_five_dropped=sum(during)==5&&~any(ismember(find(during),index))&&numel(pt)==numel(t)-5;
 checks.missing_flags=all(queue(during,2)==1)&&all(anchor(during)==0)&&max(queue(:,1))==1;
 reasonBit=2048;
elseif program(1)==2
 onset=program(4);healthy=program(5);during=t>=onset-1e-12&t<healthy-1e-12;
 reset=teach_values(s.obs_sless_v2_reset);
 checks.reset_applied=sum(during)==1&&all(queue(during,3)==1)&&all(reset(during)==1)&&all(anchor(during)==0)&&max(queue(:,1))==1;
 checks.no_missing=all(queue(:,2)==0)&&numel(pt)==numel(t);reasonBit=1024;
else
 onset=ceil((.6-first)/Ts-1e-9)*Ts+first;healthy=ceil((.7-first)/Ts-1e-9)*Ts+first;reasonBit=8;
 checks.all_frames_captured=numel(pt)==numel(t);timing=teach_values(s.obs_sless_v2_timing_valid);
 checks.timing_veto_region=all(timing(t>=onset-1e-12&t<healthy-1e-12)==0);
 checks.jitter_applied=any(abs(expectedDelay-4e-6)<1e-12);
 m.pwm=physical_pwm_oracle(s,program,h,Ts,first);checks.physical_pwm_writes_and_updates=m.pwm.all_passed;
end
e=find(eventTicks==round(onset/h));checks.first_native_veto=isscalar(e)&&events(e,3)==0&&bitand(uint16(events(e,4)),uint16(reasonBit))~=0;
checks.pre_fault_permission=any(permit&t>=onset-.02&t<onset);
% Recovery needs599 good sample opportunities and a contiguous20ms hold.
earliest=healthy+598*Ts;post=find(permit&t>=onset-1e-12);checks.no_early_repermission=isempty(post)||t(post(1))>=earliest-1e-12;
good=permit&abs(angle)<=8&relative<=.03;eligible=find(t>=healthy-1e-12);run=0;start=NaN;completion=NaN;
for k=eligible'
 if good(k),run=run+1;else,run=0;end
 if run>=400
  candidate=t(k-run+1);available=actualCompletion(k-run+1);
  native=events(:,1)>=available-1e-12&events(:,1)<available+.02-1e-12;
  if available+.02<=testcase.duration_s+1e-12&&any(native)&&all(events(native,3)>.5&events(native,2)==0)
   start=candidate;completion=available;break;
  end
 end
end
checks.recovered=isfinite(start)&&start>=earliest-1e-12&&start-healthy<=.15&&start+.02<=testcase.duration_s+1e-12;
checks.native_recovery_hold=isfinite(completion);
m.fault_onset_s=onset;m.first_healthy_reference_s=healthy;m.recovery_reference_s=start;m.recovery_completion_s=completion;m.recovery_delay_s=start-healthy;
m.checks=checks;m.failed_checks={};names=fieldnames(checks);for k=1:numel(names),if ~checks.(names{k}),m.failed_checks{end+1}=names{k};end,end
m.all_passed=isempty(m.failed_checks);
end
function m=physical_pwm_oracle(s,program,h,Ts,first)
d=teach_values(s.obs_sless_r2_pwm_events);ticks=round(s.obs_sless_r2_pwm_events.Time/h);N=round(Ts/h);half=N/2;
refs=round(first/h):N:floor((ticks(end)-round(first/h))/N)*N+round(first/h);
expectedWrite=zeros(size(refs));expectedApply=zeros(size(refs));
for k=1:numel(refs)
 extra=0;ref=refs(k)*h;
 for j=1:program(6)
  if ref>=program(8+3*(j-1))-1e-12,extra=sum(program(9+3*(j-1):10+3*(j-1)));end
 end
 expectedWrite(k)=refs(k)+round((8e-6+extra)/h);expectedApply(k)=(floor(expectedWrite(k)/half)+1)*half;
end
eligible=expectedWrite<=ticks(end);writes=ticks(d(:,4)>.5);latched=ticks(d(:,5)>.5);apply=expectedApply(expectedApply<=ticks(end));
checks=struct('exact_write_ticks',isequal(writes(:),expectedWrite(eligible)'),...
 'exact_update_ticks',isequal(latched(:),apply(:)),'all_uev_observed',all(ismember((0:half:ticks(end))',ticks)));
for k=find(expectedApply<=ticks(end))
 row=find(ticks==expectedApply(k));assert(isscalar(row));
 checks.exact_update_ticks=checks.exact_update_ticks&&d(row,7)==k&&abs(d(row,9)-(expectedApply(k)-refs(k))*h)<1e-12;
end
checks.tied_write_observed=any(mod(expectedWrite,half)==0);checks.late_write_observed=any(expectedWrite>floor(refs/half)*half+half);
m=struct('checks',checks,'writes',numel(writes),'updates',numel(latched),'all_passed',all(structfun(@(x)x,checks)));
end
