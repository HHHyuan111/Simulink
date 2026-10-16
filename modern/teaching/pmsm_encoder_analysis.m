function [report,series,samples]=pmsm_encoder_analysis(outputs,plan)
% Independent count, timestamp and actual Park-input checks from raw logs.
c=plan.comparison_contract;assert(strcmp(c.kind,'mechanical_count_angle_three_cases'));
report=struct('schema',1,'scope',c.scope,'contract',c,'cases',struct([]));series=cell(1,3);tables=cell(1,3);
for k=1:3
 s=outputs{k};d=teach_values(s.log_encoder);t=s.log_encoder.Time;
 mech=teach_values(s.log_encoder_mechanical);tr=s.log_encoder_mechanical.Time;
 used=teach_values(s.log_encoder_control);assert(size(d,2)==12&&size(used,2)==2&&isequal(tr,s.log_encoder_control.Time));
 assert(max(abs(diff(tr)-c.read_period_s))<1e-12&&abs(tr(1)-c.read_offset_s)<1e-12);
 N=c.counts_per_mechanical_turn;p=c.pole_pairs;cfg=plan.encoder_configurations(k);
 raw=mod(floor(mech*(c.sensor_direction*N/(2*pi))),N);
 corrected=mod(c.software_direction*raw,N);angle=mod(corrected*(2*pi/N)*p+c.electrical_zero_deg*pi/180,2*pi);
 trueAngle=mod(mech*p,2*pi);fresh=d(:,12)>.5;valid=d(:,8)>.5;
 [found,current]=ismember(round(d(fresh,6)/c.event_step_s),round(tr/c.event_step_s));assert(all(found));
 assert(isequal(d(fresh,1),raw(current))&&isequal(d(fresh,2),corrected(current)),'计数或方向修正与机械真值不符。');
 freshError=max(abs(wrap(d(fresh,4)-angle(current))));assert(freshError<1e-10);
 assert(isequal(s.log_theta_meas.Time,t)&&max(abs(wrap(teach_values(s.log_theta_meas)-d(:,5))))<1e-12);
 delay=0;if strcmp(cfg.delay_on,'on'),delay=str2double(cfg.delay_cycles);end
 enc=strcmp(cfg.encoder_on,'on');expect=angle;source=(1:numel(tr))';sourceValid=true(size(source));
 if delay>0
  expect=[zeros(delay,1);angle(1:end-delay)];source=(1:numel(tr))'-delay;sourceValid=source>0;
 end
 if ~enc,expect=trueAngle;source=(1:numel(tr))';sourceValid(:)=true;end
 controlError=max(abs(wrap(used(:,1)-expect)));inverseError=max(abs(wrap(used(:,2)-used(:,1))));
 assert(controlError<1e-9&&inverseError<1e-12,'计数/延迟角度未按计划进入实际Park和逆Park。');
 if enc
  [found,from]=ismember(round(d(valid,7)/c.event_step_s),round(tr/c.event_step_s));assert(all(found));
  assert(isequal(d(valid,11),raw(from))&&max(abs(wrap(d(valid,5)-angle(from))))<1e-10,'输出使用了错误来源样本。');
  [found,nowIndex]=ismember(round(d(valid,6)/c.event_step_s),round(tr/c.event_step_s));assert(all(found));
  assert(all(from==nowIndex-delay)&&all(d(valid,7)<=d(valid,6)),'延迟样本不是指定历史拍。');
  assert(all(d(~valid,5)==0),'无有效历史时应输出零初值。');
  expectedValid=false(size(t));expectedValid(fresh)=current>delay;
  assert(isequal(valid,expectedValid),'初始化或有效时刻不符。');
 end
 % Check the original Clarke/Park with the actual sampled transform angle.
 currentAtLog=floor((t-c.read_offset_s)/c.read_period_s+1e-8)+1;
 theta=zeros(size(t));has=currentAtLog>0;theta(has)=used(currentAtLog(has),1);
 abc=teach_values(s.log_iabc_meas);alpha=(2*abc(:,1)-abc(:,2)-abc(:,3))/3;beta=(abc(:,2)-abc(:,3))/sqrt(3);
 park=[alpha.*cos(theta)+beta.*sin(theta),-alpha.*sin(theta)+beta.*cos(theta)];
 feedback=[teach_values(s.log_id),teach_values(s.log_iq)];parkError=max(abs(park-feedback),[],'all');assert(parkError<1e-8,'原Park计算与实际使用角度不符。');
 errorDeg=wrap(used(:,1)-trueAngle)*180/pi;tail=tr>=plan.statistics_window_s(1);
 quantDeg=wrap(angle-trueAngle-c.electrical_zero_deg*pi/180)*180/pi;
 assert(max(abs(quantDeg))<=360*p/N+1e-8,'量化误差超出单计数边界。');
 sourceTime=nan(size(tr));sourceTime(sourceValid)=tr(source(sourceValid));age=tr-sourceTime;
 metric=struct('id',plan.cases(k).id,'sample_count',numel(tr), ...
  'fresh_angle_max_error_rad',freshError,'actual_park_angle_max_error_rad',controlError,'park_inverse_max_error_rad',inverseError, ...
  'park_formula_max_error_A',parkError,'invalid_initial_samples',sum(~sourceValid), ...
  'quantization_max_electrical_deg',max(abs(quantDeg)), ...
  'angle_rms_electrical_deg',sqrt(mean(errorDeg(tail).^2)),'angle_peak_electrical_deg',max(abs(errorDeg(tail))), ...
  'source_age_us',max(age(sourceValid))*1e6,'counts_integer_and_causal',true);
 if k==1,report.cases=metric;else,report.cases(k)=metric;end
 rawActual=nan(size(raw));rawActual(current)=d(fresh,1);assert(all(isfinite(rawActual)),'读取计数记录不完整。');
 series{k}=struct('time',tr,'mechanical',mech,'true_unwrapped_electrical',p*mech, ...
  'control_unwrapped_electrical',p*mech+wrap(used(:,1)-trueAngle),'error_deg',errorDeg,'raw_count',rawActual, ...
  'source_valid',sourceValid,'source_time',sourceTime,'age',age);
 tables{k}=table(repmat(string(plan.cases(k).id),numel(tr),1),tr,mech,rawActual,corrected,trueAngle,used(:,1),used(:,2),source,sourceTime,sourceValid,age*1e6, ...
  'VariableNames',{'case_id','read_time_s','mechanical_truth_rad','raw_count','corrected_count','true_electrical_rad', ...
  'park_electrical_rad','inverse_park_electrical_rad','source_sample_index','source_time_s','source_valid','source_age_us'});
 tables{k}.source_sample_index(~sourceValid)=0;
end
samples=vertcat(tables{:});
end
function x=wrap(x)
x=atan2(sin(x),cos(x));
end
