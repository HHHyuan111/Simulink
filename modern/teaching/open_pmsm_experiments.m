function f=open_pmsm_experiments
% Separate experiment entrance; the v1 reference tools remain byte-identical.
here=fileparts(mfilename('fullpath'));addpath(here,fullfile(fileparts(here),'layout','appearance'));catalog=pmsm_experiment_catalog;last=[];
f=figure('Name','PMSM 固定实验','NumberTitle','off','MenuBar','none','ToolBar','none','Color','white','Position',[100 80 1120 800],'Visible','off');
uicontrol(f,'Style','text','Tag','ExperimentHeading','Position',[25 425 770 35],'BackgroundColor','white','HorizontalAlignment','left', ...
 'String','固定参考 → 受控对照 → 查看结果 → 自动恢复。相同PI与工况，结果逐次存档。','FontSize',14);
selector=uicontrol(f,'Style','popupmenu','Position',[25 375 230 35],'String',{catalog.name},'Tag','ExperimentSelector','Callback',@(~,~)select());
valueLabel=uicontrol(f,'Style','text','Position',[265 380 80 20],'String','因素大小','BackgroundColor','white');
value=uicontrol(f,'Style','edit','Position',[345 377 180 30],'HorizontalAlignment','left','Tag','ExperimentValue','Callback',@(~,~)invalidate());
unit=uicontrol(f,'Style','text','Position',[540 380 245 20],'HorizontalAlignment','left','BackgroundColor','white');
cutoffLabel=uicontrol(f,'Style','text','Position',[265 345 80 20],'String','截止频率','BackgroundColor','white','Visible','off');
cutoff=uicontrol(f,'Style','edit','Position',[345 342 180 30],'HorizontalAlignment','left','Tag','ExperimentFilterHz','Visible','off','Callback',@(~,~)invalidate());
cutoffUnit=uicontrol(f,'Style','text','Position',[540 345 245 20],'String','Hz','HorizontalAlignment','left','BackgroundColor','white','Visible','off');
zeroLabel=uicontrol(f,'Style','text','Position',[265 310 80 20],'String','电角零位','BackgroundColor','white','Visible','off');
zero=uicontrol(f,'Style','edit','Position',[345 307 180 30],'Tag','ExperimentEncoderZero','Visible','off','Callback',@(~,~)invalidate());
zeroUnit=uicontrol(f,'Style','text','Position',[540 310 245 20],'String','电角度 °','HorizontalAlignment','left','BackgroundColor','white','Visible','off');
description=uicontrol(f,'Style','text','Position',[25 260 770 100],'HorizontalAlignment','left','BackgroundColor','white','FontSize',14);
restore=uicontrol(f,'Style','pushbutton','Position',[25 205 230 36],'String','恢复固定参考','Tag','ExperimentRestore','Callback',@(~,~)restoreReference());
run=uicontrol(f,'Style','pushbutton','Position',[275 205 230 36],'String','运行固定对照','Tag','ExperimentRun','Callback',@(~,~)runExperiment());
currents=uicontrol(f,'Style','pushbutton','Position',[25 150 230 36],'String','3 查看三相电流','Enable','off','Callback',@(~,~)show('comparison.png'));
response=uicontrol(f,'Style','pushbutton','Position',[275 150 230 36],'String','4 查看闭环响应与误差','Enable','off','Callback',@(~,~)show('response.png'));
mechanism=uicontrol(f,'Style','pushbutton','Position',[525 150 230 36],'String','5 查看因素机制','Enable','off','Tag','ExperimentMechanism','Callback',@(~,~)show('mechanism.png'));
startup=uicontrol(f,'Style','pushbutton','Position',[525 205 230 36],'String','6 查看启动相位','Enable','off','Tag','ExperimentStartup','Callback',@(~,~)preview());
status=uicontrol(f,'Style','edit','Min',0,'Max',2,'Enable','inactive','Position',[25 20 770 110],'HorizontalAlignment','left','BackgroundColor','white','String','选择实验并设置参数，然后运行固定对照。运行前自动恢复参考，结果逐次存档。','Tag','ExperimentStatus');
set(findall(f,'Type','uicontrol'),'FontSize',14);
f.SizeChangedFcn=@(~,~)relayout();relayout();select();f.Visible='on';
 function relayout
  sz=f.Position;w=max(1040,sz(3));h=max(780,sz(4));if any(sz(3:4)~=[w h]),f.Position=[sz(1:2) w h];end
  title=findobj(f,'Tag','ExperimentHeading');
  title.Position=[30 h-75 w-60 40];title.FontSize=16;title.FontWeight='bold';
  selector.Position=[30 h-155 315 48];
  labels=[valueLabel cutoffLabel zeroLabel];edits=[value cutoff zero];units=[unit cutoffUnit zeroUnit];
  for j=1:3,y=h-140-(j-1)*54;labels(j).Position=[380 y-5 125 30];edits(j).Position=[515 y-10 235 42];units(j).Position=[775 y-5 w-805 35];end
  description.Position=[30 h-390 w-60 130];
  bw=(w-90)/3;buttons=[restore run startup currents response mechanism];
  for j=1:6,row=floor((j-1)/3);col=mod(j-1,3);buttons(j).Position=[30+col*(bw+15) 305-row*65 bw 48];end
  status.Position=[30 35 w-60 165];
 end
 function select
  s=catalog(selector.Value);value.String=mat2str(s.default_value,5);unit.String=s.unit;
  set([cutoffLabel cutoff cutoffUnit],'Visible','off');cutoffLabel.String='截止频率';cutoffUnit.String='Hz';valueLabel.String='因素大小';
  set([zeroLabel zero zeroUnit],'Visible','off');zeroLabel.String='电角零位';zeroUnit.String='电角度 °';startup.String='6 查看启动相位';
  if strcmp(s.id,'noise_filter')
   value.String=num2str(s.default_value(1),5);unit.String='A RMS，每相';valueLabel.String='噪声 RMS';
   cutoff.String=num2str(s.default_value(2),5);set([cutoffLabel cutoff cutoffUnit],'Visible','on');
  end
  if strcmp(s.id,'sampling_window')
   value.String=num2str(s.default_value(1),7);unit.String='μs，PWM谷底为0';valueLabel.String='触发相位';
   cutoff.String=num2str(s.default_value(2),7);cutoffLabel.String='稳定等待';cutoffUnit.String='μs';
   set([cutoffLabel cutoff cutoffUnit],'Visible','on');
  end
  if strcmp(s.id,'encoder_angle')
   value.String=num2str(s.default_value(1),8);valueLabel.String='每转计数';unit.String='计数/机械转（已解码）';
   cutoff.String=num2str(s.default_value(2),8);cutoffLabel.String='延迟拍数';cutoffUnit.String='拍，每拍50μs';
   zero.String=num2str(s.default_value(3),8);set([cutoffLabel cutoff cutoffUnit zeroLabel zero zeroUnit],'Visible','on');
  end
  if ismember(s.id,{'encoder_speed','speed_feedback','speed_filter'})
   value.String=num2str(s.default_value(1),8);valueLabel.String='每转计数';unit.String='计数/机械转（已解码）';
   cutoff.String=num2str(s.default_value(2),8);cutoffLabel.String='差分窗口';cutoffUnit.String='拍，短窗固定1拍';
   zero.String=num2str(s.default_value(3),8);zeroLabel.String='长窗口';zeroUnit.String='拍，每拍50μs';
   set([cutoffLabel cutoff cutoffUnit zeroLabel zero zeroUnit],'Visible','on');
  end
  description.String=sprintf('%s\n%s\n边界：%s',s.question,s.observe,s.boundary);invalidate();
  if ismember(s.id,{'gate_deadtime_pair','low_speed_compensation'}),currents.String='3 查看电角度电流';else,currents.String='3 查看三相电流';end
  if strcmp(s.id,'low_speed_compensation'),mechanism.String='5 查看补偿观测';else,mechanism.String='5 查看因素机制';end
  response.String='4 查看闭环响应与误差';run.String='运行固定对照';status.String='尚未运行当前设置。默认每组0.2秒，结束后恢复固定参考。';
  if strcmp(s.id,'timing_events')
   valueLabel.String='计算耗时';currents.String='3 查看采样电流';response.String='4 查看运行状态';mechanism.String='5 查看周期事件';run.String='2 运行参考与时序观测';
   status.String='尚未运行当前设置。默认每组0.05秒，事件模式采用细网格，运行会较慢。';
  end
  if strcmp(s.id,'timing_deadline')
   valueLabel.String='计算耗时';currents.String='3 查看指令序号';response.String='4 查看运行状态';mechanism.String='5 查看更新边界';run.String='2 运行三组边界对照';
   status.String='默认每组0.05秒。按[赶上 同边界 错过]填写耗时；中间固定10.5μs，前后按0.0625μs调整。三组均使用真实时序，运行较慢。';
  end
  if strcmp(s.id,'sampling_window')
   response.String='4 查看运行状态';mechanism.String='5 查看采样窗口';run.String='2 运行三组窗口对照';
   status.String='默认每组0.05秒；两参数均按0.0625μs设置，三组共同应用。完整记录采样来源和门极，结束恢复固定参考。';
  end
  if strcmp(s.id,'encoder_angle')
   currents.String='3 查看dq电流';mechanism.String='5 查看编码器角度';response.String='4 查看运行状态';run.String='2 运行三组角度对照';
   startup.String='6 展开编码器模块';startup.Enable='on';description.String=[s.question newline '原模型临时接入；速度仍走原路径。10000计数来自固件，延迟为演示值。'];
   status.String='默认每组0.05秒。可单独修改计数、整数延迟拍数及电角零位；展开模块后，恢复参考或运行实验会自动移除临时模块。';
  end
  if ismember(s.id,{'encoder_speed','speed_feedback','speed_filter'})
   currents.String='3 查看测速对照';mechanism.String='5 查看差分窗口';response.String='4 查看运行状态';run.String='2 运行一次并行观测';
   startup.String='6 展开测速模块';startup.Enable='on';description.String=[s.question newline '三路窗口共用同一轨迹，只观测，速度环反馈保持原路径。'];
   status.String='默认运行0.05秒，三种窗口并行记录。输入计数、差分窗口和长窗口；历史不足会标无效。没有速度滤波或测速反馈接管。';
  end
  if strcmp(s.id,'speed_feedback')
   currents.String='3 查看反馈与给定';mechanism.String='5 查看启动与来源';run.String='2 运行三组反馈对照';startup.String='6 展开反馈选择';
   description.String=[s.question newline '三组：原速度、窗口测速、长窗测速；角度不变，速度滤波关闭。'];
   status.String='默认每组0.05秒。计数反馈接原速度保持之前；历史不足用零，不回填真值。可展开选择开关阅读。';
  end
  if strcmp(s.id,'speed_filter')
   zeroLabel.String='截止频率';zeroUnit.String='Hz';currents.String='3 查看滤波与给定';mechanism.String='5 查看平滑与滞后';run.String='2 运行两组滤波对照';startup.String='6 展开速度滤波';
   description.String=[s.question newline '固定测速窗口，原速度PI与角度保持；只切换速度滤波。'];
   status.String='默认每组0.1秒，以观察限幅退出后的响应。200Hz来自源码配置，未实测；20kHz滤波，10kHz速度PI。';
  end
 end
 function invalidate
  status.String='参数已更改，请运行当前设置。';last=[];currents.Enable='off';response.Enable='off';mechanism.Enable='off';startup.Enable='off';f.UserData=[];
  if ismember(catalog(selector.Value).id,{'encoder_angle','encoder_speed','speed_feedback','speed_filter'}),startup.Enable='on';end
 end
 function restoreReference
  try,pmsm_presented_call(@restoreFixed);status.String='已恢复完整参考，尚未运行。当前因素大小仅用于下一次实验，不改变参考档案。';
  catch err,status.String=['未恢复：' err.message];end
 end
 function runExperiment
  controls=[selector value cutoff zero restore run currents response mechanism startup];set(controls,'Enable','off');status.String='正在运行固定对照实验，请等待；主模型不保存覆盖。';drawnow;
  try
   parameter=value.String;
   if ismember(catalog(selector.Value).id,{'noise_filter','sampling_window'}),parameter=[str2double(value.String) str2double(cutoff.String)];end
   if ismember(catalog(selector.Value).id,{'encoder_angle','encoder_speed','speed_feedback','speed_filter'}),parameter=[str2double(value.String) str2double(cutoff.String) str2double(zero.String)];end
   last=pmsm_presented_call(@runFixed,catalog(selector.Value).id,parameter);f.UserData=last;
   status.String=sprintf('已完成：%s，共%d组，大小%s %s。已恢复固定参考。\n结果目录：%s',last.scenario.name,numel(last.cases),mat2str(last.factor_value,4),last.factor_unit,last.folder);
   currents.Enable='on';response.Enable='on';
   if isfile(fullfile(last.folder,'mechanism.png')),mechanism.Enable='on';end
   if isfile(fullfile(last.folder,'startup.png')),startup.Enable='on';end
  catch err,last=[];f.UserData=[];status.String=['实验未完成：' err.message];end
  set([selector value cutoff zero restore run],'Enable','on');if ismember(catalog(selector.Value).id,{'encoder_angle','encoder_speed','speed_feedback','speed_filter'}),startup.Enable='on';end
 end
 function r=runFixed(id,parameter)
  restoreFixed;r=run_pmsm_experiment(id,parameter);
 end
 function restoreFixed
  if pmsm_encoder_model('installed'),pmsm_encoder_model('remove');end
  pmsm_reference('restore');
 end
 function preview
  if ~ismember(catalog(selector.Value).id,{'encoder_angle','encoder_speed','speed_feedback','speed_filter'}),show('startup.png');return;end
  try
   parameters=[str2double(value.String) str2double(cutoff.String) str2double(zero.String)];
   if strcmp(catalog(selector.Value).id,'speed_filter'),pmsm_presented_call(@pmsm_speed_filter_view,parameters);elseif strcmp(catalog(selector.Value).id,'speed_feedback'),pmsm_presented_call(@pmsm_speed_feedback_view,parameters);elseif strcmp(catalog(selector.Value).id,'encoder_speed'),pmsm_presented_call(@pmsm_encoder_speed_view,parameters);else,pmsm_presented_call(@pmsm_encoder_view,parameters);end
   status.String='已展开原模型中的临时模块。恢复参考或运行实验会自动移除；无需保存SLX。';
  catch err,status.String=['模块未打开：' err.message];end
 end
 function show(name)
  if isempty(last),return;end
  try
   pmsm_experiment_verify(last.folder);pmsm_show_report(last.folder,{name,last.scenario.name},[last.scenario.name ' | ' last.id]);
  catch err,status.String=['报告未打开：' err.message];end
 end
end
