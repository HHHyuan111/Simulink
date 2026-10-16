function [fig,report]=open_pmsm_timing_filter
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'signal_chain'));[out,report]=timing_filter_data;
fig=figure('Name','滤波与PWM时序 · 已保存实验','NumberTitle','off','Color','white','Position',[80 60 1120 800],'Tag','PMSMTimingFilter','UserData',report);
g=tiledlayout(fig,3,2,'Padding','compact','TileSpacing','compact');title(g,'滤波与PWM时序');colors=[0 .447 .741;.84 .15 .16;0 .447 .741;.84 .15 .16];axesTime=gobjects(1,6);
titles={'A相测量误差','d轴真实电流','q轴跟踪误差','转矩','转速','q轴误差增量'};units={'A','A','A','N·m','rpm','A'};
errors=cell(1,4);for k=1:4,state=teach_values(out{k}.obs_state);errors{k}=state(:,2)-teach_values(out{k}.log_iq_ref);end
for panel=1:6
 axesTime(panel)=nexttile(g);hold on;
 if panel==6
  t=out{1}.log_Te.Time;ix=t>=.18&t<=.2;
  incrementLabels={'计算5 μs','计算15 μs'};
  for k=1:2,y=errors{k+2}-errors{k};plot(t(ix)*1000,y(ix),'Color',colors(k,:),'LineWidth',1.1,'DisplayName',incrementLabels{k},'Tag',sprintf('factorial_increment_%d',k));end
 else
  for k=1:4
   s=out{k};t=s.log_Te.Time;ix=t>=.18&t<=.2;state=teach_values(s.obs_state);
   switch panel
    case 1,y=teach_values(s.log_iabc_meas)-teach_values(s.log_iabc_true);y=y(:,1);
    case 2,y=state(:,1);
    case 3,y=errors{k};
    case 4,y=teach_values(s.log_Te);
    case 5,y=teach_values(s.log_speed);
   end
   style='-';if k<=2,style='--';end
   plot(t(ix)*1000,y(ix),'Color',colors(k,:),'LineStyle',style,'LineWidth',1.1,'DisplayName',report.labels{k},'Tag',sprintf('factorial_panel_%d_case_%d',panel,k));
  end
  if ismember(panel,[2 4 5])
   names={'obs_id_ref','log_TL','log_nref'};slot=find([2 4 5]==panel);y=teach_values(out{1}.(names{slot}));label='给定';if panel==4,label='负载';end
   plot(t(ix)*1000,y(ix),':','Color',[.4 .4 .4],'DisplayName',label,'Tag',sprintf('factorial_reference_%d',panel));
  end
 end
 title(titles{panel});ylabel(units{panel});xlabel('时间 [ms]');grid on;ax=gca;ax.FontSize=11;xlim([180 200]);
end
shared=gobjects(1,5);
for k=1:4,shared(k)=findobj(fig,'Tag',sprintf('factorial_panel_2_case_%d',k));end
shared(5)=findobj(fig,'Tag','factorial_reference_2');
lg=legend(axesTime(2),shared,[report.labels {'给定/负载'}],'Orientation','horizontal','NumColumns',5,'FontSize',10,'Box','off','AutoUpdate','off');
lg.Layout.Tile='north';lg.Tag='factorial_shared_legend';
lg=legend(axesTime(6),'show','Location','northeast','NumColumns',2,'FontSize',10,'Box','on','Color','white','EdgeColor',[.8 .8 .8],'AutoUpdate','off');lg.Tag='factorial_increment_legend';
linkaxes(axesTime,'x');pmsm_sampling_comparison_menu(fig);uimenu(fig,'Text','指标与工况','MenuSelectedFcn',@(~,~)info(report));
end
function info(r)
f=figure('Name','滤波与时序指标 · 已保存实验','NumberTitle','off','MenuBar','none','ToolBar','none','Color','white','Position',[100 100 1080 430]);
names={'写入相位 [μs]','生效相位 [μs]','JEOS至生效 [μs]','真实iq跟踪RMS [A]','转矩标准差 [N·m]','转速跟踪RMS [rpm]'};values=[r.events_us';r.metrics'];data=cell(6,5);
for k=1:6,data(k,:)=[names(k) arrayfun(@(v)sprintf('%.6f',v),values(k,:),'UniformOutput',false)];end
uitable(f,'Data',data,'ColumnName',[{'指标'} r.labels],'RowName',[],'FontSize',13,'ColumnWidth',{260 185 185 185 185},'Units','normalized','Position',[.02 .46 .96 .51]);
uicontrol(f,'Style','text','BackgroundColor','white','FontSize',14,'HorizontalAlignment','left','Units','normalized','Position',[.03 .02 .94 .41],...
 'String',{'3000 rpm、24 V、0.207 N·m；原PI、零初态、理想桥；其他附加因素关闭。',...
 '同一真实时序、62.5 ns网格、10 μs触发；计算耗时5 μs或15 μs。',...
 '数字低通为三相静止坐标一阶1500 Hz；虚线关闭，实线开启。',...
 '所有曲线取180～200 ms、50 μs控制记录，不是全带宽纹波。',...
 '右下图是各计算时间下，有/无滤波的真实q轴误差之差。',...
 '这包含闭环轨迹变化，不是滤波器纯相移；无噪声注入，不评价噪声抑制收益。'});
end
