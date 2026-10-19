function finish_sensorless_style(mdl)
% Finish presentation without touching numerical block parameters.
old=[mdl '/Validation logging'];
if getSimulinkBlockHandle(old)>0,set_param(old,'Name','数据记录');end
if getSimulinkBlockHandle([mdl '/数据记录'])>0
    set_param([mdl '/数据记录'],'Position',[1020 890 1200 945], ...
        'BackgroundColor','[0.95 0.95 0.95]','FontName','Microsoft YaHei','FontSize','10');
end
set_param([mdl '/测量观测'],'Position',[1020 795 1200 850]);
% Divide the PLL computation into readable, equation-level pages.
p=[mdl '/无感观测/锁相环/归一化PLL/条件积分与限速'];
if getSimulinkBlockHandle([p '/积分系数'])>0
    sections={...
      '积分试算',{'积分系数','积分增量','试算积分','比例项','试算速度'}; ...
      '抗饱和积分',{'试算绝对值','未超限','实际积分变化','饱和方向','退出饱和','积分许可','条件积分','运行积分'}; ...
      '速度选择与限幅',{'校正速度','速度保持','负速度限值','上限钳位','双向限速','速度绝对值','限速标志'}};
    for k=1:size(sections,1)
        names=sections{k,2};handles=cellfun(@(n)get_param([p '/' n],'Handle'),names);
        Simulink.BlockDiagram.createSubSystem(handles);
        path=get_param(handles(1),'Parent');set_param(path,'Name',sections{k,1});
        path=[p '/' sections{k,1}];Simulink.BlockDiagram.arrangeSystem(path,'FullLayout','true');
        set_param(path,'BackgroundColor','white','FontName','Microsoft YaHei','FontSize','10','ZoomFactor','FitSystem');
    end
    Simulink.BlockDiagram.arrangeSystem(p,'FullLayout','true');
end
% Keep the frequently used page in view; scope declarations remain below it.
route_sensorless_pages(mdl);
polish_sensorless_layout(mdl);
set_param(mdl,'ZoomFactor','80');
set_param([mdl '/无感观测'],'ZoomFactor','90');
end
