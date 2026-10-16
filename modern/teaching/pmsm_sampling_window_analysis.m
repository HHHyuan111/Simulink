function [r,z,samples]=pmsm_sampling_window_analysis(outputs,plan)
% Check each aperture from raw gate history, each accepted sample from plant
% truth, and every held output from preceding valid measurements only.
assert(strcmp(plan.scenario.id,'sampling_window')&&numel(outputs)==3);
c=plan.comparison_contract;h=c.event_step_s;N=round(c.pwm_period_s/h);tr=round(c.trigger_phase_s/h);
rank=round(c.rank_s/h);ap=round(c.aperture_s/h);guard=ceil(c.settle_s/h);J=tr+3*rank;
r=struct('schema',1,'scope',c.scope,'trigger_us',c.trigger_phase_s*1e6,'settle_us',c.settle_s*1e6, ...
 'settle_ticks',guard,'event_step_s',h,'jeos_phase_us',J*h*1e6, ...
 'sample_end_CBA_us',(tr+(0:2)*rank+ap)*h*1e6,'statistics_window_s',plan.statistics_window_s, ...
 'plot_window_s',plan.plot_window_s,'adc_record_kind','全程JEOS快照，不是全网格ADC事件记录', ...
 'cases',struct([]),'example',struct);z=cell(1,3);tables=cell(1,3);
for k=1:3
 s=outputs{k};t=s.obs_adc_timing.Time;a=teach_values(s.obs_adc_timing);ticks=round(t/h);n=numel(t);
 assert(size(a,2)==15&&ticks(1)==J&&all(diff(ticks)==N)&&all(a(:,6)==1)&&all(a(:,15)==1));
 assert(isequal(t,s.log_iabc_meas.Time)&&isequal(t,s.log_speed.Time));
 valid=a(:,7:9)>0;delivered=a(:,10:12);measured=teach_values(s.log_iabc_meas);
 controllerError=max(abs(measured-delivered),[],'all');assert(controllerError<1e-10);
 g=teach_values(s.obs_dead_requested);gt=round(s.obs_dead_requested.Time/h);
 truth=teach_values(s.obs_current_fast);ft=round(s.obs_current_fast.Time/h);
 assert(size(g,2)==6&&gt(1)==0&&all(diff(gt)==1)&&ft(1)==0&&all(diff(ft)==1));
 assert(size(truth,2)==3&&gt(end)==round(plan.duration_s/h)&&ft(end)==gt(end));
 assert(all(g==0|g==1,'all'));
 actual=teach_values(s.obs_dead_gates);at=round(s.obs_dead_gates.Time/h);
 assert(all(diff(at)==1)&&all(at>=0)&&all(at<=gt(end)));
 gateError=max(abs(actual-g(at+1,:)),[],'all');assert(gateError==0,'死区关闭时实际门极应等于请求。');
 raw=zeros(n,3);predicted=false(n,3);base=floor(ticks/N)*N;
 for phase=1:3
  first=base+tr+(3-phase)*rank;last=first+ap;
  % Cached gate at ADC tick q is SW(q-1). elapsed>guard throughout the
  % aperture is equivalent to no OFF tick in this extended interval.
  % Virtual tick -1 is the model's single initial gate-history value;
  % earlier history does not exist, so an insufficient initial wait fails.
  lo=first-guard-1;hi=last-1;known=lo>=-1;
  initial=c.initial_gate_history(:)';low=[initial(2*phase);g(:,2*phase)]>0;
  offPrefix=[0;cumsum(~low)];predicted(known,phase)=offPrefix(hi(known)+3)-offPrefix(lo(known)+2)==0;
  raw(:,phase)=truth(last+1,phase);
 end
 flagErrors=nnz(predicted~=valid);assert(flagErrors==0,'孔径/稳定等待与原始门极不一致。');
 accepted=valid;if k==1,accepted=true(size(valid));end
 sampleError=0;if any(accepted,'all'),sampleError=max(abs(delivered(accepted)-raw(accepted)));end;assert(sampleError<1e-8);
 sources=zeros(n,3);ages=nan(n,3);lastGood=zeros(1,3);lastIndex=zeros(1,3);policyError=0;
 for j=1:n
  for phase=1:3
   if valid(j,phase),lastGood(phase)=delivered(j,phase);lastIndex(phase)=j;end
   if k==1
    sources(j,phase)=j;
   elseif valid(j,phase)
    sources(j,phase)=j;
   elseif k==2
    policyError=max(policyError,abs(delivered(j,phase)));
   else
    sources(j,phase)=lastIndex(phase);policyError=max(policyError,abs(delivered(j,phase)-lastGood(phase)));
    assert(lastIndex(phase)<j,'保持值不能来自本次无效样本或未来样本。');
   end
   if sources(j,phase)>0,ages(j,phase)=(j-sources(j,phase))*N*h*1e6;end
  end
 end
 assert(policyError<1e-12);stat=t>=plan.statistics_window_s(1)&t<=plan.statistics_window_s(2);
 maxAge=zeros(1,3);initialZero=zeros(1,3);
 for phase=1:3
  age=ages(~valid(:,phase)&sources(:,phase)>0,phase);if ~isempty(age),maxAge(phase)=max(age);end
  initialZero(phase)=nnz(~valid(:,phase)&sources(:,phase)==0);
 end
 row=struct('id',plan.cases(k).id,'label',plan.cases(k).label,'jeos_sample_count',n, ...
  'valid_fraction_full_ABC',mean(valid,1),'valid_fraction_tail_ABC',mean(valid(stat,:),1), ...
  'invalid_count_ABC',sum(~valid,1),'aperture_flag_mismatch_count',flagErrors, ...
  'accepted_phase_sample_count',nnz(accepted),'accepted_sample_max_error_A',sampleError,'policy_max_error_A',policyError, ...
  'controller_path_max_error_A',controllerError,'requested_actual_gate_tail_max_error',gateError, ...
  'max_known_source_age_us_ABC',maxAge,'invalid_initial_zero_count_ABC',initialZero, ...
  'measurement_rms_at_jeos_ABC_A',zeros(1,3));
 % Statistics compare feedback and simultaneous physical current; the raw
 % aperture samples above separately verify the earlier sequential captures.
 physical=teach_values(s.log_iabc_true);row.measurement_rms_at_jeos_ABC_A=sqrt(mean((measured(stat,:)-physical(stat,:)).^2,1));
 if k==1,r.cases=row;else,r.cases(k)=row;end
 tab=table(repmat({row.id},n,1),(1:n)',floor(ticks/N),t,'VariableNames',{'case_id','sample_index','cycle_index','jeos_time_s'});
 for phase=1:3
  tag=char('A'+phase-1);tab.(['valid_' tag])=valid(:,phase);tab.(['aperture_truth_' tag '_A'])=raw(:,phase);
  tab.(['delivered_' tag '_A'])=delivered(:,phase);tab.(['source_sample_index_' tag])=sources(:,phase);tab.(['source_age_' tag '_us'])=ages(:,phase);
 end
 tables{k}=tab;
 keep=s.obs_current_fast.Time>=plan.plot_window_s(1)&s.obs_current_fast.Time<=plan.plot_window_s(2);
 z{k}=struct('sample_time_s',t,'valid',valid,'delivered',delivered,'raw_aperture_ABC_A',raw,'source_age_us_ABC',ages, ...
  'truth_plot_time_s',s.obs_current_fast.Time(keep),'truth_plot_ABC_A',truth(keep,:));
end
assert(isequal(outputs{1}.obs_adc_timing.Time,outputs{2}.obs_adc_timing.Time)&&isequal(outputs{1}.obs_adc_timing.Time,outputs{3}.obs_adc_timing.Time));
% Deterministic teaching example: latest sample having the most invalid
% channels in the zero group within the displayed current window.
t=z{2}.sample_time_s;eligible=find(t>=plan.plot_window_s(1)&t<=plan.plot_window_s(2));assert(~isempty(eligible));
bad=sum(~z{2}.valid(eligible,:),2);j=eligible(find(bad==max(bad),1,'last'));cycle=floor(round(t(j)/h)/N);start=cycle*N;
r.example=struct('sample_index',j,'cycle_index',cycle,'cycle_start_time_s',start*h, ...
 'selection','置零组最后10ms内，无效相数最多的最后一次JEOS；全有效时取最后一次。', ...
 'sample_start_ABC_us',(tr+(2:-1:0)*rank)*h*1e6,'sample_end_ABC_us',(tr+(2:-1:0)*rank+ap)*h*1e6, ...
 'valid_ABC_by_case',vertcat(z{1}.valid(j,:),z{2}.valid(j,:),z{3}.valid(j,:)));
for k=1:3
 s=outputs{k};g=teach_values(s.obs_dead_requested);gt=round(s.obs_dead_requested.Time/h);
 cachedTicks=[0;gt+1];cached=[c.initial_gate_history(:)';g];keep=cachedTicks>=start&cachedTicks<=start+N;
 z{k}.gate_time_us=(cachedTicks(keep)-start)*h*1e6;z{k}.gate_history=cached(keep,:);
end
samples=vertcat(tables{:});
end
