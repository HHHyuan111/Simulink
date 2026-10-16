function fig=open_pmsm_framework(visible)
% Navigation and controlled experiments; algorithms and reference stay fixed.
if nargin<1,visible='on';end
here=fileparts(mfilename('fullpath'));root=fileparts(here);addpath(fullfile(root,'teaching'),fullfile(root,'layout','appearance'));
fig=uifigure('Name','PMSM仿真工作台','Position',[120 80 1120 780],'Visible',visible,'Color',[.96 .97 .99]);
g=uigridlayout(fig,[6 3]);g.Padding=[24 20 24 20];g.RowSpacing=16;g.ColumnSpacing=16;
g.RowHeight={50,55,'1x',55,55,85};g.ColumnWidth={'1x','1x','1x'};
label=uilabel(g,'Text','PMSM 仿真工作台','FontSize',25,'FontWeight','bold');label.Layout.Row=1;label.Layout.Column=[1 3];
nav={'打开模型','单项实验','参数与开关'};fun={@openModel,@openExperiments,@()open_pmsm_controls};
for k=1:3,b=uibutton(g,'Text',nav{k},'FontSize',16,'ButtonPushedFcn',@(~,~)fun{k}());b.Layout.Row=2;b.Layout.Column=k;end
help=uimenu(fig,'Text','帮助');uimenu(help,'Text','体验清单','MenuSelectedFcn',@(~,~)edit(fullfile(here,'体验清单.md')));
 data={'控制与电机','FOC、前馈、限压、SVPWM、PMSM','已建立';...
 '功率级','死区、续流、压降、基础补偿','可做单项对照';...
 '采样与时序','ADC、任务频率、CCR、有效窗口','可做单项对照';...
 '位置与速度','编码器角度、计数测速、速度滤波','可做单项对照';...
 '整机运行','组合反馈、变速、增载、平台判定','两组基线已验证';...
 '启停与保护','启停接管、电角定位、故障保护','待开发'};
t=uitable(g,'Data',data,'ColumnName',{'部分','功能','进度'},'ColumnWidth',{150,'auto',195},'RowName',{},'FontSize',16);t.Layout.Row=3;t.Layout.Column=[1 3];
run=uibutton(g,'Text','运行整机基线','FontSize',16,'BackgroundColor',[.15 .42 .69],'FontColor','white','ButtonPushedFcn',@(~,~)runSystem);run.Layout.Row=4;run.Layout.Column=1;
b=uibutton(g,'Text','查看整机结果','FontSize',16,'ButtonPushedFcn',@(~,~)showResult);b.Layout.Row=4;b.Layout.Column=2;
b=uibutton(g,'Text','恢复固定参考','FontSize',16,'ButtonPushedFcn',@(~,~)restore);b.Layout.Row=4;b.Layout.Column=3;
hint=uilabel(g,'Text','先用单项实验理解一个因素，再用整机基线查看组合运行。电机及硬件参数尚待实测校准。','FontSize',15,'WordWrap','on');hint.Layout.Row=5;hint.Layout.Column=[1 3];
status=uitextarea(g,'Value',{'就绪。打开模型会自动应用整理后的布局。','实验自动从固定参考运行，结果逐次存档。'},'Editable','off','FontSize',15);status.Layout.Row=6;status.Layout.Column=[1 3];
 function openModel
  try,open_pmsm_model;status.Value={'模型已打开。可双击设置模块，查看具体开关和内部链路。'};catch err,fail(err);end
 end
 function openExperiments
  open_pmsm_experiments;
 end
 function restore
  try,pmsm_presented_call(@restoreCompute);status.Value={'固定参考已恢复，当前仍显示整理后的布局。'};catch err,fail(err);end
 end
 function restoreCompute
  mdl='PMSM_FOC_R2026a';if bdIsLoaded(mdl)
   if pmsm_system_inputs('installed',mdl),pmsm_system_inputs('remove',mdl);end
   if pmsm_encoder_model('installed',mdl),pmsm_encoder_model('remove',mdl);end
  end
  pmsm_reference('restore');
 end
 function runSystem
  buttons=findall(fig,'Type','uibutton');set(buttons,'Enable','off');status.Value={'正在运行两组整机实验。','实际计算可能需要十余分钟；完成后自动恢复参考并打开结果。'};drawnow;
  cleanup=onCleanup(@()set(buttons(isvalid(buttons)),'Enable','on'));
  try,r=pmsm_presented_call(@runPrepared);status.Value={['已完成：' r.id],'参考已恢复，原始数据及图片已存档。'};showResult;
  catch err,status.Value={'运行未完成，已产生的原始档案保留。',err.message};uialert(fig,err.message,'整机实验失败');end
 end
 function r=runPrepared
  restoreCompute;r=run_pmsm_system_baseline;
 end
 function showResult
  try
   latest=jsondecode(fileread(fullfile(here,'latest.json')));verify_pmsm_system_baseline(latest.folder);
   pmsm_show_report(latest.folder,{'response.png','整机响应';'feedback.png','反馈链路';'currents.png','三相电流'},'整机实验结果');
  catch err,fail(err);end
 end
 function fail(err),status.Value={err.message};uialert(fig,err.message,'操作未完成');end
end
