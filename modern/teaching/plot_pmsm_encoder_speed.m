function plot_pmsm_encoder_speed(outputs,plan,folder)
[report,v,samples]=pmsm_encoder_speed_analysis(outputs,plan);s=outputs{1};colors=[.12 .40 .72;.89 .34 .11;.14 .57 .36];labels=cellfun(@(z)z.label,v,'UniformOutput',false);
f=page([1400 850]);g=onCleanup(@()close(f));tiledlayout(2,3,'TileSpacing','compact','Padding','compact');
for row=1:2
 for k=1:3
  nexttile;hold on;z=v{k};y=z.speed;y(~z.valid)=NaN;
  if row==1
   plot(z.time*1000,z.truth,'Color',[.45 .47 .5]);plot(z.time*1000,z.window_truth,'k--');stairs(z.time*1000,y,'Color',colors(k,:));
   title(labels{k});ylabel('转速 [rpm]');xlim([plan.duration_s-.002 plan.duration_s]*1000);
   if k==1,legend('瞬时真值','窗口真值','计数测速');end
  else
   y=z.total_error;y(~z.valid)=NaN;plot(z.time*1000,y,'Color',colors(k,:));yline(0,'k--');ylabel('测速误差 [rpm]');xlim(plan.plot_window_s*1000);
  end
  xlabel('时间 [ms]');grid on;
 end
end
sgtitle('计数测速');savePage(f,folder,'comparison.png');clear g;
f=page([1200 850]);g=onCleanup(@()close(f));tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
nexttile;stairs(v{1}.time*1000,v{1}.count,'Color',colors(1,:));xlim([plan.duration_s-.001 plan.duration_s]*1000);title('机械计数');ylabel('计数');xlabel('时间 [ms]');grid on;
for j=1:3
 nexttile;hold on;
 for k=1:3
  z=v{k};switch j
   case 1,y=z.quantization_error;
   case 2,y=z.window_error;
   case 3,y=double(z.valid);
  end
  if j<3,y(~z.valid)=NaN;plot(z.time*1000,y,'Color',colors(k,:));else,stairs(z.time*1000,y,'Color',colors(k,:));end
 end
 if j==1,title('计数量化误差');ylabel('rpm');legend(labels);
 elseif j==2,title('窗口平均误差');ylabel('rpm');
 else,title('窗口有效');ylabel('有效标志');ylim([-.1 1.1]);end
 if j<3,xlim(plan.plot_window_s*1000);else,xlim([0 1.8]);end
 xlabel('时间 [ms]');grid on;
end
sgtitle('差分窗口');savePage(f,folder,'mechanism.png');clear g;
f=page([1200 850]);g=onCleanup(@()close(f));tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
nexttile;hold on;plot(s.log_speed.Time*1000,teach_values(s.log_speed),'k');
for k=1:3,z=v{k};y=z.speed;y(~z.valid)=NaN;plot(z.time*1000,y,'Color',colors(k,:));end
title('转速');ylabel('rpm');xlabel('时间 [ms]');grid on;legend([{'真实'} labels]);xlim([0 plan.duration_s*1000]);
nexttile;plot(s.log_speed.Time*1000,teach_values(s.log_speed),'Color',[.45 .47 .5]);hold on;stairs(s.log_speed_control.Time*1000,teach_values(s.log_speed_control),'Color',colors(1,:));
title('速度环输入');ylabel('rpm');xlabel('时间 [ms]');grid on;legend('真实','实际输入');xlim([plan.duration_s-.001 plan.duration_s]*1000);
nexttile;plot(s.log_Te.Time*1000,teach_values(s.log_Te),'Color',colors(1,:));title('转矩');ylabel('N·m');xlabel('时间 [ms]');grid on;
nexttile;state=teach_values(s.obs_state);plot(s.log_id.Time*1000,state(:,1),'Color',[.45 .47 .5]);hold on;plot(s.log_id.Time*1000,teach_values(s.log_id),'Color',colors(1,:));
title('d轴电流');ylabel('A');xlabel('时间 [ms]');grid on;legend('真实','反馈');
sgtitle('运行状态');savePage(f,folder,'response.png');
teach_writejson(fullfile(folder,'speed.json'),report);writetable(samples,fullfile(folder,'speed_samples.csv'),'Encoding','UTF-8');
end
function f=page(dim)
f=figure('Visible','off','Color','white','Position',[40 40 dim]);set(f,'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei','DefaultTextInterpreter','none');
end
function savePage(f,folder,name)
pmsm_plot_style(f);exportgraphics(f,fullfile(folder,name),'Resolution',140);
end
