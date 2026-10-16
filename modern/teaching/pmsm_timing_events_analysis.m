function [r,trace]=pmsm_timing_events_analysis(outputs,plan)
% Verify actual event records against frozen timing parameters and raw truth.
assert(strcmp(plan.scenario.id,'timing_events')&&numel(outputs)==2);
s=outputs{2};c=plan.comparison_contract;h=c.event_step_s;Ts=c.pwm_period_s;N=round(Ts/h);
ta=s.obs_adc_timing.Time;tp=s.obs_pwm_timing.Time;a=teach_values(s.obs_adc_timing);p=teach_values(s.obs_pwm_timing);
assert(isequal(ta,tp)&&size(a,2)==15&&size(p,2)==12);ticks=round(ta/h);
assert(all(diff(ticks)==1)&&abs(median(diff(ta))-h)<1e-14);
assert(max(abs(a(:,1)-mod(ticks,N)*h))<1e-12);
tr=c.trigger_phase_s+c.trigger_sync_s;jeos=tr+3*c.rank_s;write=jeos+c.compute_us*1e-6;
opportunity=Ts/2;if strcmp(c.update_mode,'仅谷底（对照）'),opportunity=Ts;end
latch=(floor((write/h)/(opportunity/h))+1)*opportunity;
offsets=[tr tr+c.aperture_s tr+c.rank_s+c.aperture_s tr+2*c.rank_s+c.aperture_s jeos];
for k=1:5
 ix=a(:,k+1)>0;assert(any(ix));assert(all(mod(ticks(ix),N)==round(offsets(k)/h)));
 if nnz(ix)>1,assert(all(diff(ticks(ix))==N));end
end
current=a(:,15)>0;speed=a(:,14)>0;assert(isequal(current,a(:,6)>0)&&any(speed));
speedTicks=round(c.speed_period_s/h);speedOffset=round((jeos+c.speed_period_s-Ts)/h);
assert(all(mod(ticks(speed),speedTicks)==speedOffset));
if nnz(speed)>1,assert(all(diff(ticks(speed))==speedTicks));end
w=find(p(:,4)>0);u=find(p(:,5)>0);uev=p(:,3)>0;
assert(~isempty(w)&&~isempty(u)&&all(mod(ticks(w),N)==round(write/h)));
assert(all(mod(ticks(uev),round(opportunity/h))==0)&&all(mod(ticks(u),N)==mod(round(latch/h),N)));
assert(all(diff(p(w,6))==1)&&all(diff(p(u,7))==1));
commands=struct('sequence',{},'jeos_time_s',{},'write_time_s',{},'apply_time_s',{},'compute_us',{},'write_wait_us',{},'jeos_to_apply_us',{});
for j=u(:)'
 seq=p(j,7);iw=w(p(w,6)==seq);if isempty(iw),continue;end;assert(isscalar(iw));
 tjeos=floor(ticks(iw)/N)*Ts+jeos;delay=(tp(j)-tjeos)*1e6;
 assert(abs(p(j,9)*1e6-delay)<1e-7&&abs(delay-(latch-jeos)*1e6)<1e-7);
 commands(end+1)=struct('sequence',seq,'jeos_time_s',tjeos,'write_time_s',tp(iw),'apply_time_s',tp(j), ...
  'compute_us',(tp(iw)-tjeos)*1e6,'write_wait_us',(tp(j)-tp(iw))*1e6,'jeos_to_apply_us',delay); %#ok<AGROW>
end
assert(numel(commands)>=2,'必须保留至少两次可完整配对的写入/生效事件。');
% Compare delivered ADC values with exact aperture endpoints, not interpolation.
tf=s.obs_current_fast.Time;truth=teach_values(s.obs_current_fast);truthTicks=round(tf/h);
assert(abs(median(diff(tf))-h)<1e-14&&all(diff(truthTicks)==1));j=find(current);
sampleErrors=zeros(numel(j),3);
for phase=1:3
 endpoint=tr+(3-phase)*c.rank_s+c.aperture_s;
 sampleTicks=floor(ticks(j)/N)*N+round(endpoint/h);[found,where]=ismember(sampleTicks,truthTicks);assert(all(found));
 sampleErrors(:,phase)=a(j,phase+9)-truth(where,phase);
end
assert(max(abs(sampleErrors),[],'all')<1e-8,'顺序采样值与本组孔径结束真值不一致。');
% Independently observe the command leaving the preload selector at UEV.
tt=s.log_Tcm_applied.Time;applied=teach_values(s.log_Tcm_applied);appliedTicks=round(tt/h);
assert(abs(median(diff(tt))-h)<1e-14);[found,where]=ismember(ticks(u),appliedTicks);assert(all(found));
appliedError=max(abs(applied(where,:)-p(u,10:12)),[],'all');assert(appliedError<1e-14,'生效事件与实际输出阈值不一致。');
firstTick=round(plan.duration_s/h)-2*N;plotWindow=[firstTick firstTick+2*N]*h;
assert(plotWindow(1)>=max(ta(1),tf(1))&&plotWindow(2)<=min(ta(end),tf(end))+h/10);
defs={'trigger','触发','adc',2;'sample_c','C采样','adc',3;'sample_b','B采样','adc',4;'sample_a','A采样','adc',5; ...
 'jeos','JEOS','adc',6;'current','电流环','adc',15;'speed','速度环','adc',14; ...
 'write','CCR写入','pwm',4;'uev','UEV机会','pwm',3;'apply','CCR生效','pwm',5};
events=struct('id',{},'label',{},'time_s',{},'cycle_index',{},'phase_us',{});
for row=defs'
 data=a;if strcmp(row{3},'pwm'),data=p;end
 for ix=find(data(:,row{4})>0)'
  events(end+1)=struct('id',row{1},'label',row{2},'time_s',ta(ix),'cycle_index',floor(ticks(ix)/N),'phase_us',mod(ticks(ix),N)*h*1e6); %#ok<AGROW>
 end
end
[~,order]=sort([events.time_s]);events=events(order);
r=struct('schema',1,'scope','已有真实时序事件核对；简化模式与事件模式的差别不归因为纯延迟。', ...
 'event_step_s',h,'pwm_period_s',Ts,'current_period_s',Ts,'current_offset_s',jeos, ...
 'speed_period_s',c.speed_period_s,'speed_offset_s',speedOffset*h,'trigger_phase_s',tr, ...
 'sample_offsets_ABC_s',[tr+2*c.rank_s+c.aperture_s tr+c.rank_s+c.aperture_s tr+c.aperture_s], ...
 'jeos_phase_s',jeos,'write_phase_s',write,'update_opportunity_period_s',opportunity, ...
 'compute_us',c.compute_us,'write_wait_us',(latch-write)*1e6,'jeos_to_apply_us',(latch-jeos)*1e6, ...
 'event_record_window_s',[ta(1) ta(end)],'truth_record_window_s',[tf(1) tf(end)],'plot_window_s',plotWindow, ...
 'current_event_count',nnz(current),'speed_event_count',nnz(speed),'paired_command_count',numel(commands), ...
 'sample_error_max_ABC_A',max(abs(sampleErrors),[],1),'applied_command_max_error_s',appliedError, ...
 'delivered_current_sum_rms_A',sqrt(mean(a(j,13).^2)),'window_flags_at_jeos_ABC',mean(a(j,7:9),1), ...
 'control_log_first_time_s',s.log_speed.Time(1),'control_log_period_s',median(diff(s.log_speed.Time)), ...
 'trigger_phase_measured',false,'compute_time_measured',false,'commands',commands,'events',events);
assert(all(teach_values(outputs{1}.obs_adc_timing)==0,'all')&&all(teach_values(outputs{1}.obs_pwm_timing)==0,'all'));
trace=struct('adc_time_s',ta,'adc',a,'pwm_time_s',tp,'pwm',p,'truth_time_s',tf,'truth_ABC_A',truth, ...
 'applied_time_s',tt,'applied_threshold_s',applied,'origin_s',plotWindow(1),'window_us',[0 2*Ts*1e6]);
end
