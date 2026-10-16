function f=open_pmsm_settings
% One window for implemented model knobs, metadata and JSON profiles.
folder=fileparts(mfilename('fullpath'));addpath(folder);config=pmsm_config('read');
f=figure('Name','PMSM 参数设置','NumberTitle','off','MenuBar','none','ToolBar','none','Position',[80 80 1250 730],'Color','white');
uicontrol(f,'Style','text','Units','normalized','Position',[.02 .93 .96 .045],'String','先选预设或修改表格，再点击“应用到模型”。保存模型后参数与来源才会写入SLX。','HorizontalAlignment','left','BackgroundColor','white','FontSize',11);
sections=unique({config.rows.section},'stable');selector=uicontrol(f,'Style','popupmenu','Units','normalized','Position',[.02 .865 .17 .045],'String',sections,'Callback',@(~,~)refresh());
for k=1:3
 names={'关闭附加因素','教学预设 2μs','实板参考（未校准）'};roles={'reference','teaching','board'};
 uicontrol(f,'Style','pushbutton','Units','normalized','Position',[.21+(k-1)*.16 .865 .15 .05],'String',names{k},'Callback',@(s,e)preset(roles{k}));
end
uicontrol(f,'Style','pushbutton','Units','normalized','Position',[.71 .865 .12 .05],'String','从模型读取','Callback',@(~,~)readModel());
uicontrol(f,'Style','pushbutton','Units','normalized','Position',[.85 .865 .13 .05],'String','应用到模型','Callback',@(~,~)apply());
t=uitable(f,'Units','normalized','Position',[.02 .18 .96 .66],'ColumnName',{'参数','当前值','单位','来源/测量记录','校准状态','怎么测 / 使用说明'}, ...
 'ColumnEditable',[false true false true true false],'ColumnWidth',{180 110 100 210 90 430},'CellEditCallback',@editCell,'RowName',[]);
uicontrol(f,'Style','pushbutton','Units','normalized','Position',[.02 .105 .14 .05],'String','保存参数档案 JSON','Callback',@(~,~)saveProfile());
uicontrol(f,'Style','pushbutton','Units','normalized','Position',[.18 .105 .14 .05],'String','载入参数档案 JSON','Callback',@(~,~)loadProfile());
uicontrol(f,'Style','pushbutton','Units','normalized','Position',[.34 .105 .15 .05],'String','打开三相电流报告','Callback',@(~,~)showReport());
uicontrol(f,'Style','pushbutton','Units','normalized','Position',[.51 .105 .18 .05],'String','恢复固定参考（整套）','Tag','RestoreFixedReference','Callback',@(~,~)restoreReference());
status=uicontrol(f,'Style','text','Units','normalized','Position',[.02 .02 .96 .065],'HorizontalAlignment','left','BackgroundColor','white','String','已读取当前模型。开关填on/off；数值填数字或一行向量。来源和校准状态由测量者填写。');
refresh();
 function refresh
  ix=find(strcmp({config.rows.section},sections{selector.Value}));data=cell(numel(ix),6);
  for j=1:numel(ix),r=config.rows(ix(j));data(j,:)={r.label,r.value,r.unit,r.source,r.status,r.measurement};end
  t.Data=data;t.UserData=ix;
 end
 function editCell(~,event)
  ix=t.UserData(event.Indices(1));fields={'','value','','source','status',''};config.rows(ix).(fields{event.Indices(2)})=char(string(event.NewData));
  status.String='表格已修改，尚未应用。实测值请同时填写来源、日期/温度等条件及校准状态。';
 end
 function preset(role)
  config=pmsm_config('preset',role);refresh();status.String=['已预览局部预设 ' role '，保留其他当前参数，点击应用才生效。回到完整起点请使用“恢复固定参考”。实板参考尚未校准。'];
 end
 function readModel
  config=pmsm_config('read');refresh();status.String='已重新读取模型，未应用的表格修改已放弃。';
 end
 function apply
  try,config=pmsm_config('apply',config);refresh();status.String='已应用并通过模型更新检查；旧设置在modern/.build/parameter_backups备份。保存模型可持久化。';
  catch err,status.String=['未应用/已回滚：' err.message];errordlg(err.message,'参数检查');end
 end
 function saveProfile
  [name,path]=uiputfile('*.json','保存当前表格的参数与测量记录');if isequal(name,0),return;end
  teach_writejson(fullfile(path,name),config);status.String='已保存表格参数档案；这一步不改变模型。';
 end
 function restoreReference
  try,pmsm_reference('restore');config=pmsm_config('read');refresh();status.String='已恢复完整固定参考并通过更新检查：参数、PI、初值和仿真设置。旧状态已备份；未运行、未保存SLX。';
  catch err,status.String=['固定参考未恢复：' err.message];errordlg(err.message,'参考版本检查');end
 end
 function loadProfile
  [name,path]=uigetfile('*.json','载入参数档案');if isequal(name,0),return;end
  try,c=jsondecode(fileread(fullfile(path,name)));assert(c.schema==1&&numel(c.rows)==numel(config.rows));config=c;refresh();status.String='档案已预览，点击应用进行校验并生效。';catch err,errordlg(err.message,'档案错误');end
 end
 function showReport
  path=fullfile(fileparts(folder),'deadtime','report_teaching','three_phase_comparison.png');
  if isfile(path),im=imread(path);g=figure('Name','三相电流对照','NumberTitle','off');ax=axes(g);image(ax,im);axis(ax,'image','off');else,errordlg('尚未生成教学报告。');end
 end
end
