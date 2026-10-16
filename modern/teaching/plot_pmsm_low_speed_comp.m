function plot_pmsm_low_speed_comp(outputs,plan,folder)
% Existing compensation only. Raw currents aligned by true rotor angle.
assert(strcmp(plan.scenario.id,'low_speed_compensation')&&numel(outputs)==3);
[aligned,info]=pmsm_deadtime_pair_alignment(outputs,plan);colors=[.12 .40 .72;.89 .34 .11;.14 .57 .36];labels={plan.cases.label};
f=page([1280 1000]);guard=onCleanup(@()close(f));tiledlayout(3,1,'TileSpacing','compact','Padding','compact');
for phase=1:3
 nexttile;hold on;
 for k=1:3,plot(aligned(k).angle_deg,aligned(k).current_ABC_A(:,phase),'Color',colors(k,:),'LineWidth',.8);end
 grid on;xlim([0 360]);xticks(0:60:360);title(sprintf('%c相电流','A'+phase-1));xlabel('电角度 [°]');ylabel('电流 [A]');legend(labels);
end
sgtitle('低速补偿','FontSize',14);savePage(f,folder,'comparison.png');clear guard;

t=outputs{1}.log_speed.Time;states=cellfun(@(s)teach_values(s.obs_state),outputs,'UniformOutput',false);
f=page([1280 900]);guard=onCleanup(@()close(f));tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
nexttile;hold on;for k=1:3,plot(t,teach_values(outputs{k}.log_speed),'Color',colors(k,:));end
plot(t,teach_values(outputs{1}.log_nref),'k--');frame('转速','rpm');legend([labels {'给定'}]);
nexttile;hold on;for k=1:3,plot(t,teach_values(outputs{k}.log_Te),'Color',colors(k,:));end
plot(t,teach_values(outputs{1}.log_TL),'k--');frame('转矩','N·m');legend([labels {'负载'}]);
nexttile;hold on;for k=1:3,plot(t,states{k}(:,1),'Color',colors(k,:));end
plot(t,teach_values(outputs{1}.obs_id_ref),'k--');frame('d轴电流','A');legend([labels {'给定'}]);
nexttile;hold on;for k=1:3,plot(t,states{k}(:,2),'Color',colors(k,:));end
plot(t,teach_values(outputs{3}.log_iq_ref),'k--');frame('q轴电流','A');legend([labels {'补偿给定'}]);
sgtitle('闭环响应','FontSize',14);savePage(f,folder,'response.png');clear guard;

s=outputs{3};tc=s.obs_dead_comp.Time;diag=teach_values(s.obs_dead_comp);range=info.cases(3).time_window_s*1000;
f=page([1280 900]);guard=onCleanup(@()close(f));tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
nexttile;hold on;for k=1:3,stairs(tc*1000,diag(:,k),'Color',colors(k,:));end
frame('相电压补偿','V');xlabel('时间 [ms]');xlim(range);legend('A','B','C');
nexttile;hold on;stairs(tc*1000,diag(:,4),'Color',colors(1,:));stairs(tc*1000,diag(:,5),'Color',colors(2,:));
frame('dq电压补偿','V');xlabel('时间 [ms]');xlim(range);legend('d','q');
nexttile;hold on;for k=1:3,stairs(tc*1000,diag(:,k+5),'Color',colors(k,:));end
frame('电流极性','1');xlabel('时间 [ms]');xlim(range);ylim([-1.2 1.2]);yticks([-1 0 1]);legend('A','B','C');
nexttile;hold on;for k=1:3,plot(aligned(k).angle_deg,aligned(k).current_ABC_A(:,1),'Color',colors(k,:));end
grid on;xlim([165 195]);title('A相过零');xlabel('电角度 [°]');ylabel('电流 [A]');legend(labels);
sgtitle('补偿观测','FontSize',14);savePage(f,folder,'mechanism.png');clear guard;

f=page([1280 900]);guard=onCleanup(@()close(f));tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
ix=strcmp({plan.baseline_state.workspace_values.name},'p');polePairs=plan.baseline_state.workspace_values(ix).value;
speed=cellfun(@(s)teach_values(s.log_speed),outputs,'UniformOutput',false);direct=cell(1,2);integrated=cell(1,2);
nexttile;hold on;for k=1:3,plot(t,speed{k},'Color',colors(k,:));end
frame('转速','rpm');legend(labels);
nexttile;hold on;for k=2:3,plot(t,speed{k}-speed{1},'Color',colors(k,:));end
frame('转速差','rpm');legend(labels(2:3));
for k=2:3
 direct{k-1}=polePairs*(states{k}(:,4)-states{1}(:,4))*180/pi;
 integrated{k-1}=direct{k-1}(1)+cumtrapz(t,speed{k}-speed{1})*6*polePairs;
end
nexttile;hold on;for k=2:3,plot(t,direct{k-1},'Color',colors(k,:));end
frame('电角度差','°');legend(labels(2:3));
nexttile;hold on;
for k=2:3,plot(t,direct{k-1},'Color',colors(k,:));plot(t,integrated{k-1},'--','Color',colors(k,:));end
frame('角度积分核对','°');legend('死区','死区积分','补偿','补偿积分');
sgtitle('启动相位','FontSize',14);savePage(f,folder,'startup.png');
info.startup=struct('definition','各组−零死区组；不折回±180°；速度积分为50μs记录的梯形积分。','cases',struct('id',{},'final_electrical_angle_difference_deg',{},'integrated_speed_difference_deg',{},'integration_residual_deg',{}));
for k=2:3
 info.startup.cases(k-1)=struct('id',plan.cases(k).id,'final_electrical_angle_difference_deg',direct{k-1}(end), ...
  'integrated_speed_difference_deg',integrated{k-1}(end),'integration_residual_deg',direct{k-1}(end)-integrated{k-1}(end));
end
teach_writejson(fullfile(folder,'alignment.json'),info);
end
function f=page(size)
f=figure('Visible','off','Color','white','Position',[40 40 size]);
set(f,'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei','DefaultTextInterpreter','none');
end
function frame(name,unit)
grid on;title(name);xlabel('时间 [s]');ylabel(unit);
end
function savePage(f,folder,name)
pmsm_plot_style(f);exportgraphics(f,fullfile(folder,name),'Resolution',140);
end
