function fig=open_pmsm_vector_lesson(folder,visible)
% Native-sample playback of verified archives; does not touch a Simulink model.
if nargin<1,folder=[];end
if nargin<2,visible='on';end
teach=fileparts(mfilename('fullpath'));here=fullfile(teach,'vector_lesson');addpath(here);
data=pmsm_vector_load(folder);
if strcmp(visible,'on')
 existing=findall(groot,'Type','figure','Tag','pmsm_vector_lesson');
 for f=existing(:)'
  if isappdata(f,'vector_data')&&strcmp(getappdata(f,'vector_data').folder,data.folder),figure(f);fig=f;return;end
 end
end
fig=uifigure('Name','坐标与矢量','Tag','pmsm_vector_lesson','Position',[80 60 1380 940], ...
 'Color',[.96 .97 .99],'Visible',visible,'AutoResizeChildren','off','CloseRequestFcn',@closeView);
g=uigridlayout(fig,[6 1]);g.Padding=[22 16 22 16];g.RowSpacing=12;g.RowHeight={40,42,'1x',32,42,40};
heading=uilabel(g,'Text','坐标与矢量','FontSize',25,'FontWeight','bold');heading.Layout.Row=1;
tools=uigridlayout(g,[1 6]);tools.Layout.Row=2;tools.Padding=[0 0 0 0];tools.ColumnSpacing=12;
tools.ColumnWidth={'1x',155,115,120,120,120};
choice=uidropdown(tools,'Items',{data.cases.label},'ItemsData',1:numel(data.cases),'Value',1, ...
 'FontSize',16,'Tag','vector_case','ValueChangedFcn',@changeView,'Tooltip','两组使用相同模型、PI和工况，仅角度偏置不同');
window=uidropdown(tools,'Items',{data.windows.name},'ItemsData',1:numel(data.windows),'Value',1, ...
 'FontSize',16,'Tag','vector_window','ValueChangedFcn',@changeView);
axesOn=uicheckbox(tools,'Text','坐标轴','Value',true,'FontSize',15,'Tag','vector_axes','ValueChangedFcn',@toggleAxes);
loadButton=uibutton(tools,'Text','载入实验','FontSize',15,'Tag','vector_load','ButtonPushedFcn',@loadArchive);
uibutton(tools,'Text','带读说明','FontSize',15,'Tag','vector_notes','ButtonPushedFcn',@(~,~)edit(fullfile(here,'带读说明.md')));
exportButton=uibutton(tools,'Text','导出本页','FontSize',15,'Tag','vector_export','BackgroundColor',[.16 .43 .70], ...
 'FontColor','white','ButtonPushedFcn',@exportPage);
plots=uigridlayout(g,[2 2]);plots.Layout.Row=3;plots.Padding=[0 0 0 0];plots.RowSpacing=20;plots.ColumnSpacing=26;
ax=gobjects(1,4);
for k=1:4
 card=uipanel(plots,'BorderType','none','BackgroundColor','white');card.Layout.Row=ceil(k/2);card.Layout.Column=1+mod(k-1,2);
 inner=uigridlayout(card,[1 1]);inner.Padding=[12 12 12 12];
 ax(k)=uiaxes(inner,'Tag',sprintf('vector_ax_%d',k),'PositionConstraint','outerposition');
end
readout=uilabel(g,'Text','','FontSize',14,'Tag','vector_readout');readout.Layout.Row=4;
player=uigridlayout(g,[1 6]);player.Layout.Row=5;player.Padding=[0 0 0 0];player.ColumnSpacing=12;
player.ColumnWidth={90,90,105,'1x',105,30};
play=uibutton(player,'Text','播放','FontSize',16,'Tag','vector_play','ButtonPushedFcn',@togglePlay);
uibutton(player,'Text','回到起点','FontSize',15,'Tag','vector_reset','ButtonPushedFcn',@resetCursor);
speed=uidropdown(player,'Items',{'慢速回放','中速回放','快速回放'},'ItemsData',[8 4 2],'Value',4,'FontSize',14,'Tag','vector_speed');
slider=uislider(player,'Tag','vector_slider','ValueChangingFcn',@scrub,'ValueChangedFcn',@scrub);
slider.MajorTicks=[];slider.MinorTicks=[];
timeBox=uieditfield(player,'numeric','FontSize',15,'ValueDisplayFormat','%.3f','Tag','vector_time','ValueChangedFcn',@setTime);
uilabel(player,'Text','ms','FontSize',14);
status=uilabel(g,'Text','','FontSize',13,'WordWrap','on','Tag','vector_status');status.Layout.Row=6;
clock=timer('ExecutionMode','fixedSpacing','Period',.05,'BusyMode','drop', ...
 'Tag','pmsm_vector_playback','TimerFcn',@tick,'ErrorFcn',@timerError);
h=[];frame=pmsm_vector_frame(data,1,1);setappdata(fig,'vector_data',data);setappdata(fig,'vector_timer',clock);
fig.SizeChangedFcn=@resized;refresh(true);resized(fig,[]);

 function refresh(rebuild)
  if rebuild,h=[];end
  h=pmsm_vector_plot(ax,data,frame,axesOn.Value,h);
  slider.Limits=frame.bounds_s*1000;slider.Value=frame.time_s*1000;
  timeBox.Limits=frame.bounds_s*1000;timeBox.Value=frame.time_s*1000;
  readout.Text=sprintf('t = %.3f ms    θe = %.1f°    Δθe = %+.2f°    id = %+.3f A    iq = %+.3f A', ...
   frame.time_s*1000,mod(frame.theta_true_rad,2*pi)*180/pi,frame.angle_error_deg,frame.dq_true_A);
  status.Text=sprintf('档案：%s  |  原始采样 %.0f μs  |  回放与显示不改变模型参数',data.source_id,data.sample_period_s*1e6);
  setappdata(fig,'vector_frame',frame);setappdata(fig,'vector_plot_handles',h);drawnow limitrate;
 end
 function changeView(~,~)
  pausePlayback;frame=pmsm_vector_frame(data,choice.Value,window.Value,frame.time_s);refresh(true);
 end
 function toggleAxes(~,~),refresh(false);end
 function scrub(~,event)
  pausePlayback;frame=pmsm_vector_frame(data,choice.Value,window.Value,event.Value/1000);refresh(false);
 end
 function setTime(~,~)
  pausePlayback;frame=pmsm_vector_frame(data,choice.Value,window.Value,timeBox.Value/1000);refresh(false);
 end
 function resetCursor(~,~)
  pausePlayback;frame=pmsm_vector_frame(data,choice.Value,window.Value,data.windows(window.Value).bounds_s(1));refresh(false);
 end
 function togglePlay(~,~)
  if strcmp(clock.Running,'on'),pausePlayback;return;end
  if frame.index==frame.indices(end),frame=pmsm_vector_frame(data,choice.Value,window.Value,frame.bounds_s(1));refresh(false);end
  play.Text='暂停';start(clock);
 end
 function tick(~,~)
  if ~isvalid(fig),stop(clock);return;end
  advance=max(1,round(numel(frame.indices)*clock.Period/speed.Value));
  idx=min(frame.indices(end),frame.index+advance);c=data.cases(choice.Value);
  frame=pmsm_vector_frame(data,choice.Value,window.Value,c.time_s(idx));refresh(false);
  if idx==frame.indices(end),pausePlayback;end
 end
 function pausePlayback
  if isvalid(clock)&&strcmp(clock.Running,'on'),stop(clock);end
  if isvalid(play),play.Text='播放';end
 end
 function timerError(~,event)
  pausePlayback;if isvalid(status),status.Text=['回放停止：' event.Data.Message];end
 end
 function exportPage(~,~)
  pausePlayback;exportButton.Enable='off';loadButton.Enable='off';status.Text='正在导出当前视图与角度对照，原始档案保持。';drawnow;
  guard=onCleanup(@enableButtons);
  try
   r=export_pmsm_vector_lesson(data,choice.Value,window.Value,frame.time_s,axesOn.Value);
   setappdata(fig,'vector_last_export',r.folder);status.Text=['已导出：' r.folder];
   addpath(fullfile(fileparts(teach),'layout','appearance'));
   pmsm_show_report(r.folder,{'snapshot.png','坐标与矢量';'comparison.png','角度偏置'},'坐标与矢量 · 导出结果');
  catch err,status.Text=err.message;uialert(fig,err.message,'导出未完成');end
 end
 function enableButtons
  if isvalid(exportButton),exportButton.Enable='on';end
  if isvalid(loadButton),loadButton.Enable='on';end
 end
 function loadArchive(~,~)
  pausePlayback;folder=uigetdir(fullfile(teach,'experiments','runs'),'选择已完成的角度偏置实验目录');
  if isequal(folder,0),return;end
  try
   fresh=pmsm_vector_load(folder);data=fresh;setappdata(fig,'vector_data',data);
   choice.Items={data.cases.label};choice.ItemsData=1:numel(data.cases);choice.Value=1;
   window.Items={data.windows.name};window.ItemsData=1:numel(data.windows);window.Value=1;
   frame=pmsm_vector_frame(data,1,1);refresh(true);
  catch err,status.Text=err.message;uialert(fig,err.message,'载入未完成');end
 end
 function resized(source,~)
  if source.Position(3)<1100||source.Position(4)<760
   p=source.Position;p(3:4)=max(p(3:4),[1100 760]);source.Position=p;
  end
 end
 function closeView(~,~)
  if isvalid(clock),stop(clock);delete(clock);end
  delete(fig);
 end
end
