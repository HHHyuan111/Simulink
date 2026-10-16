function plot_pmsm_speed_feedback(outputs,plan,folder)
[report,v,samples]=pmsm_speed_feedback_analysis(outputs,plan);colors=[.12 .4 .72;.89 .34 .11;.14 .57 .36];labels={plan.cases.label};
f=page;g=onCleanup(@()close(f));tiledlayout(2,3,'TileSpacing','compact','Padding','compact');
for row=1:2
 for k=1:3
  nexttile;hold on;s=outputs{k};z=v{k};
  if row==1,plot(z.time*1000,z.truth,'Color',[.45 .47 .5]);stairs(z.time*1000,z.input,'Color',colors(k,:));ylabel('转速 [rpm]');title(labels{k});if k==1,legend('真实','PI输入');end
  else,stairs(s.log_iq_ref.Time*1000,teach_values(s.log_iq_ref),'Color',colors(k,:));ylabel('iq给定 [A]');end
  xlim(plan.plot_window_s*1000);xlabel('时间 [ms]');grid on;
 end
end
sgtitle('测速反馈');savePage(f,folder,'comparison.png');clear g;
f=page;g=onCleanup(@()close(f));tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
for j=1:4
 nexttile;hold on;
 for k=1:3
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
f=page;g=onCleanup(@()close(f));tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
for j=1:4
 nexttile;hold on;
 for k=1:3
  z=v{k};switch j
   case 1,y=z.input;
   case 2,y=double(z.valid);
   case 3,y=z.error;
   case 4,y=repmat(plan.comparison_contract.feedback_on(k),size(z.time));
  end
  stairs(z.time*1000,y,'Color',colors(k,:));
 end
 names={'启动反馈','候选有效','反馈误差','计数反馈开关'};units={'rpm','有效标志','rpm','开关'};title(names{j});ylabel(units{j});xlabel('时间 [ms]');grid on;
 if j==1,legend(labels);end
 if j<=2,xlim([0 1]);else,xlim(plan.plot_window_s*1000);end
 if ismember(j,[2 4]),ylim([-.1 1.1]);end
end
sgtitle('反馈来源');savePage(f,folder,'mechanism.png');
teach_writejson(fullfile(folder,'feedback.json'),report);writetable(samples,fullfile(folder,'feedback_samples.csv'),'Encoding','UTF-8');
end
function f=page
f=figure('Visible','off','Color','white','Position',[40 40 1400 850]);set(f,'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei','DefaultTextInterpreter','none');
end
function savePage(f,folder,name)
pmsm_plot_style(f);exportgraphics(f,fullfile(folder,name),'Resolution',140);
end
