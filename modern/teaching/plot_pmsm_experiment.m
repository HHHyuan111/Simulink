function plot_pmsm_experiment(outputs,plan,folder,skipCurrents)
% Same axes and time window for the two cases; no smoothing or THD claim.
if nargin<4,skipCurrents=false;end
colors=[.12 .30 .52;.86 .35 .12];phaseColors=[.12 .42 .72;.90 .36 .12;.15 .57 .36];window=plan.plot_window_s;
truth=cell(1,2);measured=cell(1,2);fast=cell(1,2);
for k=1:2,truth{k}=teach_values(outputs{k}.log_iabc_true);measured{k}=teach_values(outputs{k}.log_iabc_meas);fast{k}=teach_values(outputs{k}.obs_current_fast);end
assert(isequal(outputs{1}.log_iabc_true.Time,outputs{2}.log_iabc_true.Time),'两组时间轴不一致。');
if ~skipCurrents
f=page([plan.scenario.name '：三相电流与测量值'],[1350 960]);guard=onCleanup(@()close(f));tiledlayout(3,2,'TileSpacing','compact','Padding','compact');
for phase=1:3
 allValues=[];
 for k=1:2
  s=outputs{k};tf=s.obs_current_fast.Time;t=s.log_iabc_meas.Time;ii=tf>=window(1)&tf<=window(2);im=t>=window(1)&t<=window(2);
  allValues=[allValues;fast{k}(ii,phase);measured{k}(im,phase)]; %#ok<AGROW>
 end
 limits=rangeWithMargin(allValues);
 for k=1:2
  s=outputs{k};nexttile;hold on;
  plot(s.obs_current_fast.Time*1000,fast{k}(:,phase),'Color',[.2 .24 .29],'LineWidth',.65);
  stairs(s.log_iabc_meas.Time*1000,measured{k}(:,phase),'Color',colors(k,:),'LineWidth',1);
  xlim(window*1000);ylim(limits);grid on;title(sprintf('%s | %c相',plan.cases(k).label,'A'+phase-1));xlabel('时间 [ms]');ylabel('电流 [A]');
  if phase==1,legend('真实电流','测量电流');end
 end
end
sgtitle([plan.scenario.name '：三相电流'],'Interpreter','none','FontSize',14);
pmsm_plot_style(f);
exportgraphics(f,fullfile(folder,'comparison.png'),'Resolution',140);clear guard;
end

f=page([plan.scenario.name '：闭环响应与误差'],[1450 1020]);guard=onCleanup(@()close(f));tiledlayout(3,2,'TileSpacing','compact','Padding','compact');
t=outputs{1}.log_speed.Time;states=cellfun(@(s)teach_values(s.obs_state),outputs,'UniformOutput',false);
nexttile;hold on;plot(t,teach_values(outputs{1}.log_nref),'k--');
for k=1:2,plot(t,teach_values(outputs{k}.log_speed),'Color',colors(k,:));end
decorate('转速','rpm',{'给定','参考','实验'});
nexttile;hold on;
for k=1:2,plot(t,teach_values(outputs{k}.log_Te),'Color',colors(k,:));end
plot(t,teach_values(outputs{1}.log_TL),'k--');decorate('转矩','N·m',{'参考','实验','负载'});
nexttile;hold on;
plot(t,teach_values(outputs{2}.obs_id_ref),'k--');plot(t,states{1}(:,1),'Color',colors(1,:));plot(t,states{2}(:,1),'Color',colors(2,:));
plot(t,teach_values(outputs{2}.log_id),':','Color',[.40 .20 .55]);decorate('d轴电流','A',{'给定','参考真值','实验真值','实验反馈'});
nexttile;hold on;
plot(t,teach_values(outputs{2}.log_iq_ref),'k--');plot(t,states{1}(:,2),'Color',colors(1,:));plot(t,states{2}(:,2),'Color',colors(2,:));
plot(t,teach_values(outputs{2}.log_iq),':','Color',[.40 .20 .55]);decorate('q轴电流','A',{'给定','参考真值','实验真值','实验反馈'});
nexttile;hold on;error=measured{2}-truth{2};
for phase=1:3,stairs(t*1000,error(:,phase),'Color',phaseColors(phase,:));end
xlim(window*1000);grid on;title('测量误差');xlabel('时间 [ms]');ylabel('电流误差 [A]');legend('A','B','C');
nexttile;hold on;difference=truth{2}-truth{1};
for phase=1:3,plot(t*1000,difference(:,phase),'Color',phaseColors(phase,:));end
xlim(window*1000);grid on;title('电流变化');xlabel('时间 [ms]');ylabel('电流差 [A]');legend('A','B','C');
sgtitle([plan.scenario.name '：闭环响应'],'Interpreter','none','FontSize',14);
pmsm_plot_style(f);
exportgraphics(f,fullfile(folder,'response.png'),'Resolution',140);clear guard;
end

function f=page(name,dimensions)
f=figure('Visible','off','Color','white','Name',name,'Position',[40 40 dimensions]);
set(f,'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei','DefaultAxesFontSize',10,'DefaultTextInterpreter','none');
end
function decorate(name,unit,labels)
grid on;title(name);xlabel('时间 [s]');ylabel(unit);legend(labels,'Location','best');
end
function limits=rangeWithMargin(values)
lo=min(values);hi=max(values);pad=max(.03,(hi-lo)*.08);limits=[lo-pad hi+pad];
end
