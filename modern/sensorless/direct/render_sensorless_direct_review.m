function render_sensorless_direct_review
% Publication graphics from the completed raw run; no model load or sim call.
base=sensorless_direct_setup;folder=fullfile(base,'runs','SMO_direct_first');
r=jsondecode(fileread(fullfile(folder,'report.json')));
accepted=jsondecode(fileread(fullfile(base,'milestones','SMO_direct','summary.json')));assert(accepted.passed);
raw=fullfile(folder,'signals.mat');assert(strcmp(teach_hash(raw),r.raw_sha256));
s=load(raw,'obs_sless_v2_theta','obs_sless_v2_truth_theta','obs_sless_v2_speed','obs_sless_v2_truth_speed','obs_sless_direct_completed');
t=s.obs_sless_v2_theta.Time;theta=teach_values(s.obs_sless_v2_theta);truth=teach_values(s.obs_sless_v2_truth_theta);
speed=teach_values(s.obs_sless_v2_speed);actual=teach_values(s.obs_sless_v2_truth_speed);
angle=atan2(sin(theta-truth),cos(theta-truth))*180/pi;delta=speed-actual;
steady=t>=.162&t<=.25;pub=teach_values(s.obs_sless_direct_completed);
firstPermit=find(pub(:,14)>.5,1);lockedMs=s.obs_sless_direct_completed.Time(firstPermit)*1000;
output=fullfile(base,'milestones','SMO_direct');font='Microsoft YaHei';
blue=[.12 .36 .85];teal=[.00 .54 .48];ink=[.10 .16 .26];muted=[.37 .43 .53];bg=[.956 .967 .984];

fig=figure('Visible','off','Position',[80 80 1560 1100],'Color',bg,'InvertHardcopy','off');
cleanup=onCleanup(@()close(fig)); %#ok<NASGU>
canvas;
label([.055 .925 .70 .052],'SMO + PLL  /  本地模型观测结果',27,ink,'bold');
label([.057 .887 .88 .035],'3000 rpm · 仿真时长 0.25 s · ADC / 滤波 / 死区 / 计算延迟工程配置',12,muted,'normal');
badge([.774 .935 .17 .033],'旁路观测 · 未接管 FOC');
card([.055 .773 .285 .095],'稳态电角度 RMS','0.077°',blue);
card([.358 .773 .285 .095],'稳态转速 RMS 误差','0.044%',teal);
card([.661 .773 .285 .095],'独立运行与结果一致性','2 / 2  通过',ink);

ax=panel([.075 .470 .390 .235],'01  转速跟踪 / 完整启动');
plot(ax,t*1000,actual,'Color',ink,'LineWidth',2.1,'DisplayName','电机实际');hold(ax,'on');
plot(ax,t*1000,speed,'Color',blue,'LineWidth',1.25,'LineStyle','--','DisplayName','SMO 估计');
plot(ax,[lockedMs lockedMs],[-150 3350],':','Color',teal,'LineWidth',1.1,'HandleVisibility','off');
text(ax,lockedMs+4,700,sprintf('首次发布许可\n%.1f ms',lockedMs),'FontName',font,'FontSize',10,'Color',teal);
xlim(ax,[0 250]);ylim(ax,[-150 3350]);xticks(ax,0:50:250);ylabel(ax,'转速 / rpm');xlabel(ax,'时间 / ms');
leg=legend(ax,'Location','southeast','Box','off');leg.FontName=font;leg.FontSize=11;

ax=panel([.555 .470 .390 .235],'02  电角度误差 / 完整启动');
plot(ax,t*1000,angle,'Color',blue,'LineWidth',1.15);xlim(ax,[0 250]);ylim(ax,[-105 15]);xticks(ax,0:50:250);
ylabel(ax,'电角度误差 / °');xlabel(ax,'时间 / ms');
text(ax,85,-78,'启动失锁、超调均保留','FontName',font,'FontSize',11,'Color',muted);

ax=panel([.075 .125 .390 .235],'03  稳态角度纹波 / 未平滑');
plot(ax,t(steady)*1000,angle(steady),'Color',blue,'LineWidth',1.1);xlim(ax,[162 250]);ylim(ax,[-.125 .005]);
xticks(ax,[162 180 200 220 240 250]);ylabel(ax,'电角度误差 / °');xlabel(ax,'时间 / ms');
text(ax,165,-.012,'峰值 0.107°','FontName',font,'FontSize',11,'Color',blue);

ax=panel([.555 .125 .390 .235],'04  稳态转速误差 / 未平滑');
plot(ax,t(steady)*1000,delta(steady),'Color',teal,'LineWidth',1.0);xlim(ax,[162 250]);
lim=max(2,ceil(max(abs(delta(steady)))));ylim(ax,[-lim lim]);xticks(ax,[162 180 200 220 240 250]);
ylabel(ax,'估计 − 实际 / rpm');xlabel(ax,'时间 / ms');
text(ax,165,.76*lim,sprintf('RMS %.3f rpm',sqrt(mean(delta(steady).^2))),'FontName',font,'FontSize',11,'Color',teal);
label([.055 .027 .90 .034],'稳态评价：162–250 ms，21.99 个电周期  |  新运行原始数据，未平滑  |  FOC 仍使用电机真实角度',11,muted,'normal');
exportgraphics(fig,fullfile(output,'review_overview.png'),'Resolution',180,'BackgroundColor',bg);
exportgraphics(fig,fullfile(output,'review_overview.pdf'),'ContentType','vector','BackgroundColor',bg);
clear cleanup

fig=figure('Visible','off','Position',[80 80 1500 820],'Color',bg,'InvertHardcopy','off');
cleanup=onCleanup(@()close(fig)); %#ok<NASGU>
canvas;
label([.06 .900 .75 .065],'稳态跟踪细节  /  SMO 与电机实际值',25,ink,'bold');
label([.062 .852 .85 .038],'角度以 sin(电角度) 展示，避免 0° / 360° 跳变；原始角度误差未作校正',12,muted,'normal');
badge([.77 .929 .18 .039],'旁路观测 · 未接管 FOC');
use=t>=.210&t<=.218;
ax=panel([.085 .500 .370 .270],'电角度跟踪 / 两个电周期');
plot(ax,t(use)*1000,sin(truth(use)),'Color',ink,'LineWidth',2,'DisplayName','电机实际');hold(ax,'on');
plot(ax,t(use)*1000,sin(theta(use)),'Color',blue,'LineStyle','--','LineWidth',1.3,'DisplayName','SMO 估计');
xlim(ax,[210 218]);ylim(ax,[-1.15 1.15]);ylabel(ax,'sin(电角度)');xlabel(ax,'时间 / ms');
leg=legend(ax,'Location','southwest','Box','off');leg.FontName=font;
ax=panel([.565 .500 .370 .270],'同一区间的真实电角度误差');
plot(ax,t(use)*1000,angle(use),'Color',blue,'LineWidth',1.3);xlim(ax,[210 218]);ylim(ax,[-.125 .005]);
ylabel(ax,'电角度误差 / °');xlabel(ax,'时间 / ms');
use=t>=.200&t<=.220;
ax=panel([.085 .120 .370 .250],'转速跟踪 / 稳态局部');
plot(ax,t(use)*1000,actual(use),'Color',ink,'LineWidth',2,'DisplayName','电机实际');hold(ax,'on');
plot(ax,t(use)*1000,speed(use),'Color',teal,'LineWidth',1,'DisplayName','SMO 估计');
xlim(ax,[200 220]);ylabel(ax,'转速 / rpm');xlabel(ax,'时间 / ms');
leg=legend(ax,'Location','southwest','Box','off');leg.FontName=font;
ax=panel([.565 .120 .370 .250],'同一区间的转速误差');
plot(ax,t(use)*1000,delta(use),'Color',teal,'LineWidth',1);xlim(ax,[200 220]);ylabel(ax,'估计 − 实际 / rpm');xlabel(ax,'时间 / ms');
label([.060 .025 .89 .033],'两次独立运行：89 路日志一致  |  原控制对照：52 路回归通过  |  当前为观测验证，尚未完成无感闭环',11,muted,'normal');
exportgraphics(fig,fullfile(output,'review_detail.png'),'Resolution',180,'BackgroundColor',bg);
exportgraphics(fig,fullfile(output,'review_detail.pdf'),'ContentType','vector','BackgroundColor',bg);
writetable(table(t,actual,speed,angle,delta,'VariableNames',{'reference_time_s','plant_speed_rpm','estimated_speed_rpm','angle_error_deg','speed_error_rpm'}),fullfile(output,'review_data.csv'));
proof=struct('simulation_started',false,'model_loaded',false,'historical_data',false,...
 'raw_sha256',r.raw_sha256,'model_sha256',r.model_sha256,'data_samples',numel(t),...
 'steady_window_s',[.162 .25],'feedback_source','true motor angle','sensorless_closed_loop',false,...
 'first_permit_publication_s',lockedMs/1000,'renderer_sha256',teach_hash([mfilename('fullpath') '.m']),...
 'data_csv_sha256',teach_hash(fullfile(output,'review_data.csv')),...
 'overview_sha256',teach_hash(fullfile(output,'review_overview.png')),'detail_sha256',teach_hash(fullfile(output,'review_detail.png')));
teach_writejson(fullfile(output,'review_source.json'),proof);

 function ax=panel(position,titleText)
  ax=axes(fig,'Position',position,'FontName',font,'FontSize',11,'Color','white',...
   'XColor',muted,'YColor',muted,'Box','off','LineWidth',.7,'TickDir','out',...
   'GridColor',[.78 .81 .87],'GridAlpha',.42,'Layer','top');
  hold(ax,'on');grid(ax,'on');title(ax,titleText,'FontName',font,'FontSize',14,'FontWeight','bold','Color',ink);
 end
 function canvas
  % Keep the full canvas in tight exports, including header/footer margins.
  annotation(fig,'rectangle',[.001 .001 .998 .998],'FaceColor','none','EdgeColor',bg,'LineWidth',.1);
 end
 function label(position,value,size,color,weight)
  annotation(fig,'textbox',position,'String',value,'FontName',font,'FontSize',size,...
   'Color',color,'FontWeight',weight,'EdgeColor','none','Margin',0,'Interpreter','none');
 end
 function badge(position,value)
  annotation(fig,'rectangle',position,'FaceColor',[1 .94 .82],'EdgeColor','none');
  annotation(fig,'textbox',position,'String',value,'FontName',font,'FontSize',11,...
   'Color',[.54 .34 .06],'EdgeColor','none','HorizontalAlignment','center','VerticalAlignment','middle','Margin',0);
 end
 function card(position,titleText,value,color)
  annotation(fig,'rectangle',position,'FaceColor','white','EdgeColor',[.87 .90 .94],'LineWidth',.8);
  label(position+[.015 .053 -.025 -.055],titleText,11,muted,'normal');
  label(position+[.015 .006 -.025 -.040],value,25,color,'bold');
 end
end
