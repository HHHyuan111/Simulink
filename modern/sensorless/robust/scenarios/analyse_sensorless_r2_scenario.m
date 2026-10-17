function m=analyse_sensorless_r2_scenario(s,testcase)
% Original acceptance plus explicit physical stimulus/coverage checks.
evaluation=testcase;if strcmp(testcase.kind,'boundary'),evaluation.kind='normal_precision';end
m=analyse_sensorless_r2_case(s,evaluation);m.kind=testcase.kind;
if strcmp(testcase.kind,'boundary'),m.boundary_policy='full_normal_precision_requirements';end
if strcmp(testcase.id,'adc_clipping')
 adc=teach_values(s.obs_sless_v2_adc_valid);m.invalid_adc_frames=sum(adc<.5);m.checks.adc_fault_observed=m.invalid_adc_frames>0;
end
if strcmp(testcase.id,'low_speed_stop')
 actual=teach_values(s.obs_sless_v2_truth_speed);t=s.obs_sless_v2_truth_speed.Time;m.low_speed_frames=sum(abs(actual)<=250);
 stop=t>=.7&t<=.9&abs(actual)<=10;edges=diff([false;stop;false]);runs=find(edges==-1)-find(edges==1);hold=0;if ~isempty(runs),hold=max(runs)*50e-6;end
 m.stop_hold_s=hold;m.checks.low_region_observed=m.low_speed_frames>0;m.checks.stop_region_observed=hold>=.02;
end
if isfield(testcase,'events')
 es=testcase.events;if ~iscell(es),es=num2cell(es);end
 applied=true;
 for j=1:numel(es)
  e=es{j};name='log_nref';value=0;
  if strcmp(e.type,'speed'),value=e.value_rpm;else,name='log_TL';value=e.value_Nm;end
  signal=s.(name);index=find(signal.Time>=e.time_s+100e-6,1);values=teach_values(signal);
  okay=~isempty(index)&&abs(values(index,1)-value)<1e-10;applied=applied&&okay;
  m.stimulus_events(j)=struct('type',e.type,'requested_s',e.time_s,'expected',value,'applied',okay);
 end
 m.checks.command_events_applied=applied;
end
m.failed_checks={};names=fieldnames(m.checks);for k=1:numel(names),if ~m.checks.(names{k}),m.failed_checks{end+1}=names{k};end,end
m.all_passed=isempty(m.failed_checks);
end
