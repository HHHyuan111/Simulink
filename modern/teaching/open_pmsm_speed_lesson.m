function fig=open_pmsm_speed_lesson
% Reuse native observation and verified archives; no simulation or tuning.
here=fileparts(mfilename('fullpath'));root=fileparts(here);addpath(root,fullfile(root,'layout','appearance'));
fig=uifigure('Name','速度控制','Color','white','Position',[300 100 700 620]);
g=uigridlayout(fig,[9 1]);g.Padding=[24 20 24 20];g.RowHeight={36,36,50,50,50,50,32,50,50};
uilabel(g,'Text','转速跟踪 → 电流响应 → 转矩变化','FontSize',18);
uilabel(g,'Text','本次仿真：打开Scope后，在模型中点击“运行”。','FontSize',16);
uibutton(g,'Text','当前控制响应','FontSize',18,'Tag','speed_lesson_current',...
 'Tooltip','复用现有原生Scope：转速、id、iq、转矩；比较量同轴，共用时间。',...
 'ButtonPushedFcn',@(~,~)launch(@open_pmsm_control_scope));
pmsm_user_run_buttons(g,'speed');
uilabel(g,'Text','内置示例：固定工况，不随当前参数更新。','FontSize',16);
uibutton(g,'Text','阶跃示例','FontSize',18,'Tag','speed_lesson_step',...
 'Tooltip','已有20rpm小阶跃档案；在同一窗口看转速、电流、转矩和误差。',...
 'ButtonPushedFcn',@(~,~)launch(@open_pmsm_speed_step));
uibutton(g,'Text','正弦示例','FontSize',18,'Tag','speed_lesson_sine',...
 'Tooltip','已有80Hz、10rpm幅值档案；同屏看转速、电流、转矩和误差。',...
 'ButtonPushedFcn',@(~,~)launch(@open_pmsm_speed_probe_time));
 function launch(fun)
  try
   out=fun();
   if isgraphics(out,'figure')
    set(out,'Position',[80 60 1120 800]);lines=findall(out,'Type','line');
    for line=lines(:)',if norm(line.Color-[.85 .325 .098])<1e-10,line.Color=[.84 .15 .16];end,end
   end
  catch err,uialert(fig,err.message,'观测未打开');end
 end
end
