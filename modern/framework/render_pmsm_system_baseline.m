function report=render_pmsm_system_baseline(folder)
here=fileparts(mfilename('fullpath'));addpath(fullfile(fileparts(here),'teaching'));
p=jsondecode(fileread(fullfile(folder,'plan.json')));outputs=cell(1,2);
for k=1:2,x=load(fullfile(folder,[p.cases(k).id '.mat']),'signals');outputs{k}=x.signals;end
report=pmsm_system_analysis(outputs,p);teach_writejson(fullfile(folder,'analysis.json'),report);
rows=cell(6,10);r=0;
for k=1:2,for j=1:3,r=r+1;m=report.cases(k).stages(j);rows(r,:)={p.cases(k).id,m.name,m.window_s(1),m.window_s(2),m.speed_error_mean_rpm,m.speed_span_rpm,m.speed_slope_rpm_per_s,m.true_id_rms_A,m.true_iq_tracking_rms_A,m.platform_pass};end,end
writetable(cell2table(rows,'VariableNames',{'case_id','stage','from_s','to_s','speed_mean_error_rpm','speed_span_rpm','speed_slope_rpm_per_s','id_rms_A','iq_tracking_rms_A','platform_pass'}),fullfile(folder,'metrics.csv'),'Encoding','UTF-8');
colors=[.15 .4 .75;.9 .35 .15];labels={p.cases.label};
f=figure('Visible','off','Color','white','Position',[100 100 1200 760]);g=onCleanup(@()close(f));tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
nexttile;hold on;for k=1:2,s=outputs{k};plot(s.log_speed.Time*1e3,v(s,'log_speed'),'Color',colors(k,:));end
s=outputs{1};plot(s.log_nref.Time*1e3,v(s,'log_nref'),'k--');title('转速');ylabel('rpm');legend([labels {'给定'}],'Location','best');finish;
nexttile;hold on;for k=1:2,s=outputs{k};plot(s.log_Te.Time*1e3,v(s,'log_Te'),'Color',colors(k,:));end
plot(s.log_TL.Time*1e3,v(s,'log_TL'),'k--');title('转矩');ylabel('N·m');legend([labels {'负载'}],'Location','best');finish;
for k=1:2,nexttile;s=outputs{k};state=v(s,'obs_state');plot(s.obs_state.Time*1e3,state(:,2));hold on;plot(s.log_iq_ref.Time*1e3,v(s,'log_iq_ref'),'k--');title(labels{k});ylabel('iq [A]');legend('真实','给定','Location','best');finish;end
sgtitle('整机响应');exportgraphics(f,fullfile(folder,'response.png'),'Resolution',130);clear g;
f=figure('Visible','off','Color','white','Position',[100 100 1200 760]);g=onCleanup(@()close(f));tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
nexttile;hold on;for k=1:2,s=outputs{k};theta=v(s,'log_encoder_control');mech=v(s,'log_encoder_mechanical');e=atan2(sin(theta(:,1)-mech*report.contract.pole_pairs),cos(theta(:,1)-mech*report.contract.pole_pairs));plot(s.log_encoder_control.Time*1e3,e*180/pi,'Color',colors(k,:));end
title('电角误差');ylabel('°');legend(labels,'Location','best');xlim(p.plot_window_s*1e3);finish;
nexttile;hold on;for k=1:2,s=outputs{k};tc=s.log_speed_control.Time;[ok,at]=ismember(round(tc/p.comparison_contract.event_step_s),round(s.log_speed.Time/p.comparison_contract.event_step_s));assert(all(ok));truth=v(s,'log_speed');plot(tc*1e3,v(s,'log_speed_control')-truth(at),'Color',colors(k,:));end
title('速度反馈误差');ylabel('rpm');legend(labels,'Location','best');xlim(p.plot_window_s*1e3);finish;
nexttile;s=outputs{2};raw=v(s,'log_speed_window');filtered=v(s,'log_speed_filter');plot(s.log_speed_window.Time*1e3,raw(:,1));hold on;plot(s.log_speed_filter.Time*1e3,filtered(:,3));
title('计数测速与滤波');ylabel('rpm');legend('窗口测速','滤波输出','Location','best');xlim(p.plot_window_s*1e3);finish;
nexttile;hold on;for k=1:2,s=outputs{k};piData=v(s,'obs_pi_speed');plot(s.obs_pi_speed.Time*1e3,piData(:,2),'Color',colors(k,:));end
title('速度环积分');ylabel('N·m');legend(labels,'Location','best');finish;
sgtitle('反馈链');exportgraphics(f,fullfile(folder,'feedback.png'),'Resolution',130);clear g;
f=figure('Visible','off','Color','white','Position',[100 100 1200 760]);g=onCleanup(@()close(f));tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
lim=0;for k=1:2,s=outputs{k};ix=s.obs_current_fast.Time>=p.plot_window_s(1);cur=v(s,'obs_current_fast');lim=max(lim,max(abs(cur(ix,:)),[],'all'));end
for k=1:2,nexttile;s=outputs{k};plot(s.obs_current_fast.Time*1e3,v(s,'obs_current_fast'));title(labels{k});ylabel('相电流 [A]');legend('A','B','C','Location','best');xlim(p.plot_window_s*1e3);ylim([-lim lim]*1.05);finish;end
for j=1:2,nexttile;hold on;for k=1:2,s=outputs{k};state=v(s,'obs_state');plot(s.obs_state.Time*1e3,state(:,j),'Color',colors(k,:));end
names={'id','iq'};title(names{j});ylabel('A');legend(labels,'Location','best');xlim(p.plot_window_s*1e3);finish;end
sgtitle('三相与dq电流');exportgraphics(f,fullfile(folder,'currents.png'),'Resolution',130);clear g;
fprintf('SYSTEM_ANALYSIS_PASS; PLATFORMS_PASS %d\n',report.all_platforms_pass);
end
function x=v(s,n),x=teach_values(s.(n));end
function finish,grid on;xlabel('时间 [ms]');set(gca,'FontName','Microsoft YaHei','FontSize',10);end
