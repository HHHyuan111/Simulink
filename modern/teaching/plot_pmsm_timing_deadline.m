function plot_pmsm_timing_deadline(outputs,plan,folder)
% Raw event markers and sequence steps; explanations belong in prose.
[r,z]=pmsm_timing_deadline_analysis(outputs,plan);colors=[.12 .40 .72;.89 .34 .11;.14 .57 .36];
f=page([1280 1000]);guard=onCleanup(@()close(f));tiledlayout(4,1,'TileSpacing','compact','Padding','compact');
nexttile;plot(z{1}.time_us,z{1}.pwm(:,1),'Color',colors(1,:));frame('中心对齐计数','CNT',z{1}.window_us);
for k=1:3
 nexttile;hold on;v=z{k};data=[v.adc(:,6) v.pwm(:,4) v.pwm(:,3) v.pwm(:,5)];
 for j=1:4,ix=data(:,j)>0;plot(v.time_us(ix),j*ones(nnz(ix),1),'o','Color',colors(k,:),'MarkerFaceColor',colors(k,:),'MarkerSize',5);end
 frame(plan.cases(k).label,'',v.window_us);yticks(1:4);yticklabels({'JEOS','CCR写入','UEV机会','CCR生效'});ylim([.5 4.5]);
end
sgtitle('CCR更新边界','FontSize',14);savePage(f,folder,'mechanism.png');clear guard;
f=page([1280 900]);guard=onCleanup(@()close(f));tiledlayout(3,1,'TileSpacing','compact','Padding','compact');
for k=1:3
 nexttile;hold on;v=z{k};stairs(v.time_us,v.pwm(:,6),'Color',[.35 .37 .4]);stairs(v.time_us,v.pwm(:,7),'Color',colors(k,:));
 frame(plan.cases(k).label,'序号',v.window_us);legend('已写入','已生效');
end
sgtitle('指令序号','FontSize',14);savePage(f,folder,'comparison.png');clear guard;
f=page([1280 900]);guard=onCleanup(@()close(f));tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
names={'转速','q轴电流','d轴电流','转矩'};units={'rpm','A','A','N·m'};
for tile=1:4
 nexttile;hold on;
 for k=1:3
  s=outputs{k};state=teach_values(s.obs_state);
  switch tile
   case 1,y=teach_values(s.log_speed);
   case 2,y=state(:,2);
   case 3,y=state(:,1);
   case 4,y=teach_values(s.log_Te);
  end
  plot(s.log_speed.Time*1000,y,'Color',colors(k,:));
 end
 grid on;title(names{tile});xlabel('时间 [ms]');ylabel(units{tile});xlim([0 plan.duration_s*1000]);legend({plan.cases.label});
end
sgtitle('运行状态','FontSize',14);savePage(f,folder,'response.png');
teach_writejson(fullfile(folder,'deadline.json'),r);writetable(struct2table(r.events),fullfile(folder,'events.csv'),'Encoding','UTF-8');
end
function f=page(dim)
f=figure('Visible','off','Color','white','Position',[40 40 dim]);
set(f,'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei','DefaultTextInterpreter','none');
end
function frame(name,unit,lim)
grid on;title(name);ylabel(unit);xlabel('相对时间 [μs]');xlim(lim);
end
function savePage(f,folder,name)
pmsm_plot_style(f);exportgraphics(f,fullfile(folder,name),'Resolution',140);
end
