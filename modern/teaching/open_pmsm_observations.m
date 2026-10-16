function fig=open_pmsm_observations(kind)
% Small native navigation, no custom plotting or animation.
if nargin<1,kind='time';end
here=fileparts(mfilename('fullpath'));root=fileparts(here);addpath(here,root,fullfile(root,'layout','appearance'));
assert(ismember(kind,{'time','frequency'}));
if bdIsLoaded('PMSM_FOC_R2026a')&&strcmp(get_param('PMSM_FOC_R2026a','SimulationStatus'),'stopped')
 refresh_pmsm_observation_shortcuts;
end
if strcmp(kind,'time')
 title='时域观测';note='按主题进入 · 本次仿真与已保存实验分开';
 labels={'速度控制','电流采样','死区与补偿','电流与电压','PWM与采样'};
 actions={@open_pmsm_speed_lesson,@open_pmsm_sampling_lesson,@open_pmsm_deadtime_lesson,@open_pmsm_electrical_scope,@open_pmsm_pwm_scope};
else
 fig=frequencyPanel;return;
end
fig=uifigure('Name',title,'Position',[300 180 560 max(340,100+60*numel(labels))],'Color','white');
g=uigridlayout(fig,[numel(labels)+1 1]);g.RowHeight=[{45} repmat({50},1,numel(labels))];g.Padding=[24 20 24 20];
uilabel(g,'Text',note,'FontSize',17);
for k=1:numel(labels),fun=actions{k};uibutton(g,'Text',labels{k},'FontSize',18,'ButtonPushedFcn',@(~,~)launch(fun,fig,kind));end
end
function fig=frequencyPanel
fig=uifigure('Name','频域分析','Position',[300 180 680 530],'Color','white');
outer=uigridlayout(fig,[1 1]);outer.Padding=[16 16 16 16];
tabs=uitabgroup(outer);current=uitab(tabs,'Title','本次仿真');lessons=uitab(tabs,'Title','教学实验');tabs.SelectedTab=current;
g=uigridlayout(current,[4 1]);g.RowHeight={42,58,42,'1x'};g.Padding=[22 18 22 18];
uilabel(g,'Text','数据来源：最近一次仿真输出','FontSize',17);
uibutton(g,'Text','电流频谱','FontSize',18,'Tooltip','读取工作区out，查看三相电流、FFT与功率谱密度。',...
 'ButtonPushedFcn',@(~,~)launch(@open_pmsm_current_analysis,fig,'frequency'));
uilabel(g,'Text','看三相电流，以及各频率成分的大小。','FontSize',15);
g=uigridlayout(lessons,[7 2]);g.ColumnWidth={160,'1x'};g.RowHeight=[{42} repmat({58},1,6)];g.Padding=[22 18 22 18];
label=uilabel(g,'Text','已保存的实验，不随本次模型运行更新','FontSize',17);label.Layout.Column=[1 2];
labels={'d轴电流环','q轴电流环','速度阶跃','速度频响','谐波对比','噪声频谱'};
descriptions={'看不同频率下的电流跟随与相位变化',...
 '锁住转子，只看q轴电流控制',...
 '看给定突变后的跟踪、超调和稳定时间',...
 '看20、80、250 Hz下的速度跟随',...
 '对比已保存实验中的电流频谱',...
 '看噪声能量主要分布在哪些频率'};
actions={@open_pmsm_current_frequency,@open_pmsm_q_frequency,@open_pmsm_speed_step,...
 @open_pmsm_speed_probe,@open_pmsm_spectrum,@open_pmsm_noise_spectrum};
for k=1:numel(labels)
 fun=actions{k};b=uibutton(g,'Text',labels{k},'FontSize',18,'Tooltip',['已保存的教学实验：' descriptions{k}],...
  'ButtonPushedFcn',@(~,~)launch(fun,fig,'frequency'));b.Layout.Row=k+1;b.Layout.Column=1;
 label=uilabel(g,'Text',descriptions{k},'FontSize',15);label.Layout.Row=k+1;label.Layout.Column=2;
end
end
function launch(fun,fig,kind)
try
 if strcmp(kind,'time')&&pmsm_observation_view('installed'),pmsm_observation_view('remove');end
 guard=onCleanup(@()refresh(kind));
 out=fun();
 if strcmp(kind,'frequency')&&isgraphics(out,'figure'),set(out,'Units','pixels','Position',[80 60 1120 800]);end
 if strcmp(kind,'time'),pmsm_observation_view('install');end
catch err,uialert(fig,err.message,'观测未打开');end
end
function refresh(kind)
if strcmp(kind,'time')&&bdIsLoaded('PMSM_FOC_R2026a'),pmsm_observation_view('install');end
end
