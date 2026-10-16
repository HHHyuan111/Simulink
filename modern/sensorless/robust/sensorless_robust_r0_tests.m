function [metrics,raw]=sensorless_robust_r0_tests(c,plan)
% Independent circuit, edge-interval, timer-enumeration and packet fixtures.
[metrics.bridge,raw.bridge]=bridge_tests(c,plan.bridge);
[metrics.deadtime,raw.deadtime]=deadtime_tests(c,plan.deadtime);
[metrics.schedule,raw.schedule]=schedule_tests(c,plan.schedule);
[metrics.publication,raw.publication]=publication_tests(c,plan.publication);
[metrics.rejected_inputs,raw.rejected_inputs]=rejection_tests(c);
end

function [m,raw]=bridge_tests(c,p)
raw=zeros(p.cases,33);index=0;maximum=0;good=true;
C=[2/3 -1/3 -1/3;0 1/sqrt(3) -1/sqrt(3)];
for bus=p.bus_V(:)'
 for profile=p.voltage_profiles(:)'
  q=c;q.Ron_hat_ohm=profile.Ron_ohm;q.Vf_hat_V=profile.Vf_V;
  for e=p.estimated_emf_ABC_V'
   for current=p.current_ABC_A'
    for pattern=0:26
     state=mod(floor(pattern./[1;3;9]),3);gates=false(6,1);
     gates(1:2:5)=state==0;gates(2:2:6)=state==1;
     [actual,d]=sensorless_bridge_estimate(gates,current,e,bus,q);
     solutions=circuit_solutions(gates,current,e,bus,q.Ron_hat_ohm,q.Vf_hat_V,q.zero_current_A);
     assert(~isempty(solutions),'Independent circuit oracle found no solution.');
     errors=max(abs(solutions-d.phase_voltage_V'),[],2);[err,chosen]=min(errors);
     expected=solutions(chosen,:)';err=max(err,max(abs(actual-C*expected)));
     ambiguous=~gates(1:2:5)&~gates(2:2:6)&abs(current-mean(current))<=q.zero_current_A;
     confidence=~any(ambiguous)&&abs(mean(current))<=q.zero_sequence_max_A;
     passed=err<=p.absolute_voltage_tolerance_V&&isequal(d.ambiguous_phase,ambiguous)&&d.voltage_confident==confidence;
     index=index+1;maximum=max(maximum,err);good=good&&passed;
     raw(index,:)=[bus q.Ron_hat_ohm q.Vf_hat_V gates' current' e' actual' d.phase_voltage_V' expected' ...
      d.path' d.ambiguous_phase' d.voltage_confident size(solutions,1) err passed];
    end
   end
  end
 end
end
assert(index==p.cases);
[~,z]=sensorless_bridge_estimate([1;0;0;1;1;0],[1.1;.1;-.9],[0;0;0],24,c);
sequence_rejected=~z.voltage_confident&&abs(z.current_zero_sequence_A-.1)<1e-12;
m=struct('cases',index,'maximum_voltage_error_V',maximum,'excess_zero_sequence_untrusted',sequence_rejected,...
 'all_passed',good&&sequence_rejected);
end

function solutions=circuit_solutions(gates,current,e,bus,Ron,Vf,band)
% Enumerate all diode/open assignments and solve floating-star KCL once each.
% This is not the DUT's iterative clamping algorithm.
i=current(:)-mean(current);known=false(3,1);fixedPole=zeros(3,1);
for k=1:3
 if gates(2*k-1),known(k)=true;fixedPole(k)=bus/2-Ron*i(k);
 elseif gates(2*k),known(k)=true;fixedPole(k)=-bus/2-Ron*i(k);
 elseif i(k)>band,known(k)=true;fixedPole(k)=-bus/2-Vf;
 elseif i(k)<-band,known(k)=true;fixedPole(k)=bus/2+Vf;
 end
end
unknown=find(~known);solutions=zeros(0,3);lower=-bus/2-Vf;upper=bus/2+Vf;tol=1e-11;
for assignment=0:3^numel(unknown)-1
 status=zeros(3,1);pole=fixedPole;fixed=known;
 for j=1:numel(unknown)
  k=unknown(j);status(k)=mod(floor(assignment/3^(j-1)),3)-1;
  if status(k)<0,pole(k)=lower;fixed(k)=true;
  elseif status(k)>0,pole(k)=upper;fixed(k)=true;
  end
 end
 n=sum(fixed);neutral=0;if n>0,neutral=(sum(pole(fixed))+sum(e(~fixed)))/n;end
 desired=e+neutral;admissible=true;
 for j=1:numel(unknown)
  k=unknown(j);
  if status(k)==0,admissible=admissible&&desired(k)>=lower-tol&&desired(k)<=upper+tol;pole(k)=desired(k);
  elseif status(k)<0,admissible=admissible&&desired(k)<=lower+tol;
  else,admissible=admissible&&desired(k)>=upper-tol;
  end
 end
 if admissible,solutions(end+1,:)=(pole-mean(pole))';end %#ok<AGROW>
end
end

function [m,raw]=deadtime_tests(c,p)
ticks=(p.ticks(1):p.ticks(2))';n=numel(ticks);a=false(n,1);
for interval=p.phase_A_upper_intervals_inclusive_ticks',a(ticks>=interval(1)&ticks<=interval(2))=true;end
upper=[a circshift(a,p.phase_B_C_circular_shift_ticks(1)) circshift(a,p.phase_B_C_circular_shift_ticks(2))];
request=false(n,6);request(:,1:2:5)=upper;request(:,2:2:6)=~upper;
raw=zeros(n*numel(p.delays_us),24);index=0;passed=true;repeat_count=0;
for delay=p.delays_us(:)'
 q=c;q.deadtime_hat_s=delay*1e-6;D=ceil(q.deadtime_hat_s/q.h_s-1e-9);
 expected=false(n,6);
 for k=1:6
  edges=diff([false;request(:,k);false]);begin=find(edges==1);finish=find(edges==-1)-1;
  for interval=1:numel(begin)
   first=begin(interval)+D;last=finish(interval);if first<=last,expected(first:last,k)=true;end
  end
 end
 state=sensorless_robust_state;s=state.deadtime;
 for row=1:n
  [s,gates,blank]=sensorless_deadtime_estimate_step(s,ticks(row)*q.h_s,request(row,:),q);
  ok=isequal(gates',expected(row,:))&&~any(gates(1:2:5)&gates(2:2:6));passed=passed&&ok;
  if mod(ticks(row),10)==0
   [same,g2,b2]=sensorless_deadtime_estimate_step(s,ticks(row)*q.h_s,request(row,:),q);
   passed=passed&&isequaln(s,same)&&isequal(gates,g2)&&isequal(blank,b2);repeat_count=repeat_count+1;
  end
  index=index+1;raw(index,:)=[delay D ticks(row) request(row,:) gates' expected(row,:) blank'];
 end
end
m=struct('profiles',numel(p.delays_us),'native_samples',index,'identical_repeat_ticks',repeat_count,'all_passed',passed);
end

function [m,raw]=schedule_tests(c,p)
raw=zeros(p.cases+1,22);index=0;passed=true;
for cycle=p.cycles(:)'
 for mode=p.modes(:)'
  for jitter=p.release_jitter_us(:)'
   for interference=p.interference_us(:)'
    for guard=p.guard_us(:)'
     q=c;q.update_mode=mode;q.guard_s=guard*1e-6;
     actual=sensorless_event_plan(cycle,jitter*1e-6,interference*1e-6,q);
     [expected,ok]=schedule_oracle(cycle,jitter*1e-6,interference*1e-6,q,actual);
     index=index+1;raw(index,:)=[cycle mode jitter interference guard actual.adc_aperture_end_ABC_s' ...
      actual.reference_time_s actual.task_release_s actual.observer_available_s actual.ccr_write_s ...
      actual.intended_pwm_apply_s actual.actual_pwm_apply_s actual.deadline_s actual.reserved_slack_s ...
      actual.missed_update actual.next_frame_overrun actual.speed_task_active actual.timing_valid expected.timing_valid ok];
     passed=passed&&ok;
    end
   end
  end
 end
end
assert(index==p.cases);
actual=sensorless_event_plan(0,0,50e-6,c);[expected,ok]=schedule_oracle(0,0,50e-6,c,actual);
index=index+1;raw(index,:)=[0 c.update_mode 0 50 c.guard_s*1e6 actual.adc_aperture_end_ABC_s' ...
 actual.reference_time_s actual.task_release_s actual.observer_available_s actual.ccr_write_s ...
 actual.intended_pwm_apply_s actual.actual_pwm_apply_s actual.deadline_s actual.reserved_slack_s ...
 actual.missed_update actual.next_frame_overrun actual.speed_task_active actual.timing_valid expected.timing_valid ok];
passed=passed&&ok&&actual.next_frame_overrun&&~actual.timing_valid;
nominal=sensorless_event_plan(0,0,0,c);
physical=[nominal.adc_aperture_end_ABC_s' nominal.reference_time_s nominal.observer_available_s nominal.ccr_write_s nominal.actual_pwm_apply_s];
expected=[28.5625 27.0625 25.5625 28.875 31.875 36.875 50]*1e-6;
passed=passed&&max(abs(physical-expected))<1e-12;
m=struct('frozen_grid_cases',p.cases,'supplemental_overrun_cases',1,'total_cases',index,...
 'nominal_physical_times_s',physical,'all_passed',passed);
end

function [e,ok]=schedule_oracle(cycle,jitter,interference,c,a)
% Enumerate UEV ticks rather than using the DUT's floor/step formula.
h=c.h_s;N=round(c.period_s/h);base=cycle*N;tr=round((c.adc_trigger_s+c.adc_sync_s)/h);
rank=round(c.adc_rank_s/h);ap=round(c.adc_aperture_s/h);
adc=base+tr+[2*rank+ap;rank+ap;ap];jeos=base+tr+3*rank;
release=jeos+ceil(jitter/h-1e-9);ready=release+ceil(c.observer_exec_s/h-1e-9);
write=ready+ceil(c.foc_exec_s/h-1e-9)+ceil(interference/h-1e-9);
events=(0:40)*N/2;if c.update_mode==1,events=events(mod(events,N)==0);end
intended=events(find(events>jeos,1));actual=events(find(events>write,1));deadline=intended-ceil(c.guard_s/h-1e-9);
e=struct('timing_valid',write<deadline&&write<jeos+N);
actualTimes=[a.adc_aperture_end_ABC_s' a.reference_time_s a.task_release_s a.observer_available_s a.ccr_write_s ...
 a.intended_pwm_apply_s a.actual_pwm_apply_s a.deadline_s a.reserved_slack_s];
expectedTimes=[adc' jeos release ready write intended actual deadline deadline-write]*h;
divider=round(c.speed_period_s/c.period_s);speedCycles=(divider-1):divider:100;
ok=max(abs(actualTimes-expectedTimes))<1e-12&&a.missed_update==(actual>intended)&&a.speed_task_active==ismember(cycle,speedCycles)&&...
 a.next_frame_overrun==(write>=jeos+N)&&a.timing_valid==e.timing_valid;
end

function [m,raw]=publication_tests(c,p)
plan=sensorless_event_plan(0,0,0,c);seed=sensorless_robust_state;base=seed.output.packet;
base.sequence=0;base.reference_time_s=plan.reference_time_s;base.available_time_s=plan.observer_available_s;
base.theta_rad=.3;base.omega_e_rad_s=1000;base.input_valid=true;base.observer_valid=true;base.timing_valid=true;
raw=struct('name',{},'packet',{},'before',{},'now_s',{},'pwm_apply_s',{},'present',{},'live_input_valid',{},'live_timing_valid',{},'after',{},'output',{},'expected_permit',{},'expected_reason',{},'passed',{});
passed=true;maximum=0;
for index=1:numel(p.cases)
 name=p.cases{index};s=seed.output;packet=base;now=base.available_time_s;apply=plan.actual_pwm_apply_s;
 present=true;permit=true;reason=0;live_input=true;live_timing=true;
 switch name
  case 'no_packet',present=false;permit=false;reason=1;
  case 'normal'
  case 'future_packet',now=now-c.h_s;permit=false;reason=33;
  case 'observer_invalid',packet.observer_valid=false;permit=false;reason=4;
  case 'adc_invalid',packet.input_valid=false;permit=false;reason=2;
  case 'deadline_invalid',packet.timing_valid=false;permit=false;reason=8;
  case 'age_equal_limit',now=base.reference_time_s+c.maximum_state_age_s;apply=now;
  case 'age_one_tick_over',now=base.reference_time_s+c.maximum_state_age_s+c.h_s;apply=now;permit=false;reason=16;
  case 'apply_horizon_equal',apply=base.reference_time_s+c.maximum_apply_prediction_s;
  case 'apply_horizon_one_tick_over',apply=base.reference_time_s+c.maximum_apply_prediction_s+c.h_s;permit=false;reason=128;
  case 'apply_time_in_past',apply=now-c.h_s;permit=false;reason=32;
  case 'backward_sequence'
   old=base;old.sequence=2;[s,~]=sensorless_publish_step(s,old,true,now,apply,c,true,true);
   packet.sequence=1;packet.reference_time_s=packet.reference_time_s+c.period_s;packet.available_time_s=packet.available_time_s+c.period_s;
   now=now+c.period_s;apply=apply+c.period_s;permit=false;reason=64;
  case 'mutated_duplicate'
   [s,~]=sensorless_publish_step(s,base,true,now,apply,c,true,true);packet.theta_rad=packet.theta_rad+.1;permit=false;reason=64;
  case 'identical_duplicate',[s,~]=sensorless_publish_step(s,base,true,now,apply,c,true,true);
  case 'new_invalid_replaces_valid'
   [s,~]=sensorless_publish_step(s,base,true,now,apply,c,true,true);packet.sequence=1;packet.observer_valid=false;
   packet.reference_time_s=packet.reference_time_s+c.period_s;packet.available_time_s=packet.available_time_s+c.period_s;
   now=now+c.period_s;apply=apply+c.period_s;permit=false;reason=4;
  case 'omega_over_limit',packet.omega_e_rad_s=c.omega_limit_rad_s+1;permit=false;reason=256;
  case 'sequence_gap'
   [s,~]=sensorless_publish_step(s,base,true,now,apply,c,true,true);packet.sequence=3;
   packet.reference_time_s=packet.reference_time_s+c.period_s;packet.available_time_s=packet.available_time_s+c.period_s;
   now=now+c.period_s;apply=apply+c.period_s;permit=false;reason=64;
  case 'explicit_state_reset'
   old=base;old.sequence=2;[s,~]=sensorless_publish_step(s,old,true,now,apply,c,true,true);s=seed.output;
  case {'live_adc_fault_while_packet_pending','live_deadline_fault_without_packet','live_both_faults'}
   [s,~]=sensorless_publish_step(s,base,true,now,apply,c,true,true);
   now=base.reference_time_s+c.period_s;apply=apply+c.period_s;present=false;permit=false;
   if strcmp(name,'live_adc_fault_while_packet_pending'),live_input=false;reason=2;
   elseif strcmp(name,'live_deadline_fault_without_packet'),live_timing=false;reason=8;
   else,live_input=false;live_timing=false;reason=10;
   end
  otherwise,error('Unknown frozen publication fixture.');
 end
 before=s;[after,o]=sensorless_publish_step(s,packet,present,now,apply,c,live_input,live_timing);
 ok=o.control_permit==permit&&double(o.reason)==reason;
 if permit
  expected=[mod(base.theta_rad,2*pi),mod(base.theta_rad+base.omega_e_rad_s*(now-base.reference_time_s),2*pi),...
   mod(base.theta_rad+base.omega_e_rad_s*(apply-base.reference_time_s),2*pi)];
  actual=[o.theta_sample_rad o.theta_now_rad o.theta_pwm_rad];err=max(abs(atan2(sin(actual-expected),cos(actual-expected))));
  maximum=max(maximum,err);ok=ok&&err<=p.angular_tolerance_rad;
 else
  ok=ok&&all([o.control_theta_sample_rad o.control_theta_pwm_rad o.control_speed_rpm]==0);
 end
 if reason==64,ok=ok&&o.reset_request&&isequaln(before,after);end
 if strcmp(name,'new_invalid_replaces_valid'),ok=ok&&after.packet.sequence==1&&~after.packet.observer_valid;end
 r=struct('name',name,'packet',packet,'before',before,'now_s',now,'pwm_apply_s',apply,'present',present,...
  'live_input_valid',live_input,'live_timing_valid',live_timing,...
  'after',after,'output',o,'expected_permit',permit,'expected_reason',reason,'passed',ok);
 raw(index)=r;passed=passed&&ok;
end
m=struct('cases',numel(raw),'maximum_angle_error_rad',maximum,'all_passed',passed);
end

function [m,raw]=rejection_tests(c)
seed=sensorless_robust_state;plan=sensorless_event_plan(0,0,0,c);packet=seed.output.packet;
packet.sequence=0;packet.reference_time_s=plan.reference_time_s;packet.available_time_s=plan.observer_available_s;
packet.input_valid=true;packet.observer_valid=true;packet.timing_valid=true;
names={};rejected=[];
bad={struct('h_s',0),struct('deadtime_hat_s',-1),struct('period_s',50e-6+1e-9),...
 struct('adc_rank_s',.5e-6),struct('observer_exec_s',-1),struct('update_mode',2),...
 struct('Ron_hat_ohm',NaN),struct('pole_pairs',1.5),struct('unknown',1)};
for k=1:numel(bad),check(['config_' num2str(k)],@()sensorless_robust_config(bad{k}));end
check('gate_shootthrough',@()sensorless_deadtime_estimate_step(seed.deadtime,0,ones(6,1),c));
check('gate_off_grid',@()sensorless_deadtime_estimate_step(seed.deadtime,c.h_s/2,zeros(6,1),c));
check('gate_skip',@()sensorless_deadtime_estimate_step(seed.deadtime,c.h_s,zeros(6,1),c));
[s,~,~]=sensorless_deadtime_estimate_step(seed.deadtime,0,[1 0 0 1 0 1],c);
check('gate_same_tick_mutation',@()sensorless_deadtime_estimate_step(s,0,[0 1 0 1 0 1],c));
check('gate_reverse',@()sensorless_deadtime_estimate_step(s,-c.h_s,[1 0 0 1 0 1],c));
check('bridge_shootthrough',@()sensorless_bridge_estimate(ones(6,1),[0 0 0],[0 0 0],24,c));
check('bridge_negative_bus',@()sensorless_bridge_estimate(zeros(6,1),[0 0 0],[0 0 0],-1,c));
check('bridge_nonfinite_current',@()sensorless_bridge_estimate(zeros(6,1),[NaN 0 0],[0 0 0],24,c));
check('bridge_nonzero_emf_sequence',@()sensorless_bridge_estimate(zeros(6,1),[0 0 0],[1 0 0],24,c));
check('schedule_negative_jitter',@()sensorless_event_plan(0,-1,0,c));
check('schedule_negative_interference',@()sensorless_event_plan(0,0,-1,c));
check('schedule_noninteger_cycle',@()sensorless_event_plan(.5,0,0,c));
q=packet;q.sequence=.5;check('packet_fractional_sequence',@()sensorless_publish_step(seed.output,q,true,plan.observer_available_s,plan.actual_pwm_apply_s,c,true,true));
q=packet;q.available_time_s=q.reference_time_s-c.h_s;check('packet_reversed_times',@()sensorless_publish_step(seed.output,q,true,plan.observer_available_s,plan.actual_pwm_apply_s,c,true,true));
q=packet;q.omega_e_rad_s=NaN;check('packet_nonfinite_state',@()sensorless_publish_step(seed.output,q,true,plan.observer_available_s,plan.actual_pwm_apply_s,c,true,true));
check('packet_off_grid_query',@()sensorless_publish_step(seed.output,packet,true,plan.observer_available_s+c.h_s/2,plan.actual_pwm_apply_s,c,true,true));
raw=struct('names',{names},'rejected',rejected);
m=struct('cases',numel(rejected),'all_passed',all(rejected));
 function check(name,call)
  caught=false;try,call();catch,caught=true;end
  names{end+1}=name;rejected(end+1)=caught;
 end
end
