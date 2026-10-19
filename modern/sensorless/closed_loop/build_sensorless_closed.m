function report=build_sensorless_closed
% Direct sensorless FOC adaptation, preserving the accepted observer core.
here=fileparts(mfilename('fullpath'));addpath(fullfile(fileparts(here),'direct'));base=sensorless_direct_setup;addpath(here);
old='PMSM_FOC_R2026a';mdl='PMSM_SMO_ClosedLoop';folder=fullfile(base,'models','closed_loop');
if ~isfolder(folder),mkdir(folder);end
file=fullfile(folder,[mdl '.slx']);
source=fullfile(base,'models','direct',[old '.slx']);load_system(source);cleanup=onCleanup(@()close_private(old,mdl)); %#ok<NASGU>
save_system(old,file);set_param(0,'CurrentSystem',mdl);
% Dynamic tracking requirement for the local closed-loop adaptation.
set_param([mdl '/无感观测'],'pll_fn_hz','150');pmsm_sensorless_v2_init(mdl);
obsCfg=getVariable(get_param(mdl,'ModelWorkspace'),'sless_cfg');
set_param([mdl '/无感观测'],'derived_kp',num2str(obsCfg(11),17),'derived_ki',num2str(obsCfg(12),17));
ws=get_param(mdl,'ModelWorkspace');Ts=getVariable(ws,'dt');sample=getVariable(ws,'timing_control_sample');
cfg=[Ts sample(2) getVariable(ws,'p') .04 .06 .14 1200 6 6 .18 .02 .04 .02 .08 ...
 getVariable(ws,'kp_w') getVariable(ws,'ki_w') getVariable(ws,'ks_w') getVariable(ws,'uplimit_w') getVariable(ws,'Kt') 2];
assignin(ws,'sless_closed_cfg',cfg);
root=[mdl '/闭环控制'];add_block('built-in/SubSystem',root,'Position',[2280 1400 2480 1480],'BackgroundColor','[0.78 0.92 0.88]');
obs=[mdl '/无感观测'];
for k=1:2
 tags={'SLessV2_publication','SLessV2_control_permit'};names={'观测数据','观测许可'};
 add_block('simulink/Signal Routing/From',[obs '/导出_' names{k}],'GotoTag',tags{k},'Position',[1000 500+60*k 1190 525+60*k]);
 add_block('built-in/Outport',[obs '/' names{k}],'Port',num2str(k),'Position',[1250 500+60*k 1280 520+60*k]);
 add_line(obs,['导出_' names{k} '/1'],[names{k} '/1']);
 add_block('built-in/Inport',[root '/' names{k}],'Port',num2str(k),'Position',[20 80+60*k 50 100+60*k]);
 add_line(mdl,['无感观测/' num2str(k)],['闭环控制/' num2str(k)],'autorouting','on');
end
add_block('built-in/Inport',[root '/转速目标'],'Port','3','Position',[20 320 50 340]);
add_line(mdl,'speed_ref/1','闭环控制/3','autorouting','on');
add_block('simulink/Sources/Digital Clock',[root '/控制时刻'],'SampleTime','timing_control_sample','Position',[20 50 150 75]);
add_block('simulink/Sources/Constant',[root '/启动与调节参数'],'Value','sless_closed_cfg','VectorParams1D','off','Position',[20 380 170 405]);
chartPath=[root '/启动与无感调节'];add_block('simulink/User-Defined Functions/MATLAB Function',chartPath,'Position',[260 60 500 460]);
rt=sfroot;c=rt.find('-isa','Stateflow.EMChart','Path',chartPath);c.Script=fileread(fullfile(here,'sless_closed_control_block.m'));
c.ChartUpdate='DISCRETE';c.SampleTime='timing_control_sample';c.VectorOutputs1D=false;
rows={'t','1';'pub','[13 1]';'permit','1';'request','1';'cfg','[1 20]';'theta_sample','1';'theta_pwm','1';...
 'speed_feedback','1';'omega_feedback','1';'id_ref','1';'iq_ref','1';'n_ref','1';'state','1';'beta','1';'age','1';'pi_values','[4 1]'};
for k=1:size(rows,1),d=c.find('-isa','Stateflow.Data','Name',rows{k,1});d.Props.Array.Size=rows{k,2};d.DataType='double';if strcmp(rows{k,1},'permit'),d.DataType='boolean';end,end
inputs={'控制时刻','观测数据','观测许可','转速目标','启动与调节参数'};
for k=1:numel(inputs),add_line(root,[inputs{k} '/1'],['启动与无感调节/' num2str(k)],'autorouting','on');end
out={'theta_sample','theta_pwm','speed','omega','id_ref','iq_ref','reference','stage','blend','age','pi'};
for k=1:numel(out)
 y=45+55*(k-1);add_block('built-in/Outport',[root '/输出_' out{k}],'Port',num2str(k),'Position',[650 y 680 y+20]);
 add_line(root,['启动与无感调节/' num2str(k)],['输出_' out{k} '/1'],'autorouting','on');
 add_block('simulink/Signal Routing/Goto',[mdl '/发布_CL_' out{k}],'GotoTag',['CL_' out{k}],'TagVisibility','scoped','Position',[2590 1310+40*k 2800 1335+40*k]);
 add_block('simulink/Signal Routing/Goto Tag Visibility',[mdl '/闭环可见域_' out{k}],'GotoTag',['CL_' out{k}],'Position',[2840 1310+40*k 3020 1335+40*k],'ShowName','off');
 add_line(mdl,['闭环控制/' num2str(k)],['发布_CL_' out{k} '/1'],'autorouting','on');
 add_block('simulink/Sinks/To Workspace',[root '/记录_' out{k}],'VariableName',['obs_closed_' out{k}],...
  'SaveFormat','Timeseries','SampleTime','timing_control_sample','MaxDataPoints','inf','Position',[750 y 950 y+25]);
 add_line(root,['启动与无感调节/' num2str(k)],['记录_' out{k} '/1'],'autorouting','on');
end
set_param([mdl '/From1'],'GotoTag','CL_theta_sample');set_param([mdl '/From11'],'GotoTag','CL_theta_pwm');
set_param([mdl '/From3'],'GotoTag','CL_omega');set_param([mdl '/From'],'GotoTag','CL_speed');
% Feed the existing q-current reference path with the new tracking speed PI.
pi=[mdl '/PI Controller_w'];ports=get_param(pi,'PortHandles');line=get_param(ports.Outport,'Line');dest=get_param(line,'DstPortHandle');pos=get_param(pi,'Position');delete_line(line);
delete_block(pi);add_block('simulink/Signal Routing/From',[mdl '/无感q电流给定'],'GotoTag','CL_iq_ref','Position',pos);
add_block('simulink/Math Operations/Gain',[mdl '/无感转矩换算'],'Gain','Kt','Position',[560 155 620 185]);
add_line(mdl,'无感q电流给定/1','无感转矩换算/1','autorouting','on');p=get_param([mdl '/无感转矩换算'],'PortHandles');
for target=dest(:)',add_line(mdl,p.Outport,target,'autorouting','on');end
add_block('simulink/Signal Routing/Goto',[mdl '/发布速度PI观测'],'GotoTag','ObsPI_speed','TagVisibility','global','Position',[2600 1850 2800 1875]);
add_line(mdl,'闭环控制/11','发布速度PI观测/1','autorouting','on');
add_block('simulink/Sinks/To Workspace',[root '/原速度PI日志'],'VariableName','obs_pi_speed',...
 'SaveFormat','Timeseries','SampleTime','timing_control_sample','MaxDataPoints','inf','Position',[750 720 950 745]);
add_line(root,'启动与无感调节/11','原速度PI日志/1','autorouting','on');
id=[mdl '/id_ref'];pos=get_param(id,'Position');p=get_param(id,'PortHandles');line=get_param(p.Outport,'Line');dest=get_param(line,'DstPortHandle');delete_line(line);
delete_block(id);add_block('simulink/Signal Routing/From',id,'GotoTag','CL_id_ref','Position',pos);p=get_param(id,'PortHandles');
for target=dest(:)',add_line(mdl,p.Outport,target,'autorouting','on');end
set_param([mdl '/T_load1'],'Before','0','After','.207','Time','.34');
set_param(mdl,'StopTime','.5');
% Old observer Scope callbacks contain the original model name.
scopes=find_system(mdl,'LookUnderMasks','all','BlockType','Scope');
for k=1:numel(scopes),callback=get_param(scopes{k},'OpenFcn');if contains(callback,old),set_param(scopes{k},'OpenFcn',strrep(callback,old,mdl));end,end
add_native_closed_scopes(mdl);
save_system(mdl,file);
report=struct('passed',true,'simulation_started',false,'model',mdl,'model_sha256',teach_hash(file),...
 'direct_source_sha256',teach_hash(source),'config',cfg,'control_truth_inputs',false,'feedback_paths',{{'Park: CL_theta_sample','Inverse Park: CL_theta_pwm','Decoupling: CL_omega','Speed PI: published SMO rpm'}});
teach_writejson(fullfile(folder,'build.json'),report);
end
function close_private(a,b)
if bdIsLoaded(a),close_system(a,0);end
if bdIsLoaded(b),close_system(b,0);end
end
