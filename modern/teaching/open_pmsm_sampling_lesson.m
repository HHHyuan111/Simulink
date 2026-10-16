function fig=open_pmsm_sampling_lesson
% One small teaching entry, using existing signals and sealed experiments.
here=fileparts(mfilename('fullpath'));root=fileparts(here);addpath(root,fullfile(root,'layout','appearance'));
fig=uifigure('Name','电流采样','Color','white','Position',[300 100 700 620]);
g=uigridlayout(fig,[9 1]);g.RowHeight={36,36,50,50,50,50,50,32,50};g.Padding=[24 20 24 20];
uilabel(g,'Text','真实电流 → 采样与反馈 → 闭环影响','FontSize',18);
uilabel(g,'Text','本次仿真：打开Scope后，在模型中点击“运行”。','FontSize',16);
uibutton(g,'Text','采样设置','FontSize',18,'Tag','sampling_lesson_settings','ButtonPushedFcn',@(~,~)settings);
uibutton(g,'Text','当前采样链','FontSize',18,'Tag','sampling_lesson_current',...
 'Tooltip','复用原生Scope，同轴比较A相真实、采样保持与反馈；同时观察三相电流和ADC事件。',...
 'ButtonPushedFcn',@(~,~)launch(@open_pmsm_current_sampling_scope));
pmsm_user_run_buttons(g,'sampling');
uilabel(g,'Text','内置示例：固定工况，不随当前参数更新。','FontSize',16);
uibutton(g,'Text','内置示例','FontSize',18,'Tag','sampling_lesson_compare',...
 'Tooltip','默认看噪声与滤波；图窗“教学对比”菜单切换采样、PWM和死区主题，不自动仿真。',...
 'ButtonPushedFcn',@(~,~)launch(@open_pmsm_sampling_comparison));
 function launch(fun)
  try,fun();catch err,uialert(fig,err.message,'观测未打开');end
 end
 function settings
  try
   if ~bdIsLoaded('PMSM_FOC_R2026a'),open_pmsm_model;end
   open_system('PMSM_FOC_R2026a/采样设置','mask');
  catch err,uialert(fig,err.message,'设置未打开');end
 end
end
