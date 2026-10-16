function [report,v,samples]=pmsm_speed_feedback_analysis(outputs,plan)
% Check the estimator from counts, then the ACTUAL held input to the speed PI.
filterCase=strcmp(plan.comparison_contract.kind,'speed_filter_pair');n=numel(outputs);
assert((n==3&&strcmp(plan.comparison_contract.kind,'speed_feedback_three_cases'))||(n==2&&filterCase));
c=plan.comparison_contract;N=c.counts_per_mechanical_turn;dt=c.read_period_s;
report=struct('schema',1,'contract',c,'cases',struct([]));v=cell(1,n);tables=cell(1,n);logs={'log_speed_short','log_speed_window','log_speed_long'};
for k=1:n
 s=outputs{k};t=s.log_encoder_mechanical.Time;mech=teach_values(s.log_encoder_mechanical);enc=teach_values(s.log_encoder);count=enc(:,2);truth=teach_values(s.log_speed);
 assert(isequal(t,s.log_encoder.Time)&&isequal(t,s.log_speed.Time)&&all(enc(:,9:10)==0,'all'));
 raw=mod(floor(mech*(-N/(2*pi))),N);assert(isequal(enc(:,1),raw)&&isequal(count,mod(-raw,N)));
 assert(max(abs(diff(t)-dt))<1e-12&&abs(t(1)-c.read_offset_s)<1e-12&&all(enc(:,12)==1));
 windowMetrics=struct([]);
 for j=1:3
  W=c.window_ticks(j);a=teach_values(s.(logs{j}));ix=(W+1:numel(t))';old=ix-W;
  assert(isequal(s.(logs{j}).Time,t)&&size(a,2)==7);
  delta=count(ix)-count(old);delta=delta-N*floor((delta+N/2)/N);ok=abs(delta)<N/2;
  valid=false(size(t));valid(ix)=ok;expected=zeros(size(t));expected(ix(ok))=delta(ok)*60/(N*W*dt);
  assert(isequal(a(:,2)>.5,valid)&&max(abs(a(:,1)-expected))<1e-9);
  assert(isequal(a(ix,3),delta)&&isequal(a(ix,7),count(old))&&max(abs(a(ix,4)-W*dt))<1e-12);
  assert(max(abs(a(ix,5)-t(old)))<1e-12&&max(abs(a(:,6)-t))<1e-12);
  span=mech(ix)-mech(old);assert(all(abs(span)<pi-1e-9),'窗口超过半圈有效域。');
  average=nan(size(t));average(ix)=span*60/(2*pi*W*dt);quant=a(:,1)-average;lag=average-truth;total=a(:,1)-truth;
  tail=valid&t>=plan.statistics_window_s(1);assert(any(tail)&&max(abs(quant(valid)))<=c.rpm_per_count_step(j)+1e-8);
  assert(max(abs(total(valid)-quant(valid)-lag(valid)))<1e-9);
  m=struct('window_ticks',W,'rpm_per_count',c.rpm_per_count_step(j),'quantization_rms_rpm',sqrt(mean(quant(tail).^2)), ...
   'window_error_rms_rpm',sqrt(mean(lag(tail).^2)),'total_error_rms_rpm',sqrt(mean(total(tail).^2)));
  if j==1,windowMetrics=m;else,windowMetrics(j)=m;end
 end
 tc=s.log_speed_control.Time;input=teach_values(s.log_speed_control);d=teach_values(s.log_speed_feedback);
 assert(isequal(tc,s.log_speed_feedback.Time)&&size(d,2)==8);
 [found,at]=ismember(round(tc/c.event_step_s),round(t/c.event_step_s));assert(all(found)&&at(1)==2&&all(diff(at)==2));
 assert(max(abs(diff(tc)-c.speed_period_s))<1e-12&&abs(tc(1)-(c.read_offset_s+dt))<1e-12);
 choice=c.window_choice(k);W=c.window_ticks(choice);candidate=teach_values(s.(logs{choice}));candidate=candidate(at,:);
 assert(isequal(d(:,1),candidate(:,1))&&isequal(d(:,2),candidate(:,2))&&all(d(:,3)==c.feedback_on(k))&&all(d(:,4)==choice));
 assert(max(abs(d(:,5)-truth(at)))<1e-9&&max(abs(d(:,7)-t(at)))<1e-12&&isequal(d(:,8),candidate(:,5)));
 expected=truth(at);if c.feedback_on(k),expected=candidate(:,1);expected(candidate(:,2)<.5)=0;end
 if filterCase
  full=teach_values(s.(logs{choice}));f=teach_values(s.log_speed_filter);assert(isequal(s.log_speed_filter.Time,t)&&size(f,2)==7);
  a=1/(1+2*pi*c.cutoff_hz*dt);b=1-a;y=zeros(size(t));state=0;
  for j=1:numel(t),state=b*full(j,1)+a*state;y(j)=state;end
  effective=full(:,1);if c.filter_on(k),effective=y;effective(full(:,2)<.5)=0;end
  assert(isequal(f(:,1),full(:,1))&&max(abs(f(:,2)-y))<1e-9&&max(abs(f(:,3)-effective))<1e-9);
  assert(isequal(f(:,4),full(:,2))&&all(f(:,5)==c.filter_on(k))&&max(abs(f(:,6)-a))<1e-14&&max(abs(f(:,7)-b))<1e-14);
  expected=effective(at);
 end
 error=max(abs(input-expected));assert(error<1e-9&&max(abs(input-d(:,6)))<1e-9,'实际速度PI输入来源或保持时刻不符。');
 tail=tc>=plan.statistics_window_s(1);feedbackError=input-truth(at);iq=teach_values(s.log_iq_ref);torque=teach_values(s.log_Te);fastTail=t>=plan.statistics_window_s(1);
 m=struct('id',plan.cases(k).id,'label',plan.cases(k).label,'feedback_on',c.feedback_on(k),'window_ticks',W, ...
  'pi_input_max_check_error_rpm',error,'invalid_speed_task_samples',sum(candidate(:,2)<.5), ...
  'feedback_error_rms_rpm',sqrt(mean(feedbackError(tail).^2)), ...
  'iq_command_step_rms_A',sqrt(mean(diff(iq(fastTail)).^2)),'torque_std_Nm',std(torque(fastTail)), ...
  'final_speed_rpm',truth(end),'windows',windowMetrics);
 if filterCase,m.filter_on=c.filter_on(k);m.cutoff_hz=c.cutoff_hz;m.filter_a=a;m.filter_b=b;m.filter_recursion_max_error_rpm=max(abs(f(:,2)-y));end
 if k==1,report.cases=m;else,report.cases(k)=m;end
 v{k}=struct('time',tc,'truth',truth(at),'input',input,'candidate',candidate(:,1),'valid',candidate(:,2)>.5,'error',feedbackError,'label',plan.cases(k).label);
 origin=max(at-W,0);origin(candidate(:,2)<.5)=0;sourceTime=candidate(:,5);sourceTime(candidate(:,2)<.5)=NaN;
 tables{k}=table(repmat(string(plan.cases(k).id),numel(tc),1),tc,at,count(at),origin,sourceTime,candidate(:,1),candidate(:,2)>.5,d(:,3),d(:,4),truth(at),input,feedbackError, ...
  'VariableNames',{'case_id','speed_task_time_s','current_read_index','corrected_count','source_read_index','source_time_s', ...
  'candidate_rpm','candidate_valid','feedback_on','window_choice','truth_rpm','actual_pi_input_rpm','feedback_error_rpm'});
end
samples=vertcat(tables{:});
end
