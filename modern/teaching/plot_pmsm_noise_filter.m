function plot_pmsm_noise_filter(outputs,plan,folder)
% Three raw-data pages: currents, physical response, and filter mechanism.
[analysis,trace]=pmsm_noise_filter_analysis(outputs,plan);c=[.12 .40 .72;.89 .34 .11;.14 .57 .36];labels={plan.cases.label};
window=plan.plot_window_s;t=trace.time_s;states=cellfun(@(s)teach_values(s.obs_state),outputs,'UniformOutput',false);
f=page([1450 1050]);guard=onCleanup(@()close(f));tiledlayout(3,3,'TileSpacing','compact','Padding','compact');
for phase=1:3
 values=[];
 for k=1:3
  s=outputs{k};fast=teach_values(s.obs_current_fast);measured=teach_values(s.log_iabc_meas);
  values=[values;fast(s.obs_current_fast.Time>=window(1)&s.obs_current_fast.Time<=window(2),phase); ...
   measured(t>=window(1)&t<=window(2),phase)]; %#ok<AGROW>
 end
 pad=max(.03,(max(values)-min(values))*.08);limits=[min(values)-pad max(values)+pad];
 for k=1:3
  s=outputs{k};fast=teach_values(s.obs_current_fast);measured=teach_values(s.log_iabc_meas);nexttile;hold on;
  plot(s.obs_current_fast.Time*1000,fast(:,phase),'Color',[.30 .33 .37],'LineWidth',.65);
  stairs(t*1000,measured(:,phase),'Color',c(k,:),'LineWidth',.9);
  frame(sprintf('%s · %c相',labels{k},'A'+phase-1),'电流 [A]',window*1000);ylim(limits);
  if phase==1,legend('真实','反馈');end
 end
end
sgtitle('噪声与滤波','FontSize',14);savePage(f,folder,'comparison.png');clear guard;

f=page([1280 900]);guard=onCleanup(@()close(f));tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
nexttile;hold on;for k=1:3,plot(t*1000,states{k}(:,1),'Color',c(k,:));end
plot(t*1000,teach_values(outputs{1}.obs_id_ref),'k--');frame('d轴电流','A',plan.statistics_window_s*1000);legend([labels {'给定'}]);
nexttile;hold on;for k=1:3,plot(t*1000,states{k}(:,2),'Color',c(k,:));end
plot(t*1000,teach_values(outputs{3}.log_iq_ref),'k--');frame('q轴电流','A',plan.statistics_window_s*1000);legend([labels {'滤波组给定'}]);
nexttile;hold on;for k=1:3,plot(t*1000,teach_values(outputs{k}.log_Te),'Color',c(k,:));end
plot(t*1000,teach_values(outputs{1}.log_TL),'k--');frame('转矩','N·m',plan.statistics_window_s*1000);legend([labels {'负载'}]);
nexttile;hold on;for k=1:3,plot(t*1000,teach_values(outputs{k}.log_speed),'Color',c(k,:));end
plot(t*1000,teach_values(outputs{1}.log_nref),'k--');frame('转速','rpm',plan.statistics_window_s*1000);legend([labels {'给定'}]);
sgtitle('闭环响应','FontSize',14);savePage(f,folder,'response.png');clear guard;

f=page([1280 900]);guard=onCleanup(@()close(f));tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
nexttile;hold on;stairs(t*1000,trace.injected{3}(:,1),'Color',c(2,:));stairs(t*1000,trace.noise_component{3}(:,1),'Color',c(3,:));
frame('A相噪声分量','A',window*1000);legend('注入','滤后分量');
nexttile;hold on;for k=1:3,stairs(t*1000,trace.measurement_error{3}(:,k),'Color',c(k,:));end
frame('测量总误差','A',window*1000);legend('A','B','C');
nexttile;hold on;plot(t*1000,states{3}(:,1),'Color',c(1,:));plot(t*1000,teach_values(outputs{3}.log_id),'Color',c(3,:));
plot(t*1000,teach_values(outputs{3}.obs_id_ref),'k--');frame('d轴真值与反馈','A',window*1000);legend('真实','反馈','给定');
hz=logspace(0,log10(.5/analysis.control_period_s),700);H=(1-analysis.alpha)./(1-analysis.alpha*exp(-1i*2*pi*hz*analysis.control_period_s));
nexttile;yyaxis left;semilogx(hz,20*log10(abs(H)),'Color',c(1,:));ylabel('幅值 [dB]');
yyaxis right;semilogx(hz,angle(H)*180/pi,'Color',c(2,:));ylabel('相位 [°]');grid on;title('滤波响应');xlabel('频率 [Hz]');xlim([1 .5/analysis.control_period_s]);legend('幅值','相位');
sgtitle('滤波观测','FontSize',14);savePage(f,folder,'mechanism.png');
teach_writejson(fullfile(folder,'analysis.json'),analysis);
end
function f=page(dimensions)
f=figure('Visible','off','Color','white','Position',[40 40 dimensions]);
set(f,'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei','DefaultTextInterpreter','none');
end
function frame(name,unit,limits)
grid on;title(name);xlabel('时间 [ms]');ylabel(unit);xlim(limits);
end
function savePage(f,folder,name)
pmsm_plot_style(f);exportgraphics(f,fullfile(folder,name),'Resolution',140);
end
