function plot_pmsm_deadtime_pair(outputs,plan,folder)
% Matched bridge/grid comparison; physical angle alignment, not peak shifting.
[aligned,info]=pmsm_deadtime_pair_alignment(outputs,plan);
c=[.12 .40 .72;.89 .34 .11];f=page([1280 1000]);g=onCleanup(@()close(f));
tiledlayout(3,1,'TileSpacing','compact','Padding','compact');
for phase=1:3
 nexttile;hold on;
 for k=1:2,plot(aligned(k).angle_deg,aligned(k).current_ABC_A(:,phase),'Color',c(k,:),'LineWidth',.8);end
 grid on;xlim([0 360]);xticks(0:60:360);title(sprintf('%c相电流','A'+phase-1));xlabel('电角度 [°]');ylabel('电流 [A]');legend('零死区','死区');
end
sgtitle('死区配对','FontSize',14);pmsm_plot_style(f);exportgraphics(f,fullfile(folder,'comparison.png'),'Resolution',140);clear g;
plot_pmsm_experiment(outputs,plan,folder,true);plot_pmsm_mechanism(outputs,plan,folder);

f=page([1280 900]);g=onCleanup(@()close(f));tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
t=outputs{1}.log_speed.Time;nr=teach_values(outputs{1}.log_speed);nf=teach_values(outputs{2}.log_speed);
x=teach_values(outputs{1}.obs_state);y=teach_values(outputs{2}.obs_state);
ix=strcmp({plan.baseline_state.workspace_values.name},'p');polePairs=plan.baseline_state.workspace_values(ix).value;
direct=polePairs*(y(:,4)-x(:,4))*180/pi;integrated=direct(1)+cumtrapz(t,nf-nr)*6*polePairs;
nexttile;hold on;plot(t,nr,'Color',c(1,:));plot(t,nf,'Color',c(2,:));grid on;title('转速');xlabel('时间 [s]');ylabel('转速 [rpm]');legend('零死区','死区');
nexttile;plot(t,nf-nr,'Color',c(2,:));grid on;title('转速差');xlabel('时间 [s]');ylabel('转速差 [rpm]');
nexttile;plot(t,direct,'Color',c(2,:));grid on;title('电角度差');xlabel('时间 [s]');ylabel('电角度差 [°]');
nexttile;hold on;plot(t,direct,'Color',c(1,:));plot(t,integrated,'--','Color',c(2,:));grid on;title('角度积分核对');xlabel('时间 [s]');ylabel('电角度差 [°]');legend('角度记录','速度积分');
sgtitle('启动相位','FontSize',14);pmsm_plot_style(f);exportgraphics(f,fullfile(folder,'startup.png'),'Resolution',140);
info.startup=struct('final_electrical_angle_difference_deg',direct(end),'integrated_speed_difference_deg',integrated(end), ...
 'final_integration_residual_deg',direct(end)-integrated(end),'peak_speed_difference_rpm',max(abs(nf-nr)), ...
 'definition','死区组−零死区组；累计角度差未折回±180°；速度积分采用50μs控制记录的梯形积分。');
teach_writejson(fullfile(folder,'alignment.json'),info);
end
function f=page(size)
f=figure('Visible','off','Color','white','Position',[40 40 size]);
set(f,'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei','DefaultTextInterpreter','none');
end
