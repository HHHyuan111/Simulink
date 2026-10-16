function h=pmsm_vector_plot(ax,data,frame,showAxes,h)
% Four linked panels. Static traces retain every sample in the selected window.
c=data.cases(frame.case_index);ii=frame.indices;xy=c.alpha_beta_A;limits=frame.limits;
colors=[.12 .40 .72;.89 .34 .11;.14 .57 .36];truth=colors(1,:);feedback=colors(2,:);
if nargin<5||isempty(h)
 for a=ax(:)'
  cla(a,'reset');hold(a,'on');a.FontName='Microsoft YaHei';a.FontSize=12;a.Box='off';a.TickDir='out';
  a.XGrid='on';a.YGrid='on';a.GridAlpha=.12;a.Color='white';
  a.Title.FontWeight='normal';a.Title.FontSize=14;
 end
 title(ax(1),'三相电流');xlabel(ax(1),'时间 [ms]');ylabel(ax(1),'电流 [A]');
 for k=1:3,plot(ax(1),c.time_s(ii)*1000,c.abc_A(ii,k),'Color',colors(k,:),'LineWidth',1.1,'DisplayName',char('A'+k-1));end
 ylim(ax(1),limits.abc_A);xlim(ax(1),frame.bounds_s*1000);legend(ax(1),'show','Location','northoutside','Orientation','horizontal','Box','off');
 h.abcCursor=plot(ax(1),[0 0],limits.abc_A,'--','Color',[.4 .43 .48],'HandleVisibility','off');
 h.abcPoints=scatter(ax(1),zeros(1,3),zeros(1,3),35,colors,'filled','HandleVisibility','off');
 title(ax(2),'αβ电流');xlabel(ax(2),'iα [A]');ylabel(ax(2),'iβ [A]');
 h.trajectory=plot(ax(2),NaN,NaN,'Color',truth,'LineWidth',1.1,'DisplayName','轨迹');
 h.vector=plot(ax(2),[0 0],[0 0],'-o','Color',[.12 .17 .24],'LineWidth',1.6,'MarkerIndices',2,'MarkerSize',6,'DisplayName','电流矢量');
 h.rotorD=plot(ax(2),[0 0],[0 0],'-','Color',[.42 .46 .51],'LineWidth',1.2,'DisplayName','真实d轴');
 h.rotorQ=plot(ax(2),[0 0],[0 0],'-','Color',[.42 .46 .51],'LineWidth',1,'HandleVisibility','off');
 h.controlD=plot(ax(2),[0 0],[0 0],'--','Color',feedback,'LineWidth',1.2,'DisplayName','控制d轴');
 h.controlQ=plot(ax(2),[0 0],[0 0],'--','Color',feedback,'LineWidth',1,'HandleVisibility','off');
 labels={'d','q','dc','qc'};h.axisText=gobjects(1,4);
 for k=1:4,col=[.42 .46 .51];if k>2,col=feedback;end
  h.axisText(k)=text(ax(2),0,0,labels{k},'Color',col,'FontSize',11,'Clipping','on','Interpreter','none');
 end
 xlim(ax(2),[-limits.xy_A limits.xy_A]);ylim(ax(2),[-limits.xy_A limits.xy_A]);ax(2).DataAspectRatio=[1 1 1];
 for k=1:2
  a=ax(k+2);field='d_A';letter='d';if k==2,field='q_A';letter='q';end
  title(a,[letter '轴电流']);xlabel(a,'时间 [ms]');ylabel(a,'电流 [A]');
  plot(a,c.time_s(ii)*1000,c.dq_true_A(ii,k),'Color',truth,'LineWidth',1.2,'DisplayName','真实');
  plot(a,c.time_s(ii)*1000,c.dq_feedback_A(ii,k),'Color',feedback,'LineWidth',1.1,'DisplayName','反馈');
  plot(a,c.time_s(ii)*1000,c.dq_reference_A(ii,k),'--','Color',[.28 .31 .35],'LineWidth',1,'DisplayName','给定');
  ylim(a,limits.(field));xlim(a,frame.bounds_s*1000);legend(a,'show','Location','northoutside','Orientation','horizontal','Box','off');
  h.dqCursor(k)=plot(a,[0 0],limits.(field),'--','Color',[.4 .43 .48],'HandleVisibility','off');
  h.dqPoints(k)=scatter(a,[0 0],[0 0],35,[truth;feedback],'filled','HandleVisibility','off');
 end
end
h.abcCursor.XData=frame.time_s*[1000 1000];h.abcPoints.XData=frame.time_s*[1000 1000 1000];h.abcPoints.YData=frame.abc_A;
h.trajectory.XData=xy(frame.history_indices,1);h.trajectory.YData=xy(frame.history_indices,2);
h.vector.XData=[0 frame.alpha_beta_A(1)];h.vector.YData=[0 frame.alpha_beta_A(2)];
angles=[frame.theta_true_rad frame.theta_true_rad+pi/2 frame.theta_control_rad frame.theta_control_rad+pi/2];
axisLines=[h.rotorD h.rotorQ h.controlD h.controlQ];radius=limits.xy_A*.76;
for k=1:4
 endpoint=radius*[cos(angles(k)) sin(angles(k))];axisLines(k).XData=[0 endpoint(1)];axisLines(k).YData=[0 endpoint(2)];
 factor=1.06;if k>2,factor=1.25;end
 h.axisText(k).Position=[endpoint*factor 0];axisLines(k).Visible=onoff(showAxes);h.axisText(k).Visible=onoff(showAxes);
end
if ~isfield(h,'axesShown')||h.axesShown~=showAxes
 if showAxes,handles=[h.trajectory h.vector h.rotorD h.controlD];labels={'轨迹','电流矢量','真实d轴','控制d轴'};
 else,handles=[h.trajectory h.vector];labels={'轨迹','电流矢量'};end
 legend(ax(2),handles,labels,'Location','northoutside','Orientation','horizontal','NumColumns',2,'Box','off','FontSize',10);
 h.axesShown=logical(showAxes);
end
for k=1:2
 h.dqCursor(k).XData=frame.time_s*[1000 1000];h.dqPoints(k).XData=frame.time_s*[1000 1000];
 h.dqPoints(k).YData=[frame.dq_true_A(k) frame.dq_feedback_A(k)];
end
end
function s=onoff(value)
if value,s='on';else,s='off';end
end
