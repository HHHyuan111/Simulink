function build_deadtime_stage4
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);addpath(fullfile(root,'teaching'));
work=fullfile(root,'.build','deadtime_stage');mdl='PMSM_FOC_R2026a';source=fullfile(root,[mdl '.slx']);
assert(strcmp(teach_hash(source),'db31d893ca9f0359e6b36e580056da9b74a46457f127da0c1bcccbab4775edec'));
file=fullfile(work,[mdl '.slx']);copyfile(source,file);load_system(file);g=onCleanup(@()close_system(mdl,0));
cache=load(fullfile(work,'before.mat'));assert(isequaln(cache.before,teach_snapshot(mdl)));
mw=get_param(mdl,'ModelWorkspace');mw.MATLABCode=[mw.MATLABCode newline ...
 'dead_gate_on=0; dead_h=1e-6; dead_gate_cfg=[0 1e-6 .5e-6];' newline ...
 'dead_comp_cfg=[0 .5e-6 Ts .05]; dead_bridge_cfg=[p phis .01 0 .01 .7];' newline];reload(mw);
p=[mdl '/功率设置'];m=Simulink.Mask.get(p);
param(m,'gate_on','checkbox','门极死区（实际空白与续流）','off');
param(m,'comp_on','checkbox','死区补偿（测量电流极性）','off');
param(m,'gate_us','edit','门极死区 [μs，固件配置]','0.5');
param(m,'comp_us','edit','补偿死区 [μs，可作失配对照]','0.5');
param(m,'hysteresis_A','edit','补偿极性滞环 ±[A，演示]','0.05');
param(m,'zero_A','edit','续流近零数值带 ±[A，演示]','0.01');
m.Description=['门极死区：下降沿立即关断，上升沿延迟；三相浮置星点按实际门极及相电流方向续流。' ...
 '0.5us是定时器编程配置，不含未知驱动传播差异。近零带为数值近似，当前仅适用于Ld=Lq。' ...
 '补偿使用测量电流和测量角，按Vbus*tcomp/Ts加相电压修正，先合入dq再统一限压及回算。' ...
 '旧平均死区与门极死区互斥；详细模式的drop_on在桥内计算Ron/Vf，不再叠加旧平均压降。'];
m.Display='if gate_on&&comp_on, color(''red'');disp(''功率：补偿'');elseif gate_on, color(''red'');disp(''功率：死区'');elseif dead_on||drop_on,disp(''功率：平均'');else,disp(''功率：理想'');end';
set_param([p '/启用'],'Value','(~dead_gate_on)&&(dead_on||drop_on)');
set_param(mdl,'InitFcn',[cache.init newline fileread(fullfile(folder,'deadtime_model_init.m'))]);

% Eliminate the existing artificial feedthrough of phase-current expressions
% through the voltage/state/torque mux. The expressions themselves are unchanged.
motor=getfullname(Simulink.ID.getHandle([mdl ':626']));
add_block('simulink/Sources/Constant',[motor '/电流占位电压'],'Value','[0 0 0]','Position',[20 760 100 790]);
add_block('simulink/Sources/Constant',[motor '/电流占位转矩'],'Value','0','Position',[20 840 100 870]);
add_block('simulink/Signal Routing/Mux',[motor '/电流状态'],'Inputs','3','Position',[180 750 185 880]);
wire(motor,'电流占位电压',1,'电流状态',1);wire(motor,'id_iq_wm_theta',1,'电流状态',2);wire(motor,'电流占位转矩',1,'电流状态',3);
for n={'ia','ib','ic'},replace(motor,n{1},1,'电流状态',1);end
tap(motor,'id_iq_wm_theta',1,'DeadMotorState',[800 780 940 805]);

% The accepted bridge remains the ideal branch, with a local detailed alternative.
p=[mdl '/Universal Bridge'];
add_block('simulink/Sources/Digital Clock',[p '/事件时钟'],'SampleTime','dead_h','Position',[30 330 120 360]);
add_block('simulink/Sources/Constant',[p '/门极参数'],'Value','dead_gate_cfg','Position',[30 410 120 440]);
chart(p,'门极死区','gate_deadtime.m',folder,[210 300 385 450],'dead_h',{'[1 6]','[1 3]'});
wire(p,'事件时钟',1,'门极死区',1);wire(p,'double gates',1,'门极死区',2);wire(p,'门极参数',1,'门极死区',3);
add_block('simulink/Sinks/Terminator',[p '/空白保留'],'Position',[430 420 450 440]);wire(p,'门极死区',2,'空白保留',1);
logSignal(p,'double gates',1,'obs_dead_requested','dead_h',[850 400 1020 430]);
add_block('simulink/Math Operations/Reshape',[p '/门极向量'],'OutputDimensionality','1-D array','Position',[430 310 510 345]);wire(p,'门极死区',1,'门极向量',1);
add_block('simulink/Signal Routing/Variant Source',[p '/门极选择'],'VariantControls',{'dead_gate_on==1','dead_gate_on==0'},'Position',[560 300 610 360]);
wire(p,'门极向量',1,'门极选择',1);wire(p,'double gates',1,'门极选择',2);tap(p,'门极选择',1,'SWact',[670 320 810 345]);
logSignal(p,'门极选择',1,'obs_dead_gates','dead_h',[850 320 1020 350]);
from(p,'电机状态','DeadMotorState',[30 540 140 565]);
add_block('simulink/Sources/Constant',[p '/续流参数'],'Value','dead_bridge_cfg','Position',[30 640 140 670]);
chart(p,'续流','bridge_freewheel.m',folder,[210 520 385 690],'continuous',{'[1 3]','[1 9]'});
wire(p,'门极选择',1,'续流',1);wire(p,'电机状态',1,'续流',2);wire(p,'Vdc',1,'续流',3);wire(p,'续流参数',1,'续流',4);
add_block('simulink/Math Operations/Reshape',[p '/相电压向量'],'OutputDimensionality','1-D array','Position',[430 530 510 570]);wire(p,'续流',1,'相电压向量',1);
add_block('simulink/Signal Routing/Variant Source',[p '/桥选择'],'VariantControls',{'dead_gate_on==1','dead_gate_on==0'},'Position',[560 520 610 580]);
wire(p,'相电压向量',1,'桥选择',1);wire(p,'phase_voltage',1,'桥选择',2);replace(p,'Vabc',1,'桥选择',1);
tap(p,'续流',2,'ObsFreewheel',[670 600 820 625]);logSignal(p,'续流',2,'obs_dead_bridge','T',[850 600 1020 630]);
% Sampling windows must inspect actual gate states, not complementary requests.
set_param([mdl '/采样设置/门极'],'GotoTag','SWact');

% Measured-current compensation joins the existing limiter and antiwindup chain.
p=[mdl '/限压'];from(p,'补偿电流','Iabc_meas',[20 950 150 975]);from(p,'补偿角度','theta_meas',[20 1030 150 1055]);
add_block('simulink/Sources/Constant',[p '/补偿参数'],'Value','dead_comp_cfg','Position',[20 1110 150 1140]);
chart(p,'死区补偿','deadtime_comp.m',folder,[220 920 400 1160],'timing_control_sample',{'[1 2]','[1 8]'});
wire(p,'补偿电流',1,'死区补偿',1);wire(p,'补偿角度',1,'死区补偿',2);wire(p,'母线采样',1,'死区补偿',3);wire(p,'补偿参数',1,'死区补偿',4);
add_block('simulink/Signal Routing/Demux',[p '/补偿分轴'],'Outputs','2','Position',[450 930 455 1040]);wire(p,'死区补偿',1,'补偿分轴',1);
for k=1:2
 axes={'d','q'};ax=axes{k};n=['补偿_' ax];add_block('simulink/Math Operations/Sum',[p '/' n],'Inputs','++','Position',[520 930+80*(k-1) 545 955+80*(k-1)]);
 wire(p,ax,1,n,1);wire(p,'补偿分轴',k,n,2);
 replace(p,'输入',k,n,1);replace(p,['输出_' ax],1,n,1);replace(p,['残差_' ax],2,n,1);replace(p,'诊断',k,n,1);
end
tap(p,'死区补偿',2,'ObsDeadComp',[600 1110 760 1135]);logSignal(p,'死区补偿',2,'obs_dead_comp','timing_control_sample',[820 1110 1000 1140]);

% Add useful plots to the existing power overview; no new root region.
p=[mdl '/功率观测'];from(p,'实际门极','SWact',[20 800 160 825]);from(p,'续流诊断','ObsFreewheel',[20 950 160 975]);from(p,'补偿诊断','ObsDeadComp',[20 1150 160 1175]);
add_block('simulink/Signal Routing/Demux',[p '/续流分组'],'Outputs','[3 3 3]','Position',[220 930 225 1060]);wire(p,'续流诊断',1,'续流分组',1);
add_block('simulink/Sinks/Terminator',[p '/真实电流保留'],'Position',[300 1040 320 1060]);wire(p,'续流分组',3,'真实电流保留',1);
add_block('simulink/Signal Routing/Demux',[p '/补偿分组'],'Outputs','[3 2 3]','Position',[220 1130 225 1260]);wire(p,'补偿诊断',1,'补偿分组',1);
add_block('simulink/Sinks/Terminator',[p '/极性保留'],'Position',[300 1240 320 1260]);wire(p,'补偿分组',3,'极性保留',1);
s=[p '/总览'];old=str2double(get_param(s,'NumInputPorts'));set_param(s,'NumInputPorts',num2str(old+5));c=get_param(s,'ScopeConfiguration');c.LayoutDimensions=[4 2];
for row={'实际门极','实际门极',1;'续流通道 -1下管/+1上管','续流分组',1;'极点电压 [V]','续流分组',2;'相电压补偿 [V]','补偿分组',1;'dq补偿 [V]','补偿分组',2}'
 old=old+1;wire(p,row{2},row{3},'总览',old);c.ActiveDisplay=num2str(old);c.Title=row{1};c.ShowLegend=true;
end
for b=cache.before.blocks,set_param(b.path,'Position',b.position);end
set_param(mdl,'SimulationCommand','update');after=teach_snapshot(mdl);
assert(isequaln(cache.before.regions,after.regions));
for b=cache.before.blocks,n=after.blocks(strcmp({after.blocks.sid},b.sid));assert(isscalar(n)&&strcmp(b.path,n.path)&&strcmp(b.type,n.type)&&(isequal(b.position,n.position)||strcmp(b.path,[mdl '/功率观测/总览'])),'Original geometry changed: %s -> %s',b.path,mat2str(n.position));end
save_system(mdl,file);save(fullfile(work,'built.mat'),'after');fprintf('DEADTIME_BUILT %s\n',teach_hash(file));
end
function param(m,n,t,p,v),m.addParameter('Name',n,'Type',t,'Prompt',p,'Value',v,'Tunable','off');end
function chart(p,n,source,folder,pos,st,sizes)
add_block('simulink/User-Defined Functions/MATLAB Function',[p '/' n],'Position',pos);rt=sfroot;c=rt.find('-isa','Stateflow.EMChart','Path',[p '/' n]);c.Script=fileread(fullfile(folder,source));
if strcmp(st,'continuous'),c.ChartUpdate='CONTINUOUS';else,c.ChartUpdate='DISCRETE';c.SampleTime=st;end
c.VectorOutputs1D=false;outputs=c.find('-isa','Stateflow.Data','Scope','Output');
for data=outputs(:)',data.Props.Array.Size=sizes{data.Port};end
end
function from(p,n,tag,pos),add_block('simulink/Signal Routing/From',[p '/' n],'GotoTag',tag,'Position',pos,'ShowName','off');end
function tap(p,n,port,tag,pos),g=['标签_' tag];add_block('simulink/Signal Routing/Goto',[p '/' g],'GotoTag',tag,'TagVisibility','global','Position',pos,'ShowName','off');wire(p,n,port,g,1);end
function logSignal(p,n,port,var,st,pos),b=['记录_' var];add_block('simulink/Sinks/To Workspace',[p '/' b],'VariableName',var,'SaveFormat','Timeseries','SampleTime',st,'MaxDataPoints','inf','Position',pos);wire(p,n,port,b,1);end
function wire(p,s,sp,d,dp),a=get_param([p '/' s],'PortHandles');b=get_param([p '/' d],'PortHandles');add_line(p,a.Outport(sp),b.Inport(dp),'autorouting','on');end
function replace(p,d,dp,s,sp),h=get_param([p '/' d],'PortHandles');l=get_param(h.Inport(dp),'Line');delete_line(p,get_param(l,'SrcPortHandle'),h.Inport(dp));wire(p,s,sp,d,dp);end
