function s=pmsm_speed_step_metrics(raw,p,amplitude)
% Step metrics use the commanded level, never an estimated final value.
t=raw.speed_ref.Time;y=teach_values(raw.obs_state);rpm=y(:,3)*30/pi;
r=teach_values(raw.speed_ref);fb=teach_values(raw.speed_feedback);e=teach_values(raw.speed_error);
assert(isequal(t,raw.obs_state.Time,raw.speed_feedback.Time,raw.speed_error.Time));
assert(max(abs(r-e-fb))<1e-9,'Speed error identity failed.');
ix=t>=p.step_time_s;tp=t(ix);v=rpm(ix)/amplitude;
s=struct('amplitude_rpm',amplitude,'rise_time_s',[],'settling_time_s',[],...
 'overshoot_percent',max(0,100*(max(v)-1)),'dc_gain',mean(rpm(t>=p.dc_start_s))/amplitude,...
 'tail_peak_error_percent',100*max(abs(v(tp>=p.dc_start_s)-1)),...
 'reference_identity_error_rpm',max(abs(r-e-fb)));
i10=find(v>=.1,1);i90=find(v>=.9,1);
if ~isempty(i10)&&~isempty(i90),s.rise_time_s=tp(i90)-tp(i10);end
bad=find(abs(v-1)>.02,1,'last');
if isempty(bad),s.settling_time_s=0;
elseif bad<numel(tp)&&t(end)-tp(bad+1)>=p.minimum_verified_tail_s
 s.settling_time_s=tp(bad+1)-p.step_time_s;
end
mid=(p.dc_start_s+p.duration_s)/2;
s.tail_drift_percent=100*abs(mean(rpm(t>=mid))-mean(rpm(t>=p.dc_start_s&t<mid)))/amplitude;
end
