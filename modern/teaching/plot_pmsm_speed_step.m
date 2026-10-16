function fig=plot_pmsm_speed_step(raw,p,amplitude)
% Original sampled traces, linked time axes, concise native figure.
blue=[0 .447 .741];red=[.85 .325 .098];gray=[.45 .45 .45];
fig=figure('Name','速度环阶跃基线','Color','white','Position',[80 60 1120 800]);
g=tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');title(g,'速度环阶跃');
t=raw.speed_ref.Time*1000;state=teach_values(raw.obs_state);
ax(1)=nexttile(g);plot(t,teach_values(raw.speed_ref),'--','Color',gray);hold on;
plot(t,state(:,3)*30/pi,'Color',blue);plot(t,teach_values(raw.speed_feedback),'Color',red);
title('转速');ylabel('rpm');legend('给定','真实','反馈','Location','best');
ax(2)=nexttile(g);plot(t,teach_values(raw.speed_iq_ref),'Color',red);hold on;plot(t,state(:,2),'Color',blue);
title('q轴电流');ylabel('A');legend('给定','真实','Location','best');
ax(3)=nexttile(g);plot(t,teach_values(raw.speed_torque),'Color',blue);hold on;plot(t,zeros(size(t)),'--','Color',gray);
title('转矩');ylabel('N·m');legend('电磁转矩','负载','Location','best');
ax(4)=nexttile(g);plot(t,teach_values(raw.speed_error),'Color',blue);
title('速度误差');ylabel('rpm');
for a=ax,set(a,'Color','white','FontSize',12);grid(a,'on');xlabel(a,'时间 [ms]');xlim(a,[0 p.duration_s*1000]);end
linkaxes(ax,'x');fig.UserData=struct('amplitude_rpm',amplitude,'kind','speed_step_baseline');
end
