function plot_pmsm_encoder(outputs,plan,folder)
[report,v,samples]=pmsm_encoder_analysis(outputs,plan);colors=[.12 .40 .72;.89 .34 .11;.14 .57 .36];
f=page([1400 850]);g=onCleanup(@()close(f));tiledlayout(2,3,'TileSpacing','compact','Padding','compact');
for row=1:2
 for k=1:3
  nexttile;hold on;z=v{k};
  if row==1
   plot(z.time*1000,z.true_unwrapped_electrical*180/pi,'Color',[.4 .42 .45]);stairs(z.time*1000,z.control_unwrapped_electrical*180/pi,'Color',colors(k,:));
   xlim([plan.duration_s-.001 plan.duration_s]*1000);title(plan.cases(k).label);ylabel('电角度 [°]');
   if k==1,legend('真实','控制器');end
  else
   plot(z.time*1000,z.error_deg,'Color',colors(k,:));xlim(plan.plot_window_s*1000);ylabel('电角误差 [°]');
  end
  grid on;xlabel('时间 [ms]');
 end
end
sgtitle('编码器角度');savePage(f,folder,'mechanism.png');clear g;
f=page([1400 850]);g=onCleanup(@()close(f));tiledlayout(2,3,'TileSpacing','compact','Padding','compact');
for row=1:2
 for k=1:3
  nexttile;hold on;s=outputs{k};state=teach_values(s.obs_state);t=s.log_id.Time*1000;
  trueValue=state(:,row);feed=teach_values(s.log_id);reference=teach_values(s.obs_id_ref);name='d轴';
  if row==2,feed=teach_values(s.log_iq);reference=teach_values(s.log_iq_ref);name='q轴';end
  plot(t,trueValue,'Color',[.4 .42 .45]);plot(t,feed,'Color',colors(k,:));plot(t,reference,'k--');
  xlim(plan.plot_window_s*1000);grid on;ylabel([name ' [A]']);xlabel('时间 [ms]');
  if row==1,title(plan.cases(k).label);end
  if row==1&&k==1,legend('真实','反馈','给定');end
 end
end
sgtitle('dq电流');savePage(f,folder,'comparison.png');clear g;
f=page([1200 850]);g=onCleanup(@()close(f));tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
names={'转速','转矩','d轴电流','q轴电流'};units={'rpm','N·m','A','A'};
for j=1:4
 nexttile;hold on;
 for k=1:3
  s=outputs{k};state=teach_values(s.obs_state);
  switch j
   case 1,y=teach_values(s.log_speed);
   case 2,y=teach_values(s.log_Te);
   case 3,y=state(:,1);
   case 4,y=state(:,2);
  end
  plot(s.log_speed.Time*1000,y,'Color',colors(k,:));
 end
 title(names{j});ylabel(units{j});xlabel('时间 [ms]');xlim([0 plan.duration_s*1000]);grid on;
 if j==1,legend({plan.cases.label});end
end
sgtitle('运行状态');savePage(f,folder,'response.png');
teach_writejson(fullfile(folder,'encoder.json'),report);writetable(samples,fullfile(folder,'encoder_samples.csv'),'Encoding','UTF-8');
end
function f=page(dim)
f=figure('Visible','off','Color','white','Position',[40 40 dim]);set(f,'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei','DefaultTextInterpreter','none');
end
function savePage(f,folder,name)
pmsm_plot_style(f);exportgraphics(f,fullfile(folder,name),'Resolution',140);
end
