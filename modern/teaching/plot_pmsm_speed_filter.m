function plot_pmsm_speed_filter(outputs,plan,folder)
[report,v,samples]=pmsm_speed_filter_analysis(outputs,plan);colors=[.12 .4 .72;.89 .34 .11];labels={plan.cases.label};
f=page;g=onCleanup(@()close(f));tiledlayout(2,2,'TileSpacing','compact','Padding','compact');axesList=gobjects(2,2);ranges=cell(2,1);
for row=1:2
 for k=1:2
  ax=nexttile;axesList(row,k)=ax;hold on;s=outputs{k};z=v{k};
  if row==1
   plot(z.time*1000,z.truth,'Color',[.45 .47 .5]);stairs(z.time*1000,z.raw,'Color',[.65 .78 .9]);stairs(z.pi.time*1000,z.pi.input,'Color',colors(k,:));title(labels{k});ylabel('转速 [rpm]');
   if k==1,legend('真实','原始测速','PI输入');end
   keep=z.time>=plan.plot_window_s(1);ranges{row}=[ranges{row};z.truth(keep);z.raw(keep);z.effective(keep)];
  else
   y=teach_values(s.log_iq_ref);stairs(s.log_iq_ref.Time*1000,y,'Color',colors(k,:));ylabel('iq给定 [A]');ranges{row}=[ranges{row};y(s.log_iq_ref.Time>=plan.plot_window_s(1))];
  end
  xlim(plan.plot_window_s*1000);xlabel('时间 [ms]');grid on;
 end
end
for row=1:2,lim=boundsWithMargin(ranges{row});set(axesList(row,:),'YLim',lim);end
sgtitle('速度滤波');savePage(f,folder,'comparison.png');clear g;
f=page;g=onCleanup(@()close(f));tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
for j=1:4
 nexttile;hold on;
 for k=1:2
  s=outputs{k};switch j
   case 1,x=s.log_speed.Time;y=teach_values(s.log_speed);
   case 2,x=s.log_iq_ref.Time;y=teach_values(s.log_iq_ref);
   case 3,x=s.log_Te.Time;y=teach_values(s.log_Te);
   case 4,x=s.obs_state.Time;a=teach_values(s.obs_state);y=a(:,2);
  end
  plot(x*1000,y,'Color',colors(k,:));
 end
 names={'转速','iq给定','转矩','真实q轴电流'};units={'rpm','A','N·m','A'};title(names{j});ylabel(units{j});xlabel('时间 [ms]');grid on;
 if j==1,legend(labels);xlim([0 plan.duration_s]*1000);else,xlim(plan.plot_window_s*1000);end
end
sgtitle('闭环响应');savePage(f,folder,'response.png');clear g;
f=page;g=onCleanup(@()close(f));tiledlayout(2,2,'TileSpacing','compact','Padding','compact');z=v{2};
nexttile;hold on;stairs(z.time*1000,z.raw,'Color',[.12 .4 .72]);plot(z.time*1000,z.filtered_state,'Color',colors(2,:));plot(z.time*1000,z.truth,'Color',[.45 .47 .5]);
title('测速与滤波');ylabel('rpm');xlabel('时间 [ms]');legend('原始','滤后','真实');xlim(plan.plot_window_s*1000);grid on;
nexttile;plot(z.time*1000,z.quantization_raw,'Color',colors(1,:));hold on;plot(z.time*1000,z.quantization_contribution,'Color',colors(2,:));
title('量化贡献');ylabel('rpm');xlabel('时间 [ms]');legend('滤前','滤后');xlim(plan.plot_window_s*1000);grid on;
nexttile;plot(z.time*1000,z.filter_dynamic,'Color',colors(2,:));hold on;plot(z.time*1000,z.window_error,'Color',colors(1,:));plot(z.time*1000,z.total_error,'Color',[.3 .3 .3]);
title('误差分量');ylabel('rpm');xlabel('时间 [ms]');legend('滤波动态','窗口平均','总误差');xlim(plan.statistics_window_s*1000);grid on;
nexttile;stairs(z.time*1000,z.raw,'Color',colors(1,:));hold on;plot(z.time*1000,z.effective,'Color',colors(2,:));
title('启动滤波');ylabel('rpm');xlabel('时间 [ms]');legend('原始','发布');xlim([0 3]);grid on;
sgtitle('平滑与滞后');savePage(f,folder,'mechanism.png');
teach_writejson(fullfile(folder,'speed_filter.json'),report);writetable(samples,fullfile(folder,'filter_samples.csv'),'Encoding','UTF-8');
end
function lim=boundsWithMargin(y)
lo=min(y);hi=max(y);pad=max((hi-lo)*.06,max(abs([lo hi]))*.005+1e-6);lim=[lo-pad hi+pad];
end
function f=page
f=figure('Visible','off','Color','white','Position',[40 40 1300 850]);set(f,'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei','DefaultTextInterpreter','none');
end
function savePage(f,folder,name)
pmsm_plot_style(f);exportgraphics(f,fullfile(folder,name),'Resolution',140);
end
