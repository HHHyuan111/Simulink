function plot_pmsm_sampling_window(outputs,plan,folder)
% Clean raw-current, guarded-aperture and physical-response pages.
[r,z,samples]=pmsm_sampling_window_analysis(outputs,plan);colors=[.12 .40 .72;.89 .34 .11;.14 .57 .36];
f=page([1500 1100]);guard=onCleanup(@()close(f));tiledlayout(3,3,'TileSpacing','compact','Padding','compact');
limits=plan.plot_window_s*1000;
for phase=1:3
 allValues=[];
 for k=1:3
  v=z{k};keep=v.sample_time_s>=plan.plot_window_s(1)&v.sample_time_s<=plan.plot_window_s(2);
  allValues=[allValues;v.truth_plot_ABC_A(:,phase);v.delivered(keep,phase)]; %#ok<AGROW>
 end
 span=max(allValues)-min(allValues);margin=max(.1,.06*span);yl=[min(allValues)-margin max(allValues)+margin];
 for k=1:3
  nexttile;hold on;v=z{k};hTruth=plot(v.truth_plot_time_s*1000,v.truth_plot_ABC_A(:,phase),'Color',[.43 .45 .48],'LineWidth',.65);
  hFeedback=stairs(v.sample_time_s*1000,v.delivered(:,phase),'Color',colors(k,:),'LineWidth',1);
  bad=~v.valid(:,phase)&v.sample_time_s>=plan.plot_window_s(1)&v.sample_time_s<=plan.plot_window_s(2);
  hInvalid=plot(v.sample_time_s(bad)*1000,v.delivered(bad,phase),'x','Color',[.78 .18 .16],'MarkerSize',3);
  xlim(limits);ylim(yl);grid on;ylabel(sprintf('%c相 [A]','A'+phase-1));
  if phase==1,title(plan.cases(k).label);end
  if phase==3,xlabel('时间 [ms]');end
  if phase==1&&k==1,legend([hTruth hFeedback hInvalid],{'物理真值','反馈电流','窗口无效标志'});end
 end
end
sgtitle('三相电流','FontSize',14);savePage(f,folder,'comparison.png');clear guard;

f=page([1500 1050]);guard=onCleanup(@()close(f));tiledlayout(3,3,'TileSpacing','compact','Padding','compact');
for phase=1:3
 for k=1:3
  nexttile;hold on;v=z{k};ok=r.example.valid_ABC_by_case(k,phase);shade=[.2 .65 .4];label='孔径有效';
  if ~ok,shade=[.85 .25 .2];label='孔径无效';end
  x=r.example.sample_start_ABC_us(phase);y=r.example.sample_end_ABC_us(phase);
  band=patch([x y y x],[-.1 -.1 1.1 1.1],shade,'FaceAlpha',.18,'EdgeColor','none');
  stairs(v.gate_time_us,v.gate_history(:,2*phase),'Color',[.25 .28 .32],'LineWidth',1);
  text(42,.84,label,'HorizontalAlignment','right','Color',shade*.72,'BackgroundColor','white','Margin',1,'FontSize',8);
  xlim([0 plan.comparison_contract.pwm_period_s*1e6]);ylim([-.1 1.1]);yticks([0 1]);grid on;
  ylabel(sprintf('%c相门极','A'+phase-1));if phase==1,title(plan.cases(k).label);end
  if phase==3,xlabel('相对时间 [μs]');end
 end
end
sgtitle('采样窗口','FontSize',14);savePage(f,folder,'mechanism.png');clear guard;

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
 grid on;title(names{tile});xlabel('时间 [ms]');ylabel(units{tile});xlim([0 plan.duration_s*1000]);
 if tile==1,legend({plan.cases.label});end
end
sgtitle('运行状态','FontSize',14);savePage(f,folder,'response.png');
teach_writejson(fullfile(folder,'window.json'),r);writetable(samples,fullfile(folder,'samples.csv'),'Encoding','UTF-8');
end
function f=page(dim)
f=figure('Visible','off','Color','white','Position',[40 40 dim]);
set(f,'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei','DefaultTextInterpreter','none');
end
function savePage(f,folder,name)
pmsm_plot_style(f);exportgraphics(f,fullfile(folder,name),'Resolution',140);
end
