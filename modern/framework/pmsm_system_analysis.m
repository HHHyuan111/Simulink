function report=pmsm_system_analysis(outputs,p)
% Check the joint chain from counts through actual transform/PI/PWM inputs.
assert(strcmp(p.kind,'integrated_system_baseline_v1')&&numel(outputs)==2);
c=p.comparison_contract;N=p.value(1);dt=c.read_period_s;h=c.event_step_s;
ix=strcmp({p.baseline_state.workspace_values.name},'p');assert(sum(ix)==1);
c.pole_pairs=p.baseline_state.workspace_values(ix).value;
a=1/(1+2*pi*p.value(3)*dt);b=1-a;
report=struct('kind',p.kind,'contract',c,'input_schedule',p.input_schedule,'cases',struct([]));
for k=1:2
 s=outputs{k};t=s.log_speed.Time;truth=v(s,'log_speed');mech=v(s,'log_encoder_mechanical');enc=v(s,'log_encoder');used=v(s,'log_encoder_control');
 assert(max(abs(diff(t)-dt))<1e-12&&abs(t(1)-c.read_offset_s)<1e-12);
 for name={'log_encoder','log_encoder_mechanical','log_encoder_control','log_speed_window','log_speed_filter','obs_state','log_iabc_meas','obs_adc_timing'}
  assert(isequal(s.(name{1}).Time,t),'时间轴不符：%s',name{1});
 end
 raw=mod(floor(mech*(-N/(2*pi))),N);count=mod(-raw,N);
 assert(isequal(enc(:,1),raw)&&isequal(enc(:,2),count)&&all(enc(:,9)==(k==2))&&all(enc(:,10)==0));
 theta=mod(mech*c.pole_pairs,2*pi);qtheta=mod(count*(2*pi/N)*c.pole_pairs,2*pi);
 expected=theta;if k==2,expected=qtheta;end
 ae=max(abs(wrap(used(:,1)-expected)));assert(ae<1e-9&&max(abs(wrap(used(:,2)-used(:,1))))<1e-12);
 assert(max(abs(wrap(qtheta-theta)))<=2*pi*c.pole_pairs/N+1e-9);
 abc=v(s,'log_iabc_meas');alpha=(2*abc(:,1)-abc(:,2)-abc(:,3))/3;beta=(abc(:,2)-abc(:,3))/sqrt(3);
 park=[alpha.*cos(used(:,1))+beta.*sin(used(:,1)),-alpha.*sin(used(:,1))+beta.*cos(used(:,1))];
 pe=max(abs(park-[v(s,'log_id') v(s,'log_iq')]),[],'all');assert(pe<1e-8,'实际Park没有使用预定角度。');
 logs={'log_speed_short','log_speed_window','log_speed_long'};
 for j=1:3
  len=c.window_ticks(j);d=v(s,logs{j});ix=(len+1:numel(t))';delta=count(ix)-count(ix-len);delta=delta-N*floor((delta+N/2)/N);
  valid=false(size(t));valid(ix)=abs(delta)<N/2;target=zeros(size(t));target(ix(valid(ix)))=delta(valid(ix))*60/(N*len*dt);
  assert(isequal(d(:,2)>.5,valid)&&max(abs(d(:,1)-target))<1e-9);
  assert(isequal(d(ix,7),count(ix-len))&&max(abs(d(ix,4)-len*dt))<1e-12);
  assert(max(abs(d(ix,5)-t(ix-len)))<1e-12&&max(abs(d(:,6)-t))<1e-12);
  assert(all(abs(mech(ix)-mech(ix-len))<pi-1e-9),'差分超过半圈有效域。');
 end
 rawSpeed=v(s,'log_speed_window');f=v(s,'log_speed_filter');state=0;y=zeros(size(t));
 for j=1:numel(t),state=b*rawSpeed(j,1)+a*state;y(j)=state;end
 effective=rawSpeed(:,1);if k==2,effective=y;effective(rawSpeed(:,2)<.5)=0;end
 fe=max(abs(f(:,2)-y));assert(fe<1e-9&&max(abs(f(:,3)-effective))<1e-9);
 assert(isequal(f(:,1),rawSpeed(:,1))&&isequal(f(:,4),rawSpeed(:,2))&&all(f(:,5)==(k==2)));
 assert(max(abs(f(:,6)-a))<1e-14&&max(abs(f(:,7)-b))<1e-14);
 tc=s.log_speed_control.Time;piInput=v(s,'log_speed_control');d=v(s,'log_speed_feedback');
 [found,at]=ismember(round(tc/h),round(t/h));assert(all(found)&&at(1)==2&&all(diff(at)==2));
 assert(max(abs(diff(tc)-c.speed_period_s))<1e-12&&isequal(tc,s.log_speed_feedback.Time));
 expected=truth(at);if k==2,expected=effective(at);end
 se=max(abs(piInput-expected));assert(se<1e-9&&max(abs(piInput-d(:,6)))<1e-9);
 assert(all(d(:,3)==(k==2))&&all(d(:,4)==2)&&isequal(d(:,1),rawSpeed(at,1))&&isequal(d(:,2),rawSpeed(at,2)));
 % Read the real speed-task boundary instead of assuming an instantaneous step.
 schedule=p.input_schedule;speedEdge=tc(find(tc>=schedule.speed_step_s,1));
 nref=schedule.speed_before_rpm*ones(size(t));nref(t>=speedEdge-1e-12)=schedule.speed_after_rpm;
 nref(t<tc(1)-1e-12)=0; % Phased Step has not executed before the first speed hit.
 loadEdge=t(find(t>=schedule.load_step_s,1));loadRef=schedule.load_before_Nm*ones(size(t));loadRef(t>=loadEdge-1e-12)=schedule.load_after_Nm;
 assert(max(abs(v(s,'log_nref')-nref))<1e-12&&max(abs(v(s,'log_TL')-loadRef))<1e-12);
 iqRef=v(s,'log_iq_ref');voltage=v(s,'obs_voltage');assert(max(abs(iqRef))<=p.acceptance.iq_command_max_A+1e-9);
 assert(max(voltage(:,7))<=1+1e-9&&all(voltage(:,5)>=0));
 % Independent CCR oracle from complete request history and recorded active seq.
 pwm=v(s,'obs_pwm_timing');tp=s.obs_pwm_timing.Time;applied=v(s,'log_Tcm_applied');ta=s.log_Tcm_applied.Time;
 requests=v(s,'log_Tcm_requested');tr=s.log_Tcm_requested.Time;
 assert(max(abs(diff(tp)-h))<1e-12&&isequal(round(tp/h),round(ta/h))&&max(abs(tp-ta))<1e-12);
 pwmTimeDifference=max(abs(tp-ta)); % Same native grid ticks; no interpolation.
 seq=round(pwm(:,7));assert(all(seq>0)&&max(seq)<=size(requests,1));
 assert(abs(tr(1)-c.read_offset_s)<1e-12&&max(abs(diff(tr)-dt))<1e-12);
 threshold=dt/2*(1-floor(max(0,min(1,1-2*requests(seq,:)/dt))*4000+1e-9)/4000);
 ce=max(abs(applied-threshold),[],'all');assert(ce<1e-15,'CCR实际输出与请求来源不符。');
 state=v(s,'obs_state');stages=struct([]);
 for j=1:size(p.stage_windows_s,1)
  span=p.stage_windows_s(j,:);ix=t>=span(1)&t<span(2);assert(sum(ix)>10);
  error=truth(ix)-nref(ix);fit=polyfit(t(ix)-mean(t(ix)),truth(ix),1);
  m=struct('name',p.stage_names{j},'window_s',span,'speed_mean_rpm',mean(truth(ix)),...
   'speed_error_mean_rpm',mean(error),'speed_error_rms_rpm',sqrt(mean(error.^2)),...
   'speed_span_rpm',max(truth(ix))-min(truth(ix)),'speed_slope_rpm_per_s',fit(1),...
   'true_id_rms_A',sqrt(mean(state(ix,1).^2)),'true_iq_tracking_rms_A',sqrt(mean((state(ix,2)-iqRef(ix)).^2)),...
   'torque_mean_Nm',mean(vat(s,'log_Te',ix)),'torque_std_Nm',std(vat(s,'log_Te',ix)));
  m.platform_pass=abs(m.speed_error_mean_rpm)<=p.acceptance.speed_error_mean_abs_max_rpm&&...
   m.speed_span_rpm<=p.acceptance.speed_span_max_rpm&&abs(m.speed_slope_rpm_per_s)<=p.acceptance.platform_abs_slope_max_rpm_per_s;
  if j==1,stages=m;else,stages(j)=m;end
 end
 report.cases(k).id=p.cases(k).id;report.cases(k).label=p.cases(k).label;
 report.cases(k).checks=struct('angle_max_error_rad',ae,'park_max_error_A',pe,'filter_max_error_rpm',fe,...
  'actual_pi_input_max_error_rpm',se,'actual_ccr_max_error_s',ce,'all_three_speed_windows_checked',true,...
  'speed_step_actual_s',speedEdge,'load_step_actual_s',loadEdge,'fast_samples',numel(t),'speed_samples',numel(tc),...
  'pwm_log_time_max_difference_s',pwmTimeDifference,'pwm_matched_by_native_grid_ticks',true);
 report.cases(k).stages=stages;report.cases(k).platforms_pass=all([stages.platform_pass]);
 report.cases(k).peak_true_iq_A=max(abs(state(:,2)));report.cases(k).peak_iq_command_A=max(abs(iqRef));
 report.cases(k).final_speed_rpm=truth(end);
end
report.interface_checks_passed=true;report.all_platforms_pass=all([report.cases.platforms_pass]);
report.boundaries={'Known electrical zero; no alignment/startup gating/active protection.',...
 'Angle and speed feedback change together; this is system integration, not single-factor attribution.',...
 'Nominal motor and unmeasured timing assumptions; not calibrated hardware accuracy.',...
 'High-rate gate and PWM diagnostics retain only the tail; not a full-run gate-edge audit.'};
end
function x=v(s,name),x=teach_values(s.(name));end
function x=vat(s,name,ix),x=v(s,name);x=x(ix,:);end
function x=wrap(x),x=atan2(sin(x),cos(x));end
