function m=analyse_sensorless_short_convergence(s,profile)
% Fixed-window convergence; all samples retained, original numeric limits.
m=analyse_sensorless_r2_case(s,profile.case);c=profile.criteria;
t=s.obs_sless_v2_theta.Time;theta=teach_values(s.obs_sless_v2_theta);truth=teach_values(s.obs_sless_v2_truth_theta);
estimate=teach_values(s.obs_sless_v2_speed);actual=teach_values(s.obs_sless_v2_truth_speed);
angle=atan2(sin(theta-truth),cos(theta-truth))*180/pi;err=estimate-actual;target=profile.case.speed_rpm;den=abs(target);
events=teach_values(s.obs_sless_r2_native_events);pt=s.obs_sless_v2_publication.Time;
[found,index]=ismember(round(pt/62.5e-9),round(events(:,1)/62.5e-9));assert(all(found));permit=events(index,3)>.5;
range=profile.steady_window_s;use=t>=range(1)-1e-12&t<=range(2)+1e-12;x=t(use);y=actual(use);a=angle(use);e=err(use);
assert(numel(x)>2);slope=sum((x-mean(x)).*(y-mean(y)))/sum((x-mean(x)).^2);u=unwrap(truth(use));cycles=abs(u(end)-u(1))/(2*pi);
m.steady=struct('window_s',range,'samples',sum(use),'target_rpm',target,'true_speed_mean_rpm',mean(y),...
 'true_speed_slope_rpm_s',slope,'electrical_cycles',cycles,'angle_rms_deg',sqrt(mean(a.^2)),...
 'angle_abs_max_deg',max(abs(a)),'speed_mean_error_relative',abs(mean(e))/den,...
 'speed_rms_error_relative',sqrt(mean(e.^2))/den,'permit_fraction',mean(permit(use)));
w=m.steady;
m.checks.plant_settled=abs(mean(y)-target)/den<=c.plant_mean_target_relative_max&&abs(slope)<=c.plant_speed_slope_rpm_s_max;
m.checks.enough_cycles=cycles>=c.minimum_electrical_cycles;
m.checks.angle_rms=w.angle_rms_deg<=c.angle_rms_deg_max;m.checks.angle_peak=w.angle_abs_max_deg<=c.angle_peak_deg_max;
m.checks.speed_mean=w.speed_mean_error_relative<=c.speed_mean_relative_max;m.checks.speed_rms=w.speed_rms_error_relative<=c.speed_rms_relative_max;
m.checks.permit_fraction=w.permit_fraction>=c.permit_fraction_min;m.checks.false_valid=m.false_valid_longest_s<=c.false_valid_longest_s_max;
m.checks.packet_count=numel(t)==round(profile.case.duration_s/50e-6);
good=permit&abs(angle)<=8&abs(err)./max(abs(actual),1)<=.03&abs(actual-target)/den<=.01;
run=0;start=NaN;
for k=1:numel(t)
 if good(k),run=run+1;else,run=0;end
 if run>=401&&t(k)-t(k-run+1)>=.02-1e-12,start=t(k-run+1);break;end
end
m.converged_reference_s=start;m.converged_publication_s=start+3e-6;m.stable_hold_s=.02;m.checks.stable_hold=isfinite(start);
m.scope='short nominal convergence, no fault or long-run qualification';
m.failed_checks={};names=fieldnames(m.checks);
for k=1:numel(names),if ~m.checks.(names{k}),m.failed_checks{end+1}=names{k};end,end
m.all_passed=isempty(m.failed_checks);
end
