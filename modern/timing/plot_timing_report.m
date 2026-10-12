function plot_timing_report
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);addpath(fullfile(root,'teaching'));
work=fullfile(root,'.build','timing_stage');report=fullfile(folder,'report_timing');if ~isfolder(report),mkdir(report);end
r=load(fullfile(work,'real.mat'),'o');o=r.o;a=teach_values(o.obs_adc_timing);p=teach_values(o.obs_pwm_timing);ta=o.obs_adc_timing.Time;tp=o.obs_pwm_timing.Time;
% A single cycle is placed near the end of the short run; pulse events are
% plotted as markers so a 62.5 ns pulse remains visible at teaching scale.
start=floor((ta(end)-150e-6)/50e-6)*50e-6;sel=ta>=start & ta<=start+100e-6;sp=tp>=start & tp<=start+100e-6;
f=figure('Visible','off','Position',[50 50 1400 1050],'Color','white');tiledlayout(4,1,'TileSpacing','compact');
nexttile;plot((tp(sp)-start)*1e6,p(sp,1),'LineWidth',1.2);ylabel('CNT');title('中心对齐计数与事件：触发相位24.375μs为待实测假设');grid on;xlim([0 100]);
nexttile;hold on;labels={'触发','C保持','B保持','A保持','JEOS'};
for k=1:5,tt=ta(sel & a(:,k+1)>0);plot((tt-start)*1e6,k*ones(size(tt)),'o','MarkerFaceColor',[.1 .4 .8]);end
yticks(1:5);yticklabels(labels);ylim([.5 5.5]);xlim([0 100]);grid on;title('ADC：孔径结束采样，整组完成后执行电流环');
nexttile;hold on;labels={'UEV机会','CCR写入','新CCR生效'};
for k=1:3,tt=tp(sp & p(:,k+2)>0);plot((tt-start)*1e6,k*ones(size(tt)),'s','MarkerFaceColor',[.8 .3 .1]);end
yticks(1:3);yticklabels(labels);ylim([.5 3.5]);xlim([0 100]);grid on;title('CCR：先计算，再写入预装载，等待更新边界');
nexttile;stairs((tp(sp)-start)*1e6,p(sp,6:7),'LineWidth',1.2);grid on;xlim([0 100]);xlabel('相对时间 [μs]');ylabel('指令序号');legend('已写入','已生效','Location','best');
sgtitle('AxDr 时序教学 · 原PI参数 · 计算耗时5μs为演示值');exportgraphics(f,fullfile(report,'timing_events.png'),'Resolution',150);close(f);
f=figure('Visible','off','Position',[50 50 1400 1050],'Color','white');tiledlayout(3,2,'TileSpacing','compact');names={'off','real','window','window_hold'};labels={'理想基线','真实时序','低侧窗口','无效保持策略'};
colors=lines(4);
for k=1:4
 q=load(fullfile(work,[names{k} '.mat']),'o');q=q.o;t=q.log_speed.Time;meas=teach_values(q.log_iabc_meas);truth=teach_values(q.log_iabc_true);
 nexttile(1);hold on;plot(t*1e3,teach_values(q.log_speed),'Color',colors(k,:));
 nexttile(2);hold on;plot(t*1e3,teach_values(q.log_iq),'Color',colors(k,:));
 nexttile(3);hold on;plot(t*1e3,meas(:,1)-truth(:,1),'Color',colors(k,:));
 nexttile(4);hold on;plot(t*1e3,sum(meas,2),'Color',colors(k,:));
 if k==3
  x=teach_values(q.obs_adc_timing);tt=q.obs_adc_timing.Time;jeos=x(:,6)>0;
  nexttile(5);stairs(tt(jeos)*1e3,x(jeos,7:9),'LineWidth',1);ylim([-.1 1.1]);title('窗口有效标志（A/B/C）');ylabel('有效=1');legend('A','B','C','Location','best');
  nexttile(6);stairs(q.obs_adc_codes.Time*1e3,teach_values(q.obs_adc_codes));title('标称12位ADC码（A/B/C）');ylabel('码值');legend('A','B','C','Location','best');
 end
end
titles={'启动转速（20ms局部）','q轴反馈电流','A相测量误差','三相测量电流之和'};units={'rpm','A','A','A'};
for k=1:6,nexttile(k);grid on;xlabel('时间 [ms]');if k<=4,title(titles{k});ylabel(units{k});legend(labels,'Location','best');end,end
sgtitle('单因素对照 · 全部沿用原PI · 无效置零/保持是策略演示');exportgraphics(f,fullfile(report,'sampling_comparison.png'),'Resolution',150);close(f);
f=figure('Visible','off','Position',[50 50 1400 1000],'Color','white');tiledlayout(2,2,'TileSpacing','compact');
names={'stress_reference','stress_window','stress_hold'};labels={'只改触发相位','再开启窗口','再开启无效保持'};
windowProbe=load(fullfile(work,'stress_window.mat'),'o');wa=teach_values(windowProbe.o.obs_adc_timing);wj=wa(:,6)>0;[~,badPhase]=min(mean(wa(wj,7:9),1));phaseNames={'A','B','C'};clear windowProbe;
for k=1:3
 q=load(fullfile(work,[names{k} '.mat']),'o');q=q.o;t=q.log_speed.Time;meas=teach_values(q.log_iabc_meas);truth=teach_values(q.log_iabc_true);
 nexttile(1);hold on;plot(t*1e3,teach_values(q.log_iq),'Color',colors(k,:));
 nexttile(2);hold on;plot(t*1e3,meas(:,badPhase)-truth(:,badPhase),'Color',colors(k,:));
 nexttile(3);hold on;plot(t*1e3,sum(meas,2),'Color',colors(k,:));
 if k==2,a=teach_values(q.obs_adc_timing);jeos=a(:,6)>0;nexttile(4);stairs(q.obs_adc_timing.Time(jeos)*1e3,a(jeos,7:9));ylim([-.1 1.1]);legend('A','B','C','Location','best');title('窗口有效标志');end
end
titles={'q轴反馈',[phaseNames{badPhase} '相测量误差（失效最多相）'],'采样三相电流之和'};
for k=1:4,nexttile(k);grid on;xlabel('时间 [ms]');if k<=3,title(titles{k});ylabel('A');legend(labels,'Location','best');end,end
sgtitle('故意后移触发至31.25μs · 三组相位一致 · 教学压力工况，非固件预设');exportgraphics(f,fullfile(report,'window_stress.png'),'Resolution',150);close(f);
end
