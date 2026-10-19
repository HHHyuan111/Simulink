function add_native_closed_scopes(mdl)
% Native control-rate Scope displays. Truth enters this observation area only.
root=[mdl '/闭环结果观测'];add_block('built-in/SubSystem',root,'Position',[2280 1540 2480 1620],'BackgroundColor','[0.94 0.95 0.98]');
groups={{'speed','u(1)','电机实际';'CL_speed','u(1)','SMO反馈';'CL_reference','u(1)','速度给定'},'转速闭环','rpm';...
 {'CL_stage','u(1)','阶段';'CL_blend','u(1)','估计角权重'},'控制阶段（5=无感闭环）','';...
 {'CL_theta_sample','angle_error','控制角误差'},'控制电角度误差','°';...
 {'Currentabc','phase1','A相';'Currentabc','phase2','B相';'Currentabc','phase3','C相'},'电机相电流','A'};
for scopeIndex=1:2
 names={'闭环全过程','闭环稳态'};span={'.5','.088'};scope=[root '/' names{scopeIndex}];
 add_block('simulink/Sinks/Scope',scope,'NumInputPorts','4','SampleTime','timing_control_sample',...
  'Position',[900 60+200*scopeIndex 1070 140+200*scopeIndex]);
 config=get_param(scope,'ScopeConfiguration');config.LayoutDimensions=[2 2];config.FrameBasedProcessing=false;
 config.OpenAtSimulationStart=false;config.DataLogging=false;config.ShowLegend=true;config.TimeSpan=span{scopeIndex};
 if isprop(config,'LimitDataPoints'),config.LimitDataPoints=false;end
 for g=1:4
  config.ActiveDisplay=num2str(g);config.Title=groups{g,2};config.YLabel=groups{g,3};config.ShowGrid=true;
  rows=groups{g,1};prefix=['显示' num2str(scopeIndex) '_' num2str(g) '_'];
  bus=[root '/' prefix '合并'];add_block('simulink/Signal Routing/Bus Creator',bus,'Inputs',num2str(size(rows,1)),...
   'Position',[740 100+100*g+500*(scopeIndex-1) 745 145+100*g+500*(scopeIndex-1)]);
  for k=1:size(rows,1)
   y=60+60*k+300*g+1400*(scopeIndex-1);src=[prefix '来源' num2str(k)];pick=[prefix '信号' num2str(k)];holdName=[prefix '采样' num2str(k)];
   add_block('simulink/Signal Routing/From',[root '/' src],'GotoTag',rows{k,1},'Position',[20 y 210 y+25]);
   add_block('simulink/Discrete/Zero-Order Hold',[root '/' holdName],'SampleTime','timing_control_sample','Position',[250 y 340 y+25]);
   add_line(root,[src '/1'],[holdName '/1']);
   if strcmp(rows{k,2},'angle_error')
    truth=[prefix '真实角度'];truthHold=[prefix '真角采样'];mux=[prefix '角差输入'];
    add_block('simulink/Signal Routing/From',[root '/' truth],'GotoTag','theta_e','Position',[20 y+45 210 y+70]);
    add_block('simulink/Discrete/Zero-Order Hold',[root '/' truthHold],'SampleTime','timing_control_sample','Position',[250 y+45 340 y+70]);
    add_block('simulink/Signal Routing/Mux',[root '/' mux],'Inputs','2','Position',[400 y 405 y+65]);
    add_line(root,[truth '/1'],[truthHold '/1']);add_line(root,[holdName '/1'],[mux '/1']);add_line(root,[truthHold '/1'],[mux '/2']);
    expr='atan2(sin(u(1)-u(2)),cos(u(1)-u(2)))*180/pi';source=mux;
   elseif startsWith(rows{k,2},'phase')
    split=[prefix '分相' num2str(k)];add_block('simulink/Signal Routing/Demux',[root '/' split],'Outputs','3','Position',[420 y 425 y+60]);
    add_line(root,[holdName '/1'],[split '/1']);
    line=add_line(root,[split '/' rows{k,2}(end)],[prefix '合并/' num2str(k)],'autorouting','on');set_param(line,'Name',rows{k,3});
    continue;
   else,expr=rows{k,2};source=holdName;
   end
   add_block('simulink/User-Defined Functions/Fcn',[root '/' pick],'Expr',expr,'Position',[450 y 640 y+30]);
   add_line(root,[source '/1'],[pick '/1']);line=add_line(root,[pick '/1'],[prefix '合并/' num2str(k)],'autorouting','on');set_param(line,'Name',rows{k,3});
  end
  add_line(root,[prefix '合并/1'],[names{scopeIndex} '/' num2str(g)],'autorouting','on');
 end
 config.ActiveDisplay='1';
end
end
