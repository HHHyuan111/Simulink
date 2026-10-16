function [r,w]=deadtime_metrics(o)
Ts=50e-6;p=5;v=@teach_values;
fast=o.obs_current_fast;t=fast.Time;i=v(fast);te=v(o.obs_torque_fast);tf=o.obs_torque_fast.Time;
group=floor(t/Ts+1e-8)+1;count=accumarray(group,1);full=count>=round(Ts/1e-6);full(end)=false;
tm=accumarray(group,t)./count;im=zeros(numel(count),3);
for k=1:3,im(:,k)=accumarray(group,i(:,k))./count;end
torque=accumarray(floor(tf/Ts+1e-8)+1,te)./accumarray(floor(tf/Ts+1e-8)+1,1);
state=v(o.obs_state);theta=interp1(o.obs_state.Time,p*state(:,4),tm,'linear','extrap');
endAngle=theta(find(full,1,'last'));keep=full & theta>=endAngle-4*pi & tm>=.02;
assert(nnz(keep)>500&&max(theta(keep))-min(theta(keep))>3.9*pi,'Need two settled electrical cycles.');
angle=theta(keep);X=ones(nnz(keep),51);
for k=1:25,X(:,2*k)=cos(k*angle);X(:,2*k+1)=sin(k*angle);end
coef=X\im(keep,1);amp=hypot(coef(2:2:end),coef(3:2:end));fundamental=X(:,1:3)*coef(1:3);
assert(amp(1)>1);thd=norm(amp(2:end))/amp(1)*100;
tk=o.obs_state.Time;sk=tk>=tm(find(keep,1));s=state(sk,:);speed=30/pi*s(:,3);g=v(o.obs_dead_gates);
assert(all(g(:,1:2:5)+g(:,2:2:6)<=1,'all'));
curr=v(o.obs_current_fast);r=struct('low_order_THD_percent',thd,'harmonic_orders',[2 25], ...
 'phase_fundamental_peak_A',amp(1),'id_rms_A',sqrt(mean(s(:,1).^2)), ...
 'iq_ac_rms_A',std(s(:,2),1),'torque_period_average_pp_Nm',max(torque(keep))-min(torque(keep)), ...
 'torque_period_average_ac_rms_Nm',std(torque(keep),1),'speed_mean_rpm',mean(speed), ...
 'speed_pp_rpm',max(speed)-min(speed),'phase_current_peak_A',max(abs(curr),[],'all'), ...
 'analysis_start_s',tm(find(keep,1)),'analysis_end_s',tm(find(keep,1,'last')));
w=struct('time_s',tm(keep),'current_ABC_A',im(keep,:),'phase_A_residual_A',im(keep,1)-fundamental, ...
 'torque_Nm',torque(keep),'harmonic_amplitudes_A',amp,'control_time_s',tk(sk),'id_iq_A',s(:,1:2));
end
