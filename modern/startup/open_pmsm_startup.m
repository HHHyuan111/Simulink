function scope=open_pmsm_startup
% Prepare the original model for manual Run and mask editing; no auto simulation.
here=fileparts(mfilename('fullpath'));root=fileparts(here);
addpath(here,root,fullfile(root,'teaching'),fullfile(root,'framework'),fullfile(root,'layout','appearance'));
scope=pmsm_presented_call(@prepare);
open_system('PMSM_FOC_R2026a');open_system(scope);
pmsm_startup_scope_style(scope);
end
function scope=prepare
mdl='PMSM_FOC_R2026a';here=fileparts(mfilename('fullpath'));root=fileparts(here);p=pmsm_system_plan;
if ~bdIsLoaded(mdl),load_system(fullfile(root,[mdl '.slx']));pmsm_reference('restore');end
if pmsm_startup_model('installed',mdl),scope=[mdl '/启停/启停观测'];return;end
assert(isequaln(pmsm_reference('capture'),p.baseline_state),'请先用工作台恢复固定参考，保留当前自定义设置后再打开启停演示。');
try
 for c=p.cases(2).changes(:)',set_param([mdl '/' c.section],c.parameter,c.value);end
 set_param([mdl '/功率设置'],'gate_on','on','gate_us','0','comp_on','off');
 pmsm_encoder_model('install');pmsm_encoder_speed_model('install');pmsm_speed_feedback_model('install');pmsm_speed_filter_model('install');
 cfgs={p.encoder_configurations(2),p.speed_configuration,p.feedback_configurations(2),p.filter_configurations(2)};
 paths={'角度设置/编码器','角度设置/编码器/测速','速度反馈','速度反馈/速度滤波'};
 for j=1:4,for key=fieldnames(cfgs{j})',set_param([mdl '/' paths{j}],key{1},cfgs{j}.(key{1}));end,end
 pmsm_system_inputs('install',mdl,p.input_schedule);pmsm_startup_model('install');
 set_param([mdl '/启停'],'start_ms','0','stop_ms','15','restart_ms','20');set_param(mdl,'StopTime','0.03');
 parent=[mdl '/启停'];scope=[parent '/启停观测'];
 add_block('simulink/Sinks/Scope',scope,'NumInputPorts','4','Position',[1240 100 1330 420]);
 add_block('simulink/Signal Routing/Mux',[parent '/许可观测'],'Inputs','3','Position',[1110 150 1115 300]);
 labels={'电流环','速度环','PWM'};
 for k=1:3,line=add_line(parent,['许可' num2str(k) '/1'],['许可观测/' num2str(k)],'autorouting','on');set_param(line,'Name',labels{k});end
 add_block('simulink/Signal Routing/From',[parent '/转速观测'],'GotoTag','speed','Position',[1000 460 1100 485]);
 add_block('simulink/Signal Routing/Mux',[parent '/电流观测'],'Inputs','2','Position',[1110 530 1115 630]);
 for row={'id','d轴',1;'iq','q轴',2}'
  add_block('simulink/Signal Routing/From',[parent '/' row{2}],'GotoTag',row{1},'Position',[950 510+50*row{3} 1050 535+50*row{3}]);
  line=add_line(parent,[row{2} '/1'],['电流观测/' num2str(row{3})],'autorouting','on');set_param(line,'Name',row{1});
 end
 sources={'状态包/1','许可观测/1','转速观测/1','电流观测/1'};
 for k=1:4,add_line(parent,sources{k},['启停观测/' num2str(k)],'autorouting','on');end
 c=get_param(scope,'ScopeConfiguration');c.Name='启停观测';c.Position=[80 60 1120 800];c.LayoutDimensions=[2 2];c.FrameBasedProcessing=false;c.TimeUnits='Seconds';c.TimeSpan='0.03';c.OpenAtSimulationStart=true;
 set_param(scope,'StopFcn',sprintf('pmsm_startup_scope_style(''%s'');',scope));
 titles={'状态','执行许可','转速','反馈电流'};units={'状态编号','0 / 1','rpm','A'};
 for k=1:4,c.ActiveDisplay=num2str(k);c.Title=titles{k};c.YLabel=units{k};c.ShowGrid=true;c.ShowLegend=ismember(k,[2 4]);c.AxesScaling='Auto';end
 c.ActiveDisplay='1';
catch err
 if pmsm_startup_model('installed'),pmsm_startup_model('remove');end
 if pmsm_system_inputs('installed',mdl),pmsm_system_inputs('remove',mdl);end
 if pmsm_encoder_model('installed'),pmsm_encoder_model('remove');end
 pmsm_reference('restore');rethrow(err);
end
end
