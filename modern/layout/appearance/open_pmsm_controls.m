function f=open_pmsm_controls(section)
% Readable parameter editor over the existing validated configuration API.
if nargin<1,section='';end
here=fileparts(mfilename('fullpath'));root=fileparts(fileparts(here));addpath(here,fullfile(root,'teaching'));
config=pmsm_config('read');sections=unique({config.rows.section},'stable');selected=1;
f=uifigure('Name','PMSM 参数与开关','Position',[90 70 1240 820],'Color',[.96 .97 .99]);
g=uigridlayout(f,[6 4]);g.Padding=[24 20 24 20];g.ColumnWidth={'1x','1x','1x','1x'};g.RowHeight={45,48,'1x',150,48,55};g.RowSpacing=14;
title=uilabel(g,'Text','参数与开关','FontSize',25,'FontWeight','bold');title.Layout.Column=[1 4];
selector=uidropdown(g,'Items',sections,'FontSize',16,'ValueChangedFcn',@(~,~)refresh);selector.Layout.Row=2;selector.Layout.Column=[1 2];
if ismember(section,sections),selector.Value=section;end
b=uibutton(g,'Text','从模型读取','FontSize',15,'ButtonPushedFcn',@(~,~)readModel);b.Layout.Row=2;b.Layout.Column=3;
b=uibutton(g,'Text','展开模块','FontSize',15,'ButtonPushedFcn',@(~,~)openBlock);b.Layout.Row=2;b.Layout.Column=4;
t=uitable(g,'ColumnName',{'参数','当前值','单位','校准状态'},'ColumnEditable',[false true false false], ...
 'ColumnWidth',{340,300,220,'auto'},'RowName',{},'FontSize',16,'CellEditCallback',@editValue,'CellSelectionCallback',@selectRow);t.Layout.Row=3;t.Layout.Column=[1 4];
details=uitextarea(g,'Editable','off','FontSize',15);details.Layout.Row=4;details.Layout.Column=[1 3];
togglePanel=uipanel(g,'Title','选中开关','FontSize',15);togglePanel.Layout.Row=4;togglePanel.Layout.Column=4;
tg=uigridlayout(togglePanel,[2 1]);tg.RowHeight={45,'1x'};toggleLabel=uilabel(tg,'FontSize',14,'WordWrap','on');
toggle=uiswitch(tg,'slider','Items',{'off','on'},'FontSize',15,'ValueChangedFcn',@toggleValue);
b=uibutton(g,'Text','关闭附加因素','FontSize',15,'ButtonPushedFcn',@(~,~)preset('reference'));b.Layout.Row=5;b.Layout.Column=1;
b=uibutton(g,'Text','教学预设','FontSize',15,'ButtonPushedFcn',@(~,~)preset('teaching'));b.Layout.Row=5;b.Layout.Column=2;
b=uibutton(g,'Text','恢复固定参考','FontSize',15,'ButtonPushedFcn',@(~,~)restore);b.Layout.Row=5;b.Layout.Column=3;
b=uibutton(g,'Text','应用到模型','FontSize',15,'BackgroundColor',[.15 .42 .69],'FontColor','white','ButtonPushedFcn',@(~,~)apply);b.Layout.Row=5;b.Layout.Column=4;
status=uilabel(g,'Text','已读取模型。编辑当前值，点击“应用到模型”后生效；开关填写 on / off。','FontSize',15,'WordWrap','on');status.Layout.Row=6;status.Layout.Column=[1 4];
menu=uimenu(f,'Text','参数档案');uimenu(menu,'Text','保存 JSON','MenuSelectedFcn',@(~,~)saveProfile);uimenu(menu,'Text','载入 JSON','MenuSelectedFcn',@(~,~)loadProfile);
refresh;
 function refresh
  config=pmsm_sampling_labels(config);
  ix=find(strcmp({config.rows.section},selector.Value));t.UserData=ix;
  t.Data=cell(numel(ix),4);for j=1:numel(ix),r=config.rows(ix(j));t.Data(j,:)={r.label,displayValue(r.value),r.unit,r.status};end
  selected=ix(1);describe;
 end
 function selectRow(~,e)
  if isempty(e.Indices),return;end;selected=t.UserData(e.Indices(1));describe;
 end
 function describe
  r=config.rows(selected);details.Value={r.label,['精确值：' r.value],['来源：' r.source],['测量与使用：' r.measurement], ...
   '开关用 on / off；数值用数字或一行向量。这里显示的是当前编辑内容，应用后才改变模型。'};
  isSwitch=ismember(r.value,{'on','off'});toggle.Visible=isSwitch;
  if isSwitch,toggle.Value=r.value;toggleLabel.Text=r.label;else,toggleLabel.Text='选中开关行可切换；数值直接在表格中编辑。';end
 end
 function toggleValue(~,~)
  config.rows(selected).value=toggle.Value;k=find(t.UserData==selected);t.Data{k,2}=toggle.Value;
  status.Text='开关已修改，尚未应用。点击“应用到模型”生效。';describe;
 end
 function editValue(~,e)
  k=t.UserData(e.Indices(1));config.rows(k).value=char(string(e.NewData));selected=k;describe;status.Text='有未应用的修改。点击“应用到模型”进行检查并生效。';
 end
 function readModel,config=pmsm_config('read');refresh;status.Text='已从模型重新读取。';end
 function preset(role),config=pmsm_config('preset',role);refresh;status.Text='已预览局部预设，尚未应用。';end
 function apply
  try,config=pmsm_presented_call(@pmsm_config,'apply',config);refresh;status.Text='参数已应用并通过模型更新检查；旧设置已自动备份。';catch err,fail(err);end
 end
 function restore
  try,pmsm_presented_call(@restoreCompute);readModel;status.Text='完整固定参考已恢复，布局保留。';catch err,fail(err);end
 end
 function restoreCompute
  if pmsm_encoder_model('installed'),pmsm_encoder_model('remove');end;pmsm_reference('restore');
 end
 function openBlock
  path=['PMSM_FOC_R2026a/' selector.Value];
  if getSimulinkBlockHandle(path)>0
   if pmsm_presentation('installed'),pmsm_signal_chain_view('refresh');end
   open_system(path,'force');set_param(path,'ZoomFactor','100');
   first='';if strcmp(selector.Value,'采样设置'),first=[path '/真实电流'];elseif strcmp(selector.Value,'角度设置'),first=[path '/真实角度'];end
   if ~isempty(first),Simulink.scrollToVisible(get_param(first,'Handle'),'ensureFit','off','panMode','minimal');end
  else,status.Text='这组参数在模型工作区中，未对应一个独立模块。';end
 end
 function saveProfile
  [name,folder]=uiputfile('*.json','保存参数档案');if isequal(name,0),return;end;teach_writejson(fullfile(folder,name),config);status.Text='编辑内容已保存为 JSON 参数档案。';
 end
 function loadProfile
  [name,folder]=uigetfile('*.json','载入参数档案');if isequal(name,0),return;end
  try,c=jsondecode(fileread(fullfile(folder,name)));assert(c.schema==1&&numel(c.rows)==numel(config.rows));config=c;refresh;status.Text='档案已载入，尚未应用。';catch err,fail(err);end
 end
 function fail(err),status.Text=err.message;uialert(f,err.message,'参数检查');end
end
function text=displayValue(text)
% Compact display only. The unchanged configuration retains full precision.
if isempty(regexp(text,'^\s*\[?\s*[-+0-9.eE,;\s]+\]?\s*$','once')),return;end
tokens=regexp(strtrim(regexprep(text,'[\[\],;]',' ')),'\s+','split');values=str2double(tokens);
if all(isfinite(values)),text=mat2str(values,6);end
end
