function [report,v,samples]=pmsm_encoder_speed_analysis(outputs,plan)
% Independent raw-count/timestamp and window-error decomposition.
assert(numel(outputs)==1&&strcmp(plan.comparison_contract.kind,'same_run_three_speed_windows_shadow'));
s=outputs{1};c=plan.comparison_contract;N=c.counts_per_mechanical_turn;dt=c.read_period_s;
t=s.log_encoder_mechanical.Time;mech=teach_values(s.log_encoder_mechanical);d=teach_values(s.log_encoder);count=d(:,2);
assert(isequal(t,s.log_encoder.Time)&&isequal(t,s.log_speed.Time)&&all(d(:,9)==0)&all(d(:,10)==0),'本实验应为理想角度控制、计数仅观测。');
raw=mod(floor(mech*(-N/(2*pi))),N);assert(isequal(d(:,1),raw)&&isequal(count,mod(-raw,N)));
assert(max(abs(diff(t)-dt))<1e-12&&abs(t(1)-c.read_offset_s)<1e-12&&all(d(:,12)==1));
truth=teach_values(s.log_speed);tc=s.log_speed_control.Time;control=teach_values(s.log_speed_control);
[found,at]=ismember(round(tc/c.event_step_s),round(t/c.event_step_s));assert(all(found));
inputError=max(abs(control-truth(at)));assert(inputError<1e-9,'速度PI输入没有保持原真值路径。');
assert(max(abs(diff(tc)-c.speed_period_s))<1e-12&&at(1)==2&&all(diff(at)==2));
report=struct('schema',1,'contract',c,'speed_control_input_max_error_rpm',inputError,'windows',struct([]));v=cell(1,3);tables=cell(1,3);
logs={'log_speed_short','log_speed_window','log_speed_long'};
for k=1:3
 W=c.window_ticks(k);a=teach_values(s.(logs{k}));assert(isequal(s.(logs{k}).Time,t)&&size(a,2)==7);
 indices=(W+1:numel(t))';start=indices-W;delta=count(indices)-count(start);delta=delta-N*floor((delta+N/2)/N);
 uniqueDirection=abs(delta)<N/2;expectedValid=false(size(t));expectedValid(indices)=uniqueDirection;
 assert(isequal(a(:,2)>.5,expectedValid),'历史有效性或半圈方向判定不符。');
 expected=zeros(size(t));expected(indices(uniqueDirection))=delta(uniqueDirection)*60/(N*W*dt);
 assert(max(abs(a(:,1)-expected))<1e-9&&all(a(~expectedValid,1)==0),'测速并非指定历史计数差分。');
 assert(isequal(a(indices,3),delta)&&isequal(a(indices,7),count(start)));
 assert(max(abs(a(indices,4)-W*dt))<1e-12&&max(abs(a(indices,5)-t(start)))<1e-12&&max(abs(a(:,6)-t))<1e-12,'窗口端点时戳不符。');
 angleSpan=mech(indices)-mech(start);assert(all(abs(angleSpan)<pi-1e-9),'该工况超出半圈解绕有效域，不能按本差分模型解释测速。');
 windowTruth=nan(size(t));windowTruth(indices)=angleSpan*60/(2*pi*W*dt);
 quantError=a(:,1)-windowTruth;windowError=windowTruth-truth;totalError=a(:,1)-truth;
 residual=totalError(expectedValid)-quantError(expectedValid)-windowError(expectedValid);assert(max(abs(residual))<1e-9);
 assert(max(abs(quantError(expectedValid)))<=c.rpm_per_count_step(k)+1e-8,'计数量化误差超出单计数差分边界。');
 tail=expectedValid&t>=plan.statistics_window_s(1);assert(any(tail));
 metric=struct('window_ticks',W,'window_s',W*dt,'rpm_per_count',c.rpm_per_count_step(k), ...
  'invalid_initial_samples',W,'valid_sample_count',sum(expectedValid),'raw_speed_max_check_error_rpm',max(abs(a(:,1)-expected)), ...
  'quantization_rms_rpm',sqrt(mean(quantError(tail).^2)),'window_error_rms_rpm',sqrt(mean(windowError(tail).^2)), ...
  'total_error_rms_rpm',sqrt(mean(totalError(tail).^2)),'total_error_mean_rpm',mean(totalError(tail)), ...
  'decomposition_max_residual_rpm',max(abs(residual)),'firmware_default_window',W==2);
 if k==1,report.windows=metric;else,report.windows(k)=metric;end
 v{k}=struct('time',t,'speed',a(:,1),'valid',expectedValid,'truth',truth,'window_truth',windowTruth, ...
  'quantization_error',quantError,'window_error',windowError,'total_error',totalError,'count',count,'label',[num2str(W) '拍']);
 origin=zeros(size(t));origin(indices)=start;origin(~expectedValid)=0;originTime=nan(size(t));originTime(expectedValid)=a(expectedValid,5);
 tables{k}=table(repmat(W,numel(t),1),(1:numel(t))',t,count,origin,originTime,a(:,1),expectedValid,truth,windowTruth,quantError,windowError,totalError, ...
  'VariableNames',{'window_ticks','sample_index','time_s','corrected_count','source_sample_index','source_time_s','estimated_rpm','valid', ...
  'instantaneous_truth_rpm','window_truth_rpm','quantization_error_rpm','window_error_rpm','total_error_rpm'});
end
samples=vertcat(tables{:});
end
