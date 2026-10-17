function m=analyse_sensorless_r2_case(s,testcase)
% Performance uses all samples in fixed windows, independent of permission.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));
plan=jsondecode(fileread(fullfile(base,'contracts','nonideal_r2_test_plan.json')));c=plan.precision;
t=s.obs_sless_v2_theta.Time;theta=teach_values(s.obs_sless_v2_theta);truth=teach_values(s.obs_sless_v2_truth_theta);
estimate=teach_values(s.obs_sless_v2_speed);actual=teach_values(s.obs_sless_v2_truth_speed);
angle=atan2(sin(theta-truth),cos(theta-truth))*180/pi;speedError=estimate-actual;
assert(isequaln(t,s.obs_sless_v2_truth_theta.Time));
pub=teach_values(s.obs_sless_v2_publication);pt=s.obs_sless_v2_publication.Time;
assert(numel(pt)==numel(t)&&max(abs(pt-t-3e-6))<1e-12);
% Control values are exactly zero when denied; event transitions carry the
% permit at each packet's actual publication epoch, with no interpolations.
events=teach_values(s.obs_sless_r2_native_events);counters=teach_values(s.obs_sless_r2_native_counters);
eventAudit=sensorless_r2_event_audit(events,counters,62.5e-9);eventTicks=round(events(:,1)/62.5e-9);
permit=false(numel(t),1);
for k=1:numel(t)
 index=find(eventTicks==round(pt(k)/62.5e-9));assert(isscalar(index));permit(k)=events(index,3)>.5;
 assert(pub(k,1)==k-1&&abs(pub(k,2)-t(k))<1e-12&&abs(pub(k,3)-pt(k))<1e-12);
 assert(abs(atan2(sin(pub(k,5)-theta(k)),cos(pub(k,5)-theta(k))))<1e-12);
end
m=struct('node','N3R2','id',testcase.id,'kind',testcase.kind,'samples',numel(t),'event_audit',eventAudit,...
 'permission_violation_ticks',counters(end,5),'low_speed_permit_ticks',counters(end,6),...
 'forbidden_control_values_ticks',counters(end,7),'max_permitted_angle_error_deg',counters(end,8),...
 'max_permitted_speed_relative',counters(end,9),'false_valid_longest_s',counters(end,2),...
 'false_valid_target_s',plan.native_false_valid.normal_cases_longest_s_max,'first_permit_s',NaN,...
 'whole_run_peak_angle_deg',max(abs(angle)),'whole_run_peak_speed_error_rpm',max(abs(speedError)),...
 'steady',struct,'events',struct([]),'all_passed',false,'failed_checks',{{}});
first=find(permit,1);if ~isempty(first),m.first_permit_s=pt(first);end
checks=struct('event_audit',eventAudit.all_passed,'no_permission_violation',counters(end,5)==0,...
 'zero_forbidden_control_outputs',counters(end,7)==0);
if strcmp(testcase.kind,'normal_precision')
 range=c.window_s;use=t>=range(1)-1e-12&t<=range(2)+1e-12;x=t(use);y=actual(use);a=angle(use);err=speedError(use);den=abs(testcase.speed_rpm);
 slope=sum((x-mean(x)).*(y-mean(y)))/sum((x-mean(x)).^2);unwrapped=unwrap(truth(use));cycles=abs(unwrapped(end)-unwrapped(1))/(2*pi);
 m.steady=struct('window_s',range,'samples',sum(use),'target_rpm',testcase.speed_rpm,'true_speed_mean_rpm',mean(y),...
  'true_speed_slope_rpm_s',slope,'electrical_cycles',cycles,'angle_rms_deg',sqrt(mean(a.^2)),...
  'angle_abs_max_deg',max(abs(a)),'speed_mean_error_relative',abs(mean(err))/den,...
  'speed_rms_error_relative',sqrt(mean(err.^2))/den,'permit_fraction',mean(permit(use)));
 w=m.steady;checks.plant_settled=abs(w.true_speed_mean_rpm-testcase.speed_rpm)/den<=c.plant_mean_target_relative_max&&abs(slope)<=c.plant_speed_slope_rpm_s_max;
 checks.enough_cycles=cycles>=c.minimum_electrical_cycles;checks.angle_rms=w.angle_rms_deg<=c.angle_rms_deg_max;
 checks.angle_peak=w.angle_abs_max_deg<=c.angle_peak_deg_max;checks.speed_mean=w.speed_mean_error_relative<=c.speed_mean_relative_max;
 checks.speed_rms=w.speed_rms_error_relative<=c.speed_rms_relative_max;checks.permit_fraction=w.permit_fraction>=c.permit_fraction_min;
 checks.false_valid=counters(end,2)<=plan.native_false_valid.normal_cases_longest_s_max+1e-12;
elseif strcmp(testcase.kind,'normal_dynamic')
 m.events=struct('request_s',{},'recovery_start_s',{},'recovery_delay_s',{},'passed',{});
 relative=abs(speedError)./max(abs(actual),1);good=permit&abs(angle)<=8&relative<=.03;
 es=testcase.events;if ~iscell(es),es=num2cell(es);end
 for j=1:numel(es)
  e=es{j};finish=testcase.duration_s;if j<numel(es),finish=es{j+1}.time_s;end
  eligible=find(t>=e.time_s&t<finish);run=0;start=NaN;
  for k=eligible'
   if good(k),run=run+1;else,run=0;end
   if run>=400,start=t(k-run+1);break;end
  end
  value=struct('request_s',e.time_s,'recovery_start_s',start,'recovery_delay_s',start-e.time_s,...
   'passed',isfinite(start)&&start-e.time_s<=.15&&start+.02<=finish+1e-12);
  m.events(j)=value;
 end
 checks.dynamic_recovery=all([m.events.passed]);checks.false_valid=counters(end,2)<=.002+1e-12;
elseif strcmp(testcase.kind,'boundary_state')
 checks.low_speed_denied=counters(end,6)==0;
elseif strcmp(testcase.kind,'logging_validation')
 checks.packet_count=numel(t)==400;checks.native_count=counters(end,12)==320001;
end
names=fieldnames(checks);for k=1:numel(names),if ~checks.(names{k}),m.failed_checks{end+1}=names{k};end,end
m.checks=checks;m.all_passed=isempty(m.failed_checks);
end
