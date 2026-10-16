function report=analyse_pmsm_power_integration(outputs,p)
% Integration checks on actual logged interfaces, with no steady-state claim.
assert(numel(outputs)==3&&strcmp(p.kind,'power_feedback_integration_v1'));
dt=p.baseline_state.workspace_values(strcmp({p.baseline_state.workspace_values.name},'dt')).value;
N=p.value(1);W=p.value(2);a=1/(1+2*pi*p.value(3)*dt);
report=struct('kind',p.kind,'duration_s',p.duration_s,'cases',struct([]));
for k=1:3
 s=outputs{k};t=s.log_speed.Time;h=62.5e-9;
 for name=fieldnames(s)',assert(all(isfinite(teach_values(s.(name{1}))),'all'));end
 assert(max(abs(diff(t)-dt))<1e-12);
 enc=v(s,'log_encoder');used=v(s,'log_encoder_control');
 assert(all(enc(:,9)==1)&&all(enc(:,10)==0));
 pole=p.baseline_state.workspace_values(strcmp({p.baseline_state.workspace_values.name},'p')).value;
 expected=mod(enc(:,2)*(2*pi/N)*pole,2*pi);
 angleError=max(abs(atan2(sin(used(:,1)-expected),cos(used(:,1)-expected))));assert(angleError<1e-9);
 abc=v(s,'log_iabc_meas');alpha=(2*abc(:,1)-abc(:,2)-abc(:,3))/3;beta=(abc(:,2)-abc(:,3))/sqrt(3);
 park=[alpha.*cos(used(:,1))+beta.*sin(used(:,1)),-alpha.*sin(used(:,1))+beta.*cos(used(:,1))];
 parkError=max(abs(park-[v(s,'log_id') v(s,'log_iq')]),[],'all');assert(parkError<1e-8);
 raw=v(s,'log_speed_window');ix=(W+1:numel(t))';d=enc(ix,2)-enc(ix-W,2);d=d-N*floor((d+N/2)/N);
 assert(max(abs(raw(ix,1)-d*60/(N*W*dt)))<1e-8);
 f=v(s,'log_speed_filter');state=0;y=zeros(size(t));
 for j=1:numel(t),state=(1-a)*raw(j,1)+a*state;y(j)=state;end
 assert(all(f(:,5)==1)&&max(abs(f(:,2)-y))<1e-8);
 y(raw(:,2)<.5)=0;assert(max(abs(f(:,3)-y))<1e-8);
 tc=s.log_speed_control.Time;[ok,at]=ismember(round(tc/h),round(t/h));assert(all(ok));
 speedError=max(abs(v(s,'log_speed_control')-y(at)));assert(speedError<1e-8);
 pwm=v(s,'obs_pwm_timing');applied=v(s,'log_Tcm_applied');requests=v(s,'log_Tcm_requested');
 assert(isequal(round(s.obs_pwm_timing.Time/h),round(s.log_Tcm_applied.Time/h)));
 seq=round(pwm(:,7));assert(all(seq>0)&all(seq<=size(requests,1)));
 threshold=dt/2*(1-floor(max(0,min(1,1-2*requests(seq,:)/dt))*4000+1e-9)/4000);
 ccrError=max(abs(applied-threshold),[],'all');assert(ccrError<1e-15);
 g=v(s,'obs_dead_gates');r=v(s,'obs_dead_requested');tg=s.obs_dead_gates.Time;
 assert(isequal(round(tg/h),round(s.obs_dead_requested.Time/h)));
 assert(all(g(:,1:2:5)+g(:,2:2:6)<=1,'all'));
 % Test complete rising-edge neighbourhoods only; tails cannot prove full-run safety.
 checked=0;delay=round(p.comparison_contract.deadtime_us(k)*1e-6/h);
 assert(max(abs(diff(tg)-h))<1e-12);
 for j=1:6
  edges=find(diff(r(:,j))>.5)+1;
  for e=edges(:)'
   finish=e+delay;if finish>size(r,1),continue;end
   if any(r(e:finish,j)<.5),continue;end
   if delay>0,assert(all(g(e:finish-1,j)==0));end
   assert(g(finish,j)==1);checked=checked+1;
  end
 end
 assert(checked>0);
 if k==1,assert(isequal(g,r));end
 iq=v(s,'log_iq_ref');assert(max(abs(iq))<=8+1e-9);
 voltage=v(s,'obs_voltage');assert(max(voltage(:,7))<=1+1e-9);
 last=t>=p.statistics_window_s(1)&t<p.statistics_window_s(2);
 truth=v(s,'obs_state');comp=v(s,'obs_dead_comp');
 if k<3,assert(all(comp==0,'all'));end
 item=struct('id',p.cases(k).id,'label',p.cases(k).label,...
  'angle_error_rad',angleError,'park_error_A',parkError,'actual_speed_pi_error_rpm',speedError,...
  'actual_ccr_error_s',ccrError,'checked_gate_edges_in_tail',checked,...
  'final_speed_rpm',vlast(s,'log_speed'),'peak_iq_command_A',max(abs(iq)),...
  'true_id_rms_A',sqrt(mean(truth(last,1).^2)),...
  'iq_tracking_rms_A',sqrt(mean((truth(last,2)-iq(last)).^2)),...
  'compensation_peak',max(abs(comp),[],'all'));
 if k==1,report.cases=item;else,report.cases(k)=item;end
end
report.interface_checks_passed=true;
report.boundaries={'Short startup integration; no platform or steady-state acceptance.',...
 'Gate checks cover retained tail only, not all-run startup/shutdown protection.',...
 'Same detailed bridge, encoder angle, window speed, filter, real ADC/PWM timing.',...
 'Measurement errors, device drops and sampling-window rejection remain disabled.',...
 'No assertion that compensation must improve this transient.'};
end
function x=v(s,name),x=teach_values(s.(name));end
function x=vlast(s,name),d=v(s,name);x=d(end,:);end
