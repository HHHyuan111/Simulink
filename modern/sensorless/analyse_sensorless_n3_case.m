function m=analyse_sensorless_n3_case(s,testcase,c)
% Offline evaluation from full original arrays; truth never enters estimation.
accept=jsondecode(fileread(fullfile(fileparts(mfilename('fullpath')),'contracts','acceptance_v1.json')));
t=s.obs_sless_theta.Time;theta=teach_values(s.obs_sless_theta);truth=teach_values(s.obs_sless_truth_theta);
speed=teach_values(s.obs_sless_speed);trueSpeed=teach_values(s.obs_sless_truth_speed);
valid=logical(teach_values(s.obs_sless_valid));angle=atan2(sin(theta-truth),cos(theta-truth))*180/pi;
error=speed-trueSpeed;relative=abs(error)./max(abs(trueSpeed),1);
assert(isequaln(t,s.obs_sless_truth_theta.Time)&&isequaln(t,s.obs_sless_speed.Time)&&isequaln(t,s.obs_sless_truth_speed.Time));
falseValid=valid&(abs(angle)>accept.dynamic.angle_abs_max_electrical_deg|relative>accept.dynamic.speed_error_relative_max);
m=struct('case_id',testcase.id,'kind',testcase.kind,'samples',numel(t),'finite_states',true,...
 'first_valid_s',first_time(t,valid),'false_valid_samples',sum(falseValid),...
 'false_valid_fraction_of_valid',sum(falseValid)/max(1,sum(valid)),...
 'false_valid_longest_s',max_run(falseValid)*c.sample_s,'whole_run_peak_angle_abs_deg',max(abs(angle)),...
 'whole_run_peak_speed_error_rpm',max(abs(error)),'windows',struct([]),'events',struct([]));
if isfield(testcase,'window_s')
 w=window_metrics(t,truth,trueSpeed,speed,angle,valid,testcase.window_s,testcase.speed_rpm,c,accept.steady);
 m.windows=w;
elseif isfield(testcase,'windows_s')
 windows=testcase.windows_s;
 for k=1:size(windows,1)
  target=NaN;if isfield(testcase,'speed_rpm'),target=testcase.speed_rpm;end
  if strcmp(testcase.id,'low_speed_stop'),targets=[1000 200 0];target=targets(k);end
  w=window_metrics(t,truth,trueSpeed,speed,angle,valid,windows(k,:),target,c,accept.steady);
  if k==1,m.windows=w;else,m.windows(k)=w;end
 end
end
if isfield(testcase,'events')
 events=testcase.events;if ~iscell(events),events=num2cell(events);end
 for j=1:numel(events)
  event=events{j};finish=testcase.duration_s;if j<numel(events),finish=events{j+1}.time_s;end
  accepted=find(t>=event.time_s-1e-12,1);taskTime=t(accepted);
  if strcmp(event.type,'speed')
   source=s.log_nref;value=event.value_rpm;
   rate=c.evaluation_speed_sample;taskTime=rate(2)+ceil((event.time_s-rate(2))/rate(1)-1e-9)*rate(1);
  else
   source=s.log_TL;value=event.value_Nm;
  end
  changed=find(source.Time>=event.time_s-1e-12&abs(teach_values(source)-value)<1e-12,1);assert(~isempty(changed));
  good=valid&abs(angle)<=accept.dynamic.angle_abs_max_electrical_deg&relative<=accept.dynamic.speed_error_relative_max;
  eligible=t>=event.time_s-1e-12&t<finish-1e-12;run=0;recovery=NaN;holdend=NaN;
  for k=find(eligible)'
   if good(k),run=run+1;else,run=0;end
   if run>=round(accept.dynamic.hold_s/c.sample_s)
    recovery=t(k-run+1);holdend=recovery+accept.dynamic.hold_s;break;
   end
  end
  q=struct('type',event.type,'request_time_s',event.time_s,'source_first_logged_time_s',source.Time(changed),...
   'accepted_task_time_s',taskTime,'first_observer_task_s',t(accepted),...
   'recovery_interval_start_s',recovery,'recovery_hold_end_s',holdend,...
   'recovery_delay_s',recovery-event.time_s,...
   'peak_angle_abs_deg',max(abs(angle(eligible))),'peak_speed_error_rpm',max(abs(error(eligible))),...
   'passed',isfinite(recovery)&&recovery-event.time_s<=accept.dynamic.recovery_deadline_after_event_s&&holdend<=finish+1e-12);
  if j==1,m.events=q;else,m.events(j)=q;end
 end
end
m.stimulus=stimulus_evidence(s,testcase);m.validity=validity_oracle(s,c);m.faults=fault_metrics(s,testcase,c);
m.correct_sign=true;
if isfield(testcase,'speed_rpm')
 use=t>=.5&t<=.8;m.correct_sign=mean(speed(use))*sign(testcase.speed_rpm)>0&&mean(trueSpeed(use))*sign(testcase.speed_rpm)>0;
end
m.precision_required=strcmp(testcase.kind,'base_precision');m.dynamic_required=strcmp(testcase.kind,'base_dynamic');
m.passed=m.stimulus.passed&&m.validity.passed&&m.faults.passed&&m.correct_sign;
if m.precision_required,m.passed=m.passed&&all([m.windows.precision_passed]);end
if m.dynamic_required,m.passed=m.passed&&all([m.events.passed]);end
end

function result=stimulus_evidence(s,testcase)
speed=s.log_nref;load=s.log_TL;
initial=0;if isfield(testcase,'speed_rpm'),initial=testcase.speed_rpm;else,initial=testcase.speed_initial_rpm;end
expectedSpeed=ones(size(speed.Time))*initial;expectedLoad=ones(size(load.Time))*.207;
if isfield(testcase,'events')
 events=testcase.events;if ~iscell(events),events=num2cell(events);end
 for j=1:numel(events)
  e=events{j};
  if strcmp(e.type,'speed'),expectedSpeed(speed.Time>=e.time_s-1e-12)=e.value_rpm;
  else,expectedLoad(load.Time>=e.time_s-1e-12)=e.value_Nm;end
 end
end
speedOK=isequaln(teach_values(speed),expectedSpeed);loadOK=max(abs(teach_values(load)-expectedLoad))<1e-12;
result=struct('speed_request_schedule_identical',speedOK,'load_schedule_identical',loadOK,'passed',speedOK&&loadOK);
end

function w=window_metrics(t,truth,trueSpeed,speed,angle,valid,range,target,c,criteria)
use=t>=range(1)-1e-12&t<=range(2)+1e-12;assert(sum(use)>1);
x=t(use);y=trueSpeed(use);estimate=speed(use);a=angle(use);v=valid(use);den=NaN;
if isfinite(target)&&target~=0,den=abs(target);end
slope=sum((x-mean(x)).*(y-mean(y)))/sum((x-mean(x)).^2);
unwrapped=unwrap(truth(use));cycles=abs(unwrapped(end)-unwrapped(1))/(2*pi);
err=estimate-y;
w=struct('begin_s',range(1),'end_s',range(2),'samples',sum(use),'target_rpm',target,...
 'true_speed_mean_rpm',mean(y),'true_speed_slope_rpm_s',slope,'electrical_cycles',cycles,...
 'angle_rms_deg',sqrt(mean(a.^2)),'angle_abs_max_deg',max(abs(a)),...
 'speed_mean_signed_error_rpm',mean(err),'speed_error_rms_rpm',sqrt(mean(err.^2)),...
 'speed_mean_error_relative',abs(mean(err))/den,'speed_error_rms_relative',sqrt(mean(err.^2))/den,...
 'valid_fraction',mean(v),'plant_settled',abs(mean(y)-target)/den<=criteria.plant_speed_mean_target_relative_max&&abs(slope)<=criteria.plant_speed_slope_abs_max_rpm_s,...
 'precision_passed',false);
w.precision_passed=w.plant_settled&&cycles>=criteria.minimum_electrical_cycles&&w.angle_rms_deg<=criteria.angle_rms_max_electrical_deg&&...
 w.angle_abs_max_deg<=criteria.angle_abs_max_electrical_deg&&w.speed_mean_error_relative<=criteria.speed_mean_error_relative_max&&...
 w.speed_error_rms_relative<=criteria.speed_error_rms_relative_max&&w.valid_fraction>=criteria.valid_fraction_min;
end

function r=validity_oracle(s,c)
% Compute segmented moving means independently, then apply frozen counters.
t=s.obs_sless_theta.Time;residual=teach_values(s.obs_sless_i_residual);phase=teach_values(s.obs_sless_pll_error);
mag=teach_values(s.obs_sless_emf_magnitude);sat=logical(teach_values(s.obs_sless_pll_saturated));
sample=logical(teach_values(s.obs_sless_sample_valid));reset=logical(teach_values(s.obs_sless_reset));
actual=logical(teach_values(s.obs_sless_valid));actualState=teach_values(s.obs_sless_state);history=teach_values(s.obs_sless_history);
valid=false;lock=0;unlock=0;begin=1;expected=false(size(actual));state=zeros(size(actual));expectedHistory=zeros(numel(t),3);
power=sum(residual.^2,2)/2;square=phase.^2;prefixR=[0;cumsum(power)];prefixP=[0;cumsum(square)];
for k=1:numel(t)
 if reset(k)||~sample(k)
  valid=false;lock=0;unlock=0;begin=k+1;n=0;
 else
  n=min(c.window_samples,k-begin+1);first=max(begin,k-c.window_samples+1);
  rmsR=sqrt(max(0,(prefixR(k+1)-prefixR(first))/c.window_samples));
  rmsP=sqrt(max(0,(prefixP(k+1)-prefixP(first))/c.window_samples));
  enough=n==c.window_samples;rok=rmsR<=c.validity.current_residual_vector_rms_max_A;pok=rmsP<=c.validity.pll_phase_error_rms_max;
  good=enough&&rok&&pok&&~sat(k)&&mag(k)>=c.validity.emf_on_min_V;
  bad=~enough||~rok||~pok||sat(k)||mag(k)<c.validity.emf_off_below_V;
  if ~valid
   if good,lock=lock+1;else,lock=0;end
   if lock>=c.lock_samples,valid=true;unlock=0;end
  else
   if bad,unlock=unlock+1;else,unlock=0;end
   if unlock>=c.unlock_samples,valid=false;lock=0;end
  end
 end
 expected(k)=valid;state(k)=1;if reset(k),state(k)=0;elseif valid,state(k)=2;elseif ~sample(k),state(k)=3;end
 expectedHistory(k,:)=[lock n unlock];
end
r=struct('valid_samples_identical',isequaln(actual,expected),'state_samples_identical',isequaln(actualState,state),...
 'history_samples_identical',isequaln(history,expectedHistory),'invalid_sample_immediate',~any(actual(~sample)),...
 'passed',isequaln(actual,expected)&&isequaln(actualState,state)&&isequaln(history,expectedHistory)&&~any(actual(~sample)));
end

function f=fault_metrics(s,testcase,c)
t=s.obs_sless_theta.Time;ticks=round(t/c.sample_s);valid=logical(teach_values(s.obs_sless_valid));
sample=logical(teach_values(s.obs_sless_sample_valid));reset=logical(teach_values(s.obs_sless_reset));
f=struct('required',false,'injected_samples',0,'correct_count',true,'state_semantics',true,'reacquire_s',NaN,'passed',true);
if isfield(testcase,'invalid_interval_s')
 f.required=true;use=ticks>=12000&ticks<12005;f.injected_samples=sum(~sample);f.correct_count=sum(use)==5&&isequal(~sample,use);
 ih=teach_values(s.obs_sless_i_hat);z=teach_values(s.obs_sless_injection);emf=teach_values(s.obs_sless_emf);inte=teach_values(s.obs_sless_pll_integral);
 for k=find(use)'
  prediction=c.a*ih(k-1,:)+c.b*teach_values_at(s.obs_sless_input_v,k)-c.b*z(k-1,:);
  f.state_semantics=f.state_semantics&&max(abs(ih(k,:)-prediction))<1e-10&&isequaln(z(k,:),z(k-1,:))&&isequaln(emf(k,:),emf(k-1,:))&&inte(k)==inte(k-1)&&~reset(k)&&~valid(k);
 end
 first=find(ticks>=12005&valid,1);if ~isempty(first),f.reacquire_s=t(first);f.state_semantics=f.state_semantics&&first-find(use,1,'last')>=c.window_samples+c.lock_samples-1;end
elseif isfield(testcase,'reset_time_s')
 f.required=true;use=ticks==12000;f.injected_samples=sum(reset&t>.59);f.correct_count=sum(use)==1&&f.injected_samples==1&&all(reset(use));
 for name={'i_hat','injection','emf','theta','omega_e','pll_integral','history'}
  values=teach_values(s.(['obs_sless_' name{1}]));f.state_semantics=f.state_semantics&&all(values(use,:)==0,'all');
 end
 first=find(ticks>12000&valid,1);if ~isempty(first),f.reacquire_s=t(first);f.state_semantics=f.state_semantics&&first-find(use)>=c.window_samples+c.lock_samples-1;end
 f.state_semantics=f.state_semantics&&~any(valid(use));
elseif isfield(testcase,'noise')
 f.required=true;noise=teach_values(s.obs_sless_noise_abc);stream=RandStream('mt19937ar','Seed',testcase.noise.seed);
 expected=testcase.noise.rms_A*randn(stream,3,numel(t))';f.injected_samples=size(noise,1);f.state_semantics=isequaln(noise,expected);
end
f.passed=f.correct_count&&f.state_semantics;
end
function value=teach_values_at(series,k),allValues=teach_values(series);value=allValues(k,:);end
function value=first_time(t,mask),index=find(mask,1);value=NaN;if ~isempty(index),value=t(index);end,end
function n=max_run(mask),edges=diff([false;mask(:);false]);lengths=find(edges==-1)-find(edges==1);n=0;if ~isempty(lengths),n=max(lengths);end,end
