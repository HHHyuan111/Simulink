function build_timing_stage3
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);addpath(fullfile(root,'teaching'));
work=fullfile(root,'.build','timing_stage');mdl='PMSM_FOC_R2026a';source=fullfile(root,[mdl '.slx']);
assert(strcmp(teach_hash(source),'a61192106edbe22425ff55814ffc3d009203baddd9fe8bfc2f245179f99e7548'));
candidate=fullfile(work,[mdl '.slx']);copyfile(source,candidate);load_system(candidate);g=onCleanup(@()close_system(mdl,0));
cached=load(fullfile(work,'before.mat'));assert(isequaln(cached.before,teach_snapshot(mdl)));
mw=get_param(mdl,'ModelWorkspace');mw.MATLABCode=[mw.MATLABCode newline ...
 'timing_on=0; timing_h=1e-6; timing_control_sample=dt; timing_speed_sample=Ts_speed; timing_static_math=-1;' newline ...
 'timing_carrier_y=[0 Ts/2 0];' newline ...
 'timing_adc_cfg=[0 0 0 1e-6 Ts 24.375e-6 1.1875e-6 1.5e-6 0 .5e-6 2];' newline ...
 'timing_pwm_cfg=[0 1e-6 Ts 24.375e-6 1.1875e-6 1.5e-6 0 5e-6 0 4000];' newline];reload(mw);
p=[mdl '/时序设置'];m=Simulink.Mask.get(p);
param(m,'real_on','checkbox','真实时序（顺序采样与CCR生效）','off');
param(m,'window_on','checkbox','低侧采样窗口（无效样本置零演示）','off');
param(m,'invalid_hold_on','checkbox','无效时保持上次有效值（策略对照）','off');
param(m,'trigger_us','edit','触发相位 [μs，24.375为待实测假设]','24.375');
param(m,'sync_us','edit','触发附加等待 [μs，演示]','0');
param(m,'compute_us','edit','JEOS至CCR写入 [μs，演示]','5');
param(m,'settle_us','edit','低侧导通稳定等待 [μs，演示]','0.5');
m.addParameter('Name','update_mode','Type','popup','Prompt','CCR预装载生效边界','TypeOptions',{'峰谷双更新（RCR=0）','仅谷底（对照）'},'Value','峰谷双更新（RCR=0）','Tunable','off');
m.addParameter('Name','grid_divider','Type','edit','Value','1','Visible','off','Tunable','off');
m.Description=['真实时序：C/B/A顺序采样，JEOS执行原控制器，计算后写CCR，下一UEV生效。' ...
 'RCR=0按峰谷双更新；24.375us触发相位是源码推导假设，CC4路由及下降沿须实测。' ...
 '计算5us、稳定等待0.5us均为演示值。窗口检查整个采样孔径；无效样本置零仅为低侧不可观测演示，保持策略不是当前固件行为。' ...
 '真实模式使用62.5ns网格，仍无门极死区/二极管模型。与旧整周期延迟互斥。'];
m.Display='if real_on, color(''red''); disp(''时序：实物''); elseif speed_on||pwm_on, disp(''时序：教学''); else, disp(''时序：理想''); end';
% Phased execution preserves all original PI internals and their numeric gains.
for b=cached.before.blocks
 if ~isfield(b.params,'SampleTime'),continue;end
 if strcmp(b.params.SampleTime,'dt'),set_param(b.path,'SampleTime','timing_control_sample');end
end
set_param(Simulink.ID.getHandle([mdl ':155']),'SampleTime','timing_speed_sample');
set_param(Simulink.ID.getHandle([mdl ':190']),'SampleTime','timing_speed_sample');
set_param(Simulink.ID.getHandle([mdl ':439']),'SampleTime','timing_control_sample');
set_param(Simulink.ID.getHandle([mdl ':453']),'SampleTime','timing_control_sample');
set_param(Simulink.ID.getHandle([mdl ':324']),'rep_seq_y','timing_carrier_y');
% These torque-coefficient operations include constants. Evaluate them before
% the first phased control hit so an initial 0/0 cannot arise in Te/Kt.
for id={'215','197'},set_param(Simulink.ID.getHandle([mdl ':' id{1}]),'SampleTime','timing_static_math');end
set_param(mdl,'InitFcn',[cached.init newline fileread(fullfile(folder,'timing_model_init.m'))]);
% ADC events live inside the existing sampling panel; no new top-level region.
p=[mdl '/采样设置'];localMask=Simulink.Mask.get(p);localMask.addParameter('Name','real_mode','Type','edit','Value','strcmp(get_param([bdroot ''/时序设置''],''real_on''),''on'')','Visible','off','Tunable','off');from(p,'门极','SW',[30 510 125 535]);
add_block('simulink/Discrete/Unit Delay',[p '/门极历史'],'SampleTime','timing_h','InitialCondition','[0 1 0 1 0 1]','Position',[160 500 250 540]);wire(p,'门极',1,'门极历史',1);
add_block('simulink/Sources/Digital Clock',[p '/事件时钟'],'SampleTime','timing_h','Position',[30 590 125 620]);
add_block('simulink/Sources/Constant',[p '/时序参数'],'Value','timing_adc_cfg','Position',[30 670 125 700]);
chart(p,'顺序采样',fileread(fullfile(folder,'timing_adc.m')),[360 500 540 720]);
wire(p,'事件时钟',1,'顺序采样',1);wire(p,'模拟选择',1,'顺序采样',2);wire(p,'门极历史',1,'顺序采样',3);wire(p,'时序参数',1,'顺序采样',4);
add_block('simulink/Discrete/Unit Delay',[p '/模拟缓存'],'SampleTime','timing_h','InitialCondition','[0;0;0]','Position',[160 750 250 790]);
wire(p,'模拟选择',1,'模拟缓存',1);replace(p,'顺序采样',2,'模拟缓存',1);
add_block('simulink/Signal Routing/Variant Source',[p '/采样方式'],'VariantControls',{'real_mode==1','real_mode==0'},'Position',[780 510 830 570]);
wire(p,'顺序采样',1,'采样方式',1);wire(p,'模拟选择',1,'采样方式',2);replace(p,'捕获',1,'采样方式',1);
add_block('simulink/Math Operations/Reshape',[p '/列向量'],'OutputDimensionality','Column vector (2-D)','Position',[620 500 710 540]);
wire(p,'顺序采样',1,'列向量',1);replace(p,'采样方式',1,'列向量',1);
set_param([p '/启用'],'Value',[get_param([p '/启用'],'Value') '||timing_on']);
log(p,'顺序采样',2,'obs_adc_timing','timing_h',[900 510 1060 540]);
log(p,'顺序采样',3,'obs_adc_codes','timing_control_sample',[900 590 1060 620]);
tap(p,'顺序采样',2,'ObsADCTiming',[900 670 1060 695]);
% Keep the old output-delay blocks; event latch is an alternative local branch.
p=[mdl '/输出延迟'];localMask=Simulink.Mask.get(p);localMask.addParameter('Name','real_mode','Type','edit','Value','strcmp(get_param([bdroot ''/时序设置''],''real_on''),''on'')','Visible','off','Tunable','off');add_block('simulink/Sources/Digital Clock',[p '/事件时钟'],'SampleTime','timing_h','Position',[25 360 120 390]);
add_block('simulink/Sources/Constant',[p '/时序参数'],'Value','timing_pwm_cfg','Position',[25 440 120 470]);
chart(p,'CCR预装载',fileread(fullfile(folder,'timing_pwm.m')),[200 340 370 500]);
wire(p,'事件时钟',1,'CCR预装载',1);wire(p,'指令',1,'CCR预装载',2);wire(p,'时序参数',1,'CCR预装载',3);
% A one-grid read buffer breaks the artificial aggregate motor-bus algebraic
% loop. Compute time must be >= one grid tick; held request is unchanged then.
add_block('simulink/Discrete/Unit Delay',[p '/指令缓存'],'SampleTime','timing_h','InitialCondition','Ts/4','Position',[30 520 120 560]);
wire(p,'指令',1,'指令缓存',1);replace(p,'CCR预装载',2,'指令缓存',1);
add_block('simulink/Signal Routing/Variant Source',[p '/输出方式'],'VariantControls',{'real_mode==1','real_mode==0'},'Position',[560 360 610 420]);
wire(p,'CCR预装载',1,'输出方式',1);wire(p,'选择',1,'输出方式',2);replace(p,'生效',1,'输出方式',1);replace(p,'记录_log_Tcm_applied',1,'输出方式',1);
add_block('simulink/Math Operations/Reshape',[p '/阈值向量'],'OutputDimensionality','1-D array','Position',[420 340 510 380]);wire(p,'CCR预装载',1,'阈值向量',1);replace(p,'输出方式',1,'阈值向量',1);
log(p,'CCR预装载',2,'obs_pwm_timing','timing_h',[700 360 860 390]);tap(p,'CCR预装载',2,'ObsPWMTiming',[700 440 860 465]);
outputMask=Simulink.Mask.get(p);outputMask.Description='理想/旧整周期延迟或真实CCR预装载分支。真实时序在时序设置中启用，包含CCR量化、计算完成与更新边界。';
outputMask.Display='disp(''更新'');';
% Extend the existing timing scope without moving its top-level block.
p=[mdl '/时序观测'];from(p,'ADC事件','ObsADCTiming',[30 1000 150 1025]);from(p,'PWM事件','ObsPWMTiming',[30 1150 150 1175]);
for row={'ADC事件','ADC事件分组','[1 5 3 4 2]',1000;'PWM事件','PWM事件分组','[2 3 3 1 3]',1150}'
 add_block('simulink/Signal Routing/Demux',[p '/' row{2}],'Outputs',row{3},'Position',[220 row{4} 225 row{4}+110]);wire(p,row{1},1,row{2},1);
 for port=[1 5],term=sprintf('%s_保留%d',row{1},port);add_block('simulink/Sinks/Terminator',[p '/' term],'Position',[310 row{4}+25*port 325 row{4}+15+25*port]);wire(p,row{2},port,term,1);end
end
s=[p '/总览'];n=str2double(get_param(s,'NumInputPorts'));set_param(s,'NumInputPorts',num2str(n+6));c=get_param(s,'ScopeConfiguration');c.LayoutDimensions=[4 3];
for row={'采样事件','ADC事件分组',2;'窗口有效ABC','ADC事件分组',3;'电流样本与和','ADC事件分组',4;'PWM更新事件','PWM事件分组',2;'待更新序号','PWM事件分组',3;'采样至生效 [s]','PWM事件分组',4}'
 n=n+1;wire(p,row{2},row{3},'总览',n);c.ActiveDisplay=num2str(n);c.Title=row{1};c.ShowLegend=true;
end
% All existing geometry is a preservation invariant.
for b=cached.before.blocks,set_param(b.path,'Position',b.position);end
set_param(mdl,'FixedStep','timing_h');set_param(mdl,'SimulationCommand','update');
after=teach_snapshot(mdl);assert(isequaln(cached.before.regions,after.regions));
for b=cached.before.blocks,n=after.blocks(strcmp({after.blocks.sid},b.sid));assert(isscalar(n)&&strcmp(b.path,n.path)&&strcmp(b.type,n.type)&&isequal(b.position,n.position));end
save_system(mdl,candidate);fprintf('TIMING_CANDIDATE_BUILT %s\n',teach_hash(candidate));
end
function param(m,n,t,p,v),m.addParameter('Name',n,'Type',t,'Prompt',p,'Value',v,'Tunable','off');end
function from(p,n,tag,pos),add_block('simulink/Signal Routing/From',[p '/' n],'GotoTag',tag,'Position',pos,'ShowName','off');end
function chart(p,n,code,pos)
add_block('simulink/User-Defined Functions/MATLAB Function',[p '/' n],'Position',pos);rt=sfroot;c=rt.find('-isa','Stateflow.EMChart','Path',[p '/' n]);c.Script=code;c.ChartUpdate='DISCRETE';c.SampleTime='timing_h';c.VectorOutputs1D=false;
outputs=c.find('-isa','Stateflow.Data','Scope','Output');
for data=outputs(:)'
 if strcmp(data.Name,'diag'),width=15;if strcmp(n,'CCR预装载'),width=12;end;else,width=3;end
 data.Props.Array.Size=sprintf('[1 %d]',width);
end
end
function tap(p,n,port,tag,pos),g=['标签_' tag];add_block('simulink/Signal Routing/Goto',[p '/' g],'GotoTag',tag,'TagVisibility','global','Position',pos);wire(p,n,port,g,1);end
function log(p,n,port,var,st,pos),b=['记录_' var];add_block('simulink/Sinks/To Workspace',[p '/' b],'VariableName',var,'SaveFormat','Timeseries','SampleTime',st,'MaxDataPoints','inf','Position',pos);wire(p,n,port,b,1);end
function wire(p,s,sp,d,dp),a=get_param([p '/' s],'PortHandles');b=get_param([p '/' d],'PortHandles');add_line(p,a.Outport(sp),b.Inport(dp),'autorouting','on');end
function replace(p,d,dp,s,sp),h=get_param([p '/' d],'PortHandles');l=get_param(h.Inport(dp),'Line');delete_line(p,get_param(l,'SrcPortHandle'),h.Inport(dp));wire(p,s,sp,d,dp);end
