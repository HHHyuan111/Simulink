function plot_deadtime_report(work,report,deadUs,rpm,loadNm,options)
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);addpath(fullfile(root,'teaching'));
if nargin<1,work=fullfile(root,'.build','deadtime_stage');end
if nargin<2,report=fullfile(folder,'report_deadtime');end
if nargin<3,deadUs=.5;end
if nargin<4,rpm=600;end
if nargin<5,loadNm=.207;end
if ~isfolder(report),mkdir(report);end
names={'ideal','dead','comp'};labels={'理想：死区0',sprintf('死区%gμs，无补偿',deadUs),sprintf('死区%gμs，有补偿',deadUs)};metrics=struct;waves=cell(1,3);
if nargin>=6,labels{3}=sprintf('死区%gμs，补偿%gμs，滞环±%gA',deadUs,options.comp_us,options.hysteresis_A);end
for k=1:3,saved=load(fullfile(work,[names{k} '.mat']),'o');[metrics.(names{k}),waves{k}]=deadtime_metrics(saved.o);end
f=figure('Visible','off','Position',[40 40 1500 1050],'Color','white');tiledlayout(3,2,'TileSpacing','compact');colors=lines(3);
for panel=1:5
 nexttile(panel);hold on;
 for k=1:3
  w=waves{k};t=w.time_s*1e3;
  switch panel
   case 1,y=w.current_ABC_A(:,1);label='A相电流：PWM周期平均';unit='A';
   case 2,y=w.phase_A_residual_A;label='A相非基波残差：同一角度谐波拟合';unit='A';
   case 3,t=w.control_time_s*1e3;y=w.id_iq_A(:,1);label='真实d轴电流';unit='A';
   case 4,t=w.control_time_s*1e3;y=w.id_iq_A(:,2);label='真实q轴电流';unit='A';
   case 5,y=w.torque_Nm;label='电磁转矩：PWM周期平均';unit='N·m';
  end
  plot(t,y,'Color',colors(k,:),'LineWidth',1);
 end
 title(label);ylabel(unit);xlabel('时间 [ms]');grid on;legend(labels,'Location','best');
end
nexttile(6);values=cellfun(@(n)metrics.(n).low_order_THD_percent,names);bar(values,'FaceColor','flat');xticks(1:3);xticklabels({'理想','死区','补偿'});ylabel('2—25次 THD [%]');grid on;
title('低次电流畸变：末两个电周期，排除开关频带');
for k=1:3,text(k,values(k),sprintf(' %.3f%%',values(k)),'HorizontalAlignment','center','VerticalAlignment','bottom');end
sgtitle(sprintf('死区及补偿 · %grpm / %.3gN·m · 相同PI与稳态初值 · 未作板级校准',rpm,loadNm));
exportgraphics(f,fullfile(report,'deadtime_comparison.png'),'Resolution',150);close(f);

f=figure('Visible','off','Position',[40 40 1300 700],'Color','white');tiledlayout(2,1,'TileSpacing','compact');
nexttile;hold on;
for k=1:3,stem(2:13,waves{k}.harmonic_amplitudes_A(2:13)/waves{k}.harmonic_amplitudes_A(1)*100,'Color',colors(k,:),'LineWidth',1,'Marker','o');end
grid on;xticks(2:13);ylabel('相对基波 [%]');xlabel('电角度谐波次数');legend(labels,'Location','best');title('A相低次谐波：基于真实电角度拟合');
nexttile;values=[metrics.dead.id_rms_A metrics.comp.id_rms_A;metrics.dead.iq_ac_rms_A metrics.comp.iq_ac_rms_A];bar(values);xticklabels({'id RMS','iq交流RMS'});ylabel('A');legend('死区无补偿','有补偿','Location','best');grid on;title('真实dq电流指标：相同分析窗口');
sgtitle('只评价本轮稳态演示工况；不包含整段启动FFT或开关频率THD');exportgraphics(f,fullfile(report,'deadtime_harmonics.png'),'Resolution',150);close(f);

saved=load(fullfile(work,'dead.mat'),'o');o=saved.o;t=o.obs_dead_gates.Time;g=teach_values(o.obs_dead_gates);
rise=find(diff(g(:,1))>0)+1;rise=rise(rise>40 & rise<numel(t)-40);assert(~isempty(rise));center=t(rise(end));zoom=max(2e-6,deadUs*1.5e-6);keep=t>=center-zoom & t<=center+zoom;
bridge=teach_values(o.obs_dead_bridge);tb=o.obs_dead_bridge.Time;kb=tb>=center-zoom & tb<=center+zoom;
f=figure('Visible','off','Position',[40 40 1300 900],'Color','white');tiledlayout(3,1,'TileSpacing','compact');
nexttile;stairs((t(keep)-center)*1e6,g(keep,1:2),'LineWidth',1.6);ylim([-.1 1.1]);grid on;legend('A上管','A下管','Location','best');ylabel('门极');title(sprintf('实际门极：上管导通前有%gμs两管关断区间',deadUs));
nexttile;stairs((t(keep)-center)*1e6,1-sum(g(keep,1:2),2),'LineWidth',1.6);ylim([-.1 1.1]);grid on;ylabel('两管关断=1');title('死区空白：下降沿立即关断，上升沿延后');
nexttile;yyaxis left;stairs((tb(kb)-center)*1e6,bridge(kb,4),'LineWidth',1.5);ylabel('A极点电压 [V]');yyaxis right;stairs((tb(kb)-center)*1e6,bridge(kb,1),'LineWidth',1.2);ylabel('二极管通道');yticks([-1 0 1]);grid on;xlabel('相对上管导通时间 [μs]');title('续流标志：-1下管二极管 / +1上管二极管 / 0无二极管通道');
sgtitle(sprintf('%gμs门极死区与续流局部 · 62.5ns事件网格 · Ron/Vf关闭',deadUs));exportgraphics(f,fullfile(report,'deadtime_gates.png'),'Resolution',150);close(f);
teach_writejson(fullfile(report,'metrics.json'),metrics);fprintf('DEADTIME_REPORT_READY %s\n',report);
end
