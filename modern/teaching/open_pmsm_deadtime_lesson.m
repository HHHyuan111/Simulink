function fig=open_pmsm_deadtime_lesson
here=fileparts(mfilename('fullpath'));root=fileparts(here);addpath(root,fullfile(root,'layout','appearance'));
if ~bdIsLoaded('PMSM_FOC_R2026a'),open_pmsm_model;end
fig=uifigure('Name','死区教学','Color','white','Position',[300 70 700 700]);
g=uigridlayout(fig,[11 1]);g.RowHeight={36,40,50,50,50,50,50,50,50,32,50};g.Padding=[24 20 24 20];
uilabel(g,'Text','门极与电压 → 电流与转矩 → 补偿作用','FontSize',18);
uilabel(g,'Text','本次仿真：改功率设置、打开Scope，再运行。','FontSize',16);
uibutton(g,'Text','功率设置','FontSize',18,'ButtonPushedFcn',@(~,~)open_system('PMSM_FOC_R2026a/功率设置','mask'));
uibutton(g,'Text','门极与电压','FontSize',18,'ButtonPushedFcn',@(~,~)showScope('gates'));
uibutton(g,'Text','电流与转矩','FontSize',18,'ButtonPushedFcn',@(~,~)showScope('effects'));
uibutton(g,'Text','补偿作用','FontSize',18,'ButtonPushedFcn',@(~,~)showScope('compensation'));
pmsm_user_run_buttons(g,'power');
uilabel(g,'Text','内置示例：600rpm、2μs，不代表本次运行。','FontSize',16);
uibutton(g,'Text','内置补偿示例','FontSize',18,'Tooltip','读取已保存的600rpm、2μs同工况实验；不代表本次运行。','ButtonPushedFcn',@(~,~)compare);
 function showScope(view)
  try,pmsm_deadtime_scope('open','PMSM_FOC_R2026a',view);catch err,uialert(fig,err.message,'观测未打开');end
 end
 function compare
  try,open_pmsm_deadtime_comparison;catch err,uialert(fig,err.message,'对比未打开');end
 end
end
