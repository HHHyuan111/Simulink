function plot_pmsm_timing_events(outputs,plan,folder)
% Short topic titles; actual pulses are markers, raw values are unchanged.
[r,z]=pmsm_timing_events_analysis(outputs,plan);colors=[.12 .40 .72;.89 .34 .11;.14 .57 .36];
origin=z.origin_s;limits=z.window_us;ta=(z.adc_time_s-origin)*1e6;tp=(z.pwm_time_s-origin)*1e6;
f=page([1280 1000]);guard=onCleanup(@()close(f));tiledlayout(4,1,'TileSpacing','compact','Padding','compact');
nexttile;plot(tp,z.pwm(:,1),'Color',colors(1,:));frame('中心对齐计数','CNT',limits);
nexttile;hold on;names={'触发','C采样','B采样','A采样','JEOS'};
for k=1:5,ix=z.adc(:,k+1)>0;plot(ta(ix),k*ones(nnz(ix),1),'o','Color',colors(1,:),'MarkerFaceColor',colors(1,:),'MarkerSize',4);end
eventFrame('ADC事件',names,limits);
nexttile;hold on;names={'电流环','速度环','CCR写入','UEV机会','CCR生效'};
data=[z.adc(:,15) z.adc(:,14) z.pwm(:,4) z.pwm(:,3) z.pwm(:,5)];
for k=1:5,ix=data(:,k)>0;plot(tp(ix),k*ones(nnz(ix),1),'s','Color',colors(2,:),'MarkerFaceColor',colors(2,:),'MarkerSize',4);end
eventFrame('控制与PWM',names,limits);
nexttile;hold on;stairs(tp,z.pwm(:,6),'Color',colors(1,:));stairs(tp,z.pwm(:,7),'Color',colors(2,:));
frame('指令序号','序号',limits);legend('已写入','已生效');sgtitle('控制时序','FontSize',14);savePage(f,folder,'mechanism.png');clear guard;

f=page([1280 900]);guard=onCleanup(@()close(f));tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
for phase=1:3
 nexttile;hold on;plot((z.truth_time_s-origin)*1e6,z.truth_ABC_A(:,phase),'Color',[.3 .33 .37]);
 stairs(ta,z.adc(:,phase+9),'Color',colors(phase,:));frame(sprintf('%c相电流','A'+phase-1),'电流 [A]',limits);legend('真实','采样保持');
end
nexttile;hold on;plot((z.truth_time_s-origin)*1e6,sum(z.truth_ABC_A,2),'Color',[.3 .33 .37]);stairs(ta,z.adc(:,13),'Color',colors(2,:));
frame('三相电流和','电流 [A]',limits);legend('真实','顺序样本');sgtitle('采样电流','FontSize',14);savePage(f,folder,'comparison.png');clear guard;

f=page([1280 900]);guard=onCleanup(@()close(f));tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
names={'转速','q轴电流','d轴电流','转矩'};units={'rpm','A','A','N·m'};
for tile=1:4
 nexttile;hold on;
 for k=1:2
  s=outputs{k};state=teach_values(s.obs_state);
  switch tile
   case 1,y=teach_values(s.log_speed);
   case 2,y=state(:,2);
   case 3,y=state(:,1);
   case 4,y=teach_values(s.log_Te);
  end
  plot(s.log_speed.Time*1000,y,'Color',colors(k,:));
 end
 grid on;title(names{tile});ylabel(units{tile});xlabel('时间 [ms]');xlim([0 plan.duration_s*1000]);legend('简化模式','事件模式');
end
sgtitle('运行状态','FontSize',14);savePage(f,folder,'response.png');
teach_writejson(fullfile(folder,'timing.json'),r);writetable(struct2table(r.events),fullfile(folder,'events.csv'),'Encoding','UTF-8');
end
function f=page(dimensions)
f=figure('Visible','off','Color','white','Position',[40 40 dimensions]);
set(f,'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei','DefaultTextInterpreter','none');
end
function frame(name,unit,limits)
grid on;title(name);ylabel(unit);xlabel('相对时间 [μs]');xlim(limits);
end
function eventFrame(name,labels,limits)
grid on;title(name);yticks(1:numel(labels));yticklabels(labels);ylim([.5 numel(labels)+.5]);xlim(limits);xlabel('相对时间 [μs]');
end
function savePage(f,folder,name)
pmsm_plot_style(f);exportgraphics(f,fullfile(folder,name),'Resolution',140);
end
