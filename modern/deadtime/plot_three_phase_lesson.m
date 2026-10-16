function plot_three_phase_lesson(work,report,deadUs,rpm,loadNm,options)
% Equal axes across cases; use period averages and explicitly label them.
names={'ideal','dead','comp'};labels={'无死区','死区，无补偿','死区，有补偿'};w=cell(1,3);r=cell(1,3);
for k=1:3,s=load(fullfile(work,[names{k} '.mat']),'o');[r{k},w{k}]=deadtime_metrics(s.o);end
colors=[.0 .35 .75;.85 .25 .05;.1 .6 .25];allI=cellfun(@(s)max(abs(s.current_ABC_A),[],'all'),w);lim=max(allI)*1.12;
a=w{1}.current_ABC_A(:,1);cross=find(a(1:end-1)<=0 & a(2:end)>0)+1;
halfWindow=60/(rpm*5)*.065;commonStart=max(cellfun(@(x)x.time_s(1),w));commonEnd=min(cellfun(@(x)x.time_s(end),w));
cross=cross(w{1}.time_s(cross)-halfWindow>=commonStart & w{1}.time_s(cross)+halfWindow<=commonEnd);
assert(~isempty(cross),'Need an interior crossing with complete data on both sides.');center=w{1}.time_s(cross(end));span=[center-halfWindow center+halfWindow]*1e3;
zoomPeak=cellfun(@(x)max(abs(x.current_ABC_A(x.time_s>=center-halfWindow & x.time_s<=center+halfWindow,1))),w);
zoomLim=max(lim*.52,1.05*max(zoomPeak));
f=figure('Visible','off','Position',[30 30 1600 850],'Color','white');tiledlayout(2,3,'TileSpacing','compact');
for k=1:3
 nexttile(k);plot(w{k}.time_s*1e3,w{k}.current_ABC_A,'LineWidth',1.3);colororder(colors);ylim([-lim lim]);xlim([w{1}.time_s(1) w{1}.time_s(end)]*1e3);grid on;
 title(sprintf('%s · THD %.3f%%',labels{k},r{k}.low_order_THD_percent));ylabel('三相电流 [A]');xlabel('时间 [ms]');legend('A','B','C','Location','best');
 nexttile(k+3);plot(w{k}.time_s*1e3,w{k}.current_ABC_A(:,1),'Color',colors(1,:),'LineWidth',1.5);hold on;
 plot(w{1}.time_s*1e3,w{1}.current_ABC_A(:,1),'k--','LineWidth',1);xlim(span);ylim([-zoomLim zoomLim]);grid on;xlabel('时间 [ms]');ylabel('A相过零 [A]');title('相同时间范围与纵轴');legend(labels{k},'无死区参考','Location','best');
end
label=sprintf('三相电流直观对照 · 死区 %.3gμs · %grpm / %.3gN·m · 同一PI · PWM周期平均电流',deadUs,rpm,loadNm);
if nargin>=6,label=[label sprintf('\n补偿时间 %.3gμs；电流滞环 ±%.3gA（运行前参数，与门极死区独立）',options.comp_us,options.hysteresis_A)];end
sgtitle(label);
exportgraphics(f,fullfile(report,'three_phase_comparison.png'),'Resolution',130);close(f);
f=figure('Visible','off','Position',[30 30 1400 950],'Color','white');tiledlayout(3,2,'TileSpacing','compact');styles={'--','-',':'};
for phase=1:3
 nexttile(2*phase-1);hold on;
 for k=1:3,plot(w{k}.time_s*1e3,w{k}.current_ABC_A(:,phase),'LineStyle',styles{k},'LineWidth',1.3);end
 ylim([-lim lim]);grid on;title(sprintf('%c相：三种状态叠加','A'+phase-1));xlabel('时间 [ms]');ylabel('A');legend(labels,'Location','best');
 nexttile(2*phase);hold on;
 for k=2:3
  ref=interp1(w{1}.time_s,w{1}.current_ABC_A(:,phase),w{k}.time_s,'linear','extrap');
  plot(w{k}.time_s*1e3,w{k}.current_ABC_A(:,phase)-ref,'LineWidth',1.2);
 end
 grid on;title('相对无死区参考的电流差');ylabel('差值 [A]');xlabel('时间 [ms]');legend(labels(2:3),'Location','best');
end
sgtitle('每相独立比较 · 电流差包含控制响应与相位变化，不等同于谐波残差');
exportgraphics(f,fullfile(report,'three_phase_difference.png'),'Resolution',130);close(f);
end
