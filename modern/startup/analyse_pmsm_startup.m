function report=analyse_pmsm_startup(s,record)
% Full retained gate/PWM history, actual PI logs and state sequence.
assert(record.enabled);
t=s.log_startup.Time;q=v(s,'log_startup');dt=50e-6;h=62.5e-9;offset=28.875e-6;
assert(isequal(unique(q(:,1))',(0:4)));
assert(all(q(q(:,1)<3,2)==0)&&all(q(q(:,1)<4,3)==0));
assert(all(q(q(:,1)<2,4)==0));
step=round((t-offset)/dt);speedHit=mod(step,2)==1;
runEdges=find(diff([false;q(:,1)==4])==1);assert(numel(runEdges)==2&&all(speedHit(runEdges)));
sampleEdges=find(diff([false;q(:,1)==2])==1);currentEdges=find(diff([false;q(:,1)>=3])==1);
assert(numel(sampleEdges)==2&&numel(currentEdges)==2);
assert(all(t(currentEdges)>t(sampleEdges))&&all(t(runEdges)>t(currentEdges)));
stop=find(t>=record.times_ms(2)*1e-3,1);restart=find(t>=record.times_ms(3)*1e-3,1);
assert(all(q(stop:restart-1,1)==0)&&q(restart,1)==1);
assert(abs(t(stop)-record.times_ms(2)*1e-3)<=dt&&abs(t(restart)-record.times_ms(3)*1e-3)<=dt);
g=v(s,'obs_dead_gates');tg=s.obs_dead_gates.Time;
assert(max(abs(diff(tg)-h))<1e-12&&abs(tg(1))<h/2&&abs(tg(end)-record.times_ms(4)*1e-3)<h/2);
state=at(tg,t,q(:,1));assert(all(g(state<2,:)==0,'all'));
assert(all(g(state==2,:)==repmat([0 1 0 1 0 1],sum(state==2),1),'all'));
assert(all(g(:,1:2:5)+g(:,2:2:6)<=1,'all'));
adc=v(s,'obs_adc_timing');assert(isequal(s.obs_adc_timing.Time,t));
assert(all(adc(currentEdges,6)>.5));
if record.window_on,assert(all(adc(currentEdges,7:9)>.5,'all'));end
for row={'obs_pi_d',2;'obs_pi_q',2;'obs_pi_speed',3}'
 name=row{1};permit=q(:,row{2});pi=v(s,name);tp=s.(name).Time;
 assert(isequal(tp,t));valid=true(size(t));if row{2}==3,valid=speedHit;end
 assert(all(abs(pi(permit==0&valid,2))<1e-12),'PI integral did not reset: %s',name);
 assert(all(abs(pi(permit==0&valid,4))<1e-12),'PI output did not clear: %s',name);
end
iq=v(s,'log_iq_ref');assert(all(abs(iq(q(:,3)==0))<1e-12)&&max(abs(iq))<=8+1e-9);
pwm=v(s,'obs_pwm_timing');tw=s.obs_pwm_timing.Time;active=v(s,'log_Tcm_applied');
assert(isequal(round(tw/h),round(s.log_Tcm_applied.Time/h))&&numel(tw)==numel(tg));
allowed=at(tw,t,q(:,2));assert(all(pwm(allowed==0,4:9)==0,'all'));
assert(all(abs(active(allowed==0,:)-dt/4)<1e-15,'all'));
% Every applied update must originate from a new write after current takeover.
write=find(pwm(:,4)>.5);latch=find(pwm(:,5)>.5);assert(~isempty(write)&&~isempty(latch));
last=cummax((1:numel(tw))'.*(pwm(:,4)>.5));origin=last(latch);assert(all(origin>0));
requests=v(s,'log_Tcm_requested');tr=s.log_Tcm_requested.Time;assert(abs(tr(1)-offset)<1e-12);
req=round((tw(origin)-offset-5e-6)/dt)+1;assert(all(req>=1&req<=numel(tr)));
assert(max(abs(tr(req)-(tw(origin)-5e-6)))<1e-12);
expected=dt/2*(1-floor(max(0,min(1,1-2*requests(req,:)/dt))*4000+1e-9)/4000);
error=max(abs(active(latch,:)-expected),[],'all');assert(error<1e-15);
for j=1:2
 begin=t(currentEdges(j));if j==1,finish=t(stop);else,finish=inf;end
 ix=find(tw(latch)>=begin&tw(latch)<finish);assert(~isempty(ix));
 assert(all(tw(origin(ix))>=begin)&&pwm(latch(ix(1)),7)==1,'Old CCR history replayed.');
end
speed=v(s,'log_speed');assert(max(abs(speed(stop:restart)))>1&&abs(speed(restart))>1,'No rotating-restart demonstration.');
report=struct('passed',true,'kind',record.kind,'times_ms',record.times_ms,'window_on',record.window_on,...
 'sampling_start_s',t(sampleEdges)','current_takeover_s',t(currentEdges)','speed_takeover_s',t(runEdges)',...
 'stop_accepted_s',t(stop),'restart_accepted_s',t(restart),...
 'full_gate_samples',numel(tg),'all_stopped_gates_zero',true,'all_sampling_low_sides_on',true,...
 'all_gate_pairs_interlocked',true,'pi_reset_at_native_tasks',true,'stale_pwm_queue_rejected',true,...
 'actual_ccr_source_max_error_s',error,'restart_speed_rpm',speed(restart),...
 'boundary','Known electrical zero; low-side zero-vector preparation; readiness uses previous fast-cycle validity; no alignment, fault protection or bumpless transfer.');
end
function x=v(s,name),x=teach_values(s.(name));end
function value=at(times,t,data)
dt=50e-6;h=62.5e-9;offset=round(t(1)/h);idx=floor((round(times/h)-offset)/round(dt/h))+1;
value=zeros(size(times));valid=idx>=1;assert(all(idx(valid)<=numel(data)));value(valid)=data(idx(valid));
end
