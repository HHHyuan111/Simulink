function plot_pmsm_mechanism(outputs,plan,folder)
% Extra mechanism page for batch two; plots retained raw records, no smoothing.
s=outputs{2};r=outputs{1};t=s.log_iabc_meas.Time;window=plan.plot_window_s;
f=figure('Visible','off','Color','white','Position',[40 40 1350 920]);guard=onCleanup(@()close(f));
set(f,'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei', ...
 'DefaultAxesFontSize',10,'DefaultTextInterpreter','none');
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
c=[.12 .40 .72;.89 .34 .11;.14 .57 .36];
switch plan.scenario.id
 case 'digital_filter'
  input=teach_values(s.log_iabc_adc);output=teach_values(s.log_iabc_filter);
  nexttile;hold on;stairs(t*1000,input(:,1),'Color',c(1,:));stairs(t*1000,output(:,1),'Color',c(2,:));
  frame('A相电流','A',window*1000);legend('滤波前','滤波后');
  nexttile;hold on;err=output-input;
  for k=1:3,stairs(t*1000,err(:,k),'Color',c(k,:));end
  frame('滤波改变量','A',window*1000);legend('A','B','C');
  dt=median(diff(t));alpha=exp(-2*pi*plan.value*dt);hz=logspace(0,log10(.5/dt),700);
  H=(1-alpha)./(1-alpha*exp(-1i*2*pi*hz*dt));
  nexttile;semilogx(hz,20*log10(abs(H)),'Color',c(1,:),'LineWidth',1.4);grid on;
  title('幅频响应');xlabel('频率 [Hz]');ylabel('幅值 [dB]');xlim([1 .5/dt]);
  nexttile;semilogx(hz,angle(H)*180/pi,'Color',c(2,:),'LineWidth',1.4);grid on;
  title('相频响应');xlabel('频率 [Hz]');ylabel('相位 [°]');xlim([1 .5/dt]);
 case 'angle_bias'
  nexttile;hold on;plot(t*1000,teach_values(s.log_theta_true)*180/pi,'Color',c(1,:));
  plot(t*1000,teach_values(s.log_theta_meas)*180/pi,'Color',c(2,:));
  frame('电角度','电角度 [°]',window*1000);legend('真实','反馈');
  nexttile;plot(t*1000,teach_values(s.log_theta_error)*180/pi,'Color',c(2,:));
  frame('角度误差','电角度 [°]',window*1000);
  margin=max(.2,.1*abs(plan.value));ylim([plan.value-margin plan.value+margin]);
  states=teach_values(s.obs_state);
  nexttile;hold on;plot(t*1000,states(:,1),'Color',c(1,:));plot(t*1000,teach_values(s.log_id),'Color',c(2,:));
  plot(t*1000,teach_values(s.obs_id_ref),'k--');frame('d轴电流','A',window*1000);legend('真实','反馈','给定');
  nexttile;hold on;plot(t*1000,states(:,2),'Color',c(1,:));plot(t*1000,teach_values(s.log_iq),'Color',c(2,:));
  plot(t*1000,teach_values(s.log_iq_ref),'k--');frame('q轴电流','A',window*1000);legend('真实','反馈','给定');
 case {'gate_deadtime','gate_deadtime_pair'}
  tg=s.obs_dead_gates.Time;requested=teach_values(s.obs_dead_requested);actual=teach_values(s.obs_dead_gates);
  assert(isequal(tg,s.obs_dead_requested.Time));origin=max(tg(1),tg(end)-100e-6);relative=(tg-origin)*1e6;edgeWindow=[0 (tg(end)-origin)*1e6];
  for k=1:2
   nexttile;hold on;stairs(relative,requested(:,k),'--','Color',c(1,:),'LineWidth',1.2);
   stairs(relative,actual(:,k),'Color',c(2,:),'LineWidth',1.2);grid on;xlim(edgeWindow);ylim([-.15 1.2]);
   labels={'A相上管','A相下管'};title(labels{k});xlabel('相对时间 [μs]');ylabel('门极逻辑');legend('请求','实际');
  end
  nexttile;stairs(relative,1-actual(:,1)-actual(:,2),'Color',c(2,:),'LineWidth',1.2);grid on;xlim(edgeWindow);ylim([-.15 1.2]);
  title('A相空白区间');xlabel('相对时间 [μs]');ylabel('空白标志');
  nexttile;hold on;
  if strcmp(plan.scenario.id,'gate_deadtime_pair')
   aligned=pmsm_deadtime_pair_alignment(outputs,plan);
   for k=1:2,plot(aligned(k).angle_deg,aligned(k).current_ABC_A(:,1),'Color',c(k,:));end
   grid on;xlim([0 360]);xticks(0:60:360);title('A相电流');xlabel('电角度 [°]');ylabel('电流 [A]');legend('零死区','死区');
  else
   a=teach_values(r.obs_current_fast);b=teach_values(s.obs_current_fast);
   plot(r.obs_current_fast.Time*1000,a(:,1),'Color',c(1,:));plot(s.obs_current_fast.Time*1000,b(:,1),'Color',c(2,:));
   frame('A相电流','A',window*1000);legend('参考','实验');
  end
 otherwise,error('不支持的机制页。');
end
sgtitle(plan.scenario.name,'Interpreter','none','FontSize',14);
pmsm_plot_style(f);
exportgraphics(f,fullfile(folder,'mechanism.png'),'Resolution',140);
end
function frame(name,unit,limits)
grid on;title(name);xlabel('时间 [ms]');ylabel(unit);xlim(limits);
end
