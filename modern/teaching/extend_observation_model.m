function extend_observation_model
% Extend the accepted flat diagram; no controller tuning or plant rebuild.
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);mdl='PMSM_FOC_R2026a';
source=fullfile(root,[mdl '.slx']);expected='88f7d9b63986307df6dad91373373b8fe2107cfde5414aea55637b9909006611';
assert(strcmp(teach_hash(source),expected),'Source changed; refusing to overwrite.');
work=fullfile(root,'.build','observation_stage');cached=load(fullfile(work,'before.mat'));
load_system(source);guard=onCleanup(@()close_system(mdl,0));
assert(isequaln(cached.before,teach_snapshot(mdl)),'Inventory mismatch.');
addAnalog(mdl);addPower(mdl);addObservations(mdl);
set_param(mdl,'SimulationCommand','update');
after=teach_snapshot(mdl);checkPreserved(cached.before,after);
probeFolder=fullfile(work,'candidate');if ~isfolder(probeFolder),mkdir(probeFolder);end
save_system(mdl,fullfile(probeFolder,[mdl '.slx']));
fprintf('OBSERVATION_VALIDATE\n');
report=validate_observation_model(cached.baseline);
assert(report.all_passed,'Validation failed; main model has not been saved.');
reload(get_param(mdl,'ModelWorkspace'));
checkPreserved(cached.before,teach_snapshot(mdl));
save_system(mdl,source);report.before_sha256=expected;report.after_sha256=teach_hash(source);
report.total_blocks=numel(after.blocks);report.root_blocks=numel(find_system(mdl,'SearchDepth',1,'Type','Block'));
report.original_384_blocks_preserved=true;report.original_geometry_and_pi_math_unchanged=true;
teach_writejson(fullfile(folder,'observation_validation.json'),report);
print(['-s' mdl],'-dpng','-r120',fullfile(root,'layout','flat_tidy.png'));
fprintf('OBSERVATION_SAVED %s\n',report.after_sha256);
end

function addAnalog(mdl)
path=[mdl '/采样设置'];mask=Simulink.Mask.get(path);
mask.addParameter('Name','analog_on','Type','checkbox','Prompt','模拟低通（采样前）','Value','off','Tunable','off','Container','filter');
mask.addParameter('Name','analog_hz','Type','edit','Prompt','模拟一阶截止频率 [Hz，演示]','Value','5000','Tunable','off','Container','filter');
mask.addParameter('Name','numerical_step','Type','edit','Value','T','Visible','off','Tunable','off');
mask.Initialization=[mask.Initialization newline ...
 'validateattributes(analog_hz,{''double''},{''scalar'',''real'',''finite'',''positive''});' newline ...
 'assert(2*pi*analog_hz*numerical_step<1,''Analog filter requires a smaller numerical step T.'');'];
mask.Description=[mask.Description ' 新增模拟一阶低通在同步采样之前，初始状态为0；模拟/数字滤波独立开关。RC与放大器实际参数待原理图确认。'];
mask.Display=statusIcon('采样设置',{'bias_on','gain_on','noise_on','adc_on','filter_on','delay_on','analog_on'});
af=[path '/模拟低通'];add_block('built-in/SubSystem',af,'Position',[440 -100 560 -60]);
add_block('simulink/Sources/In1',[af '/输入']);add_block('simulink/Signal Routing/Demux',[af '/分相'],'Outputs','3','Position',[100 50 105 250]);
add_block('simulink/Signal Routing/Mux',[af '/合相'],'Inputs','3','Position',[420 50 425 250]);
add_block('simulink/Sinks/Out1',[af '/输出'],'Position',[500 140 530 160]);wire(af,'输入',1,'分相',1);wire(af,'合相',1,'输出',1);
for k=1:3
 name=sprintf('RC%d',k);add_block('simulink/Continuous/Transfer Fcn',[af '/' name],'Numerator','[2*pi*analog_hz]', ...
  'Denominator','[1 2*pi*analog_hz]','Position',[200 30+80*(k-1) 320 70+80*(k-1)]);
 wire(af,'分相',k,name,1);wire(af,name,1,'合相',k);
end
add_block('simulink/Sources/Constant',[path '/模拟开关'],'Value','analog_on','Position',[600 -25 675 0]);
add_block('simulink/Signal Routing/Switch',[path '/模拟选择'],'Criteria','u2 ~= 0','Position',[710 -90 760 -30]);
ph=get_param([path '/捕获'],'PortHandles');delete_line(get_param(ph.Inport(1),'Line'));
wire(path,'模拟测量',1,'模拟低通',1);wire(path,'模拟低通',1,'模拟选择',1);
wire(path,'模拟开关',1,'模拟选择',2);wire(path,'模拟测量',1,'模拟选择',3);wire(path,'模拟选择',1,'捕获',1);
set_param([path '/启用'],'Value','bias_on||gain_on||noise_on||adc_on||filter_on||delay_on||analog_on');
tap(path,'模拟选择',1,'obs_analog_current','ObsAnalog',[710 -170 880 -145]);
end

function addPower(mdl)
path=[mdl '/功率设置'];
mask=panel(path,[1640 1250 1800 1285],'功率设置', ...
 ['周期平均误差教学模型，非逐开关沿死区/二极管模型。正相电流定义为逆变器流向电机。' ...
 '每Ts保持电流，压降=开关死区项+导通电阻项，去除共模后从理想相电压扣除。' ...
 '0.5us来自AxDr_L dev配置；Ron、Vf和过零平滑均为演示参数。忽略最小脉宽、钳位、二极管瞬态和开关损耗。']);
param(mask,'dead_on','checkbox','死区平均压降','off');param(mask,'dead_us','edit','死区 [μs，固件目标]','0.5');
param(mask,'drop_on','checkbox','器件导通压降','off');param(mask,'ron','edit','等效导通电阻 [Ω，演示]','0.01');
param(mask,'vf','edit','续流压降 [V，演示，仅随死区项计入]','0.7');
param(mask,'blend_A','edit','过零平滑电流 [A，演示]','0.1');
mask.addParameter('Name','pwm_period','Type','edit','Value','Ts','Visible','off','Tunable','off');
mask.Display=statusIcon('功率设置',{'dead_on','drop_on'});
mask.Initialization=sprintf([ ...
 'validateattributes(dead_us,{''double''},{''scalar'',''real'',''finite'',''nonnegative'',''<'',pwm_period*1e6/10});\n' ...
 'validateattributes(ron,{''double''},{''scalar'',''real'',''finite'',''nonnegative''});\n' ...
 'validateattributes(vf,{''double''},{''scalar'',''real'',''finite'',''nonnegative''});\n' ...
 'validateattributes(blend_A,{''double''},{''scalar'',''real'',''finite'',''positive''});']);
from(path,'电流','Currentabc',[25 50 105 70]);
add_block('simulink/Discrete/Zero-Order Hold',[path '/周期电流'],'SampleTime','Ts','Position',[150 40 220 80]);
from(path,'母线','UDC',[25 150 105 170]);
add_block('simulink/Signal Routing/Mux',[path '/输入'],'Inputs','2','Position',[280 40 285 170]);
wire(path,'电流',1,'周期电流',1);wire(path,'周期电流',1,'输入',1);wire(path,'母线',1,'输入',2);
add_block('simulink/Signal Routing/Mux',[path '/三相压降'],'Inputs','3','Position',[650 40 655 230]);
for k=1:3
 name=sprintf('压降%d',k);expr=sprintf('dead_on*dead_us*1e-6/Ts*(u(4)+drop_on*vf)*u(%d)/(abs(u(%d))+blend_A)+drop_on*ron*u(%d)',k,k,k);
 add_block('simulink/User-Defined Functions/Fcn',[path '/' name],'Expr',expr,'Position',[350 30+75*(k-1) 580 65+75*(k-1)]);
 wire(path,'输入',1,name,1);wire(path,name,1,'三相压降',k);
end
add_block('simulink/Math Operations/Gain',[path '/去共模'],'Gain','eye(3)-ones(3)/3', ...
 'Multiplication','Matrix(K*u)','Position',[715 110 850 155]);wire(path,'三相压降',1,'去共模',1);
tap(path,'去共模',1,'obs_power_drop','ObsPowerDrop',[910 115 1040 140]);
add_block('simulink/Sources/Constant',[path '/启用'],'Value','dead_on||drop_on','Position',[715 250 850 280]);
goto(path,'开关','ObsPowerOn',[910 255 1040 280]);wire(path,'启用',1,'开关',1);
logSignal(path,'去共模',1,'obs_power_drop','dt',[910 330 1050 360]);

effect=[mdl '/功率压降'];add_block('built-in/SubSystem',effect,'Position',[1290 960 1325 1000],'ShowName','off','BackgroundColor','white');
m=Simulink.Mask.create(effect);m.Display='disp(''压降'');';m.Description=mask.Description;
add_block('simulink/Sources/In1',[effect '/理想'],'Position',[25 100 55 120]);
from(effect,'压降','ObsPowerDrop',[25 200 130 220]);from(effect,'开关','ObsPowerOn',[220 200 330 220]);
add_block('simulink/Math Operations/Sum',[effect '/扣除'],'Inputs','+-','SampleTime','0','Position',[175 95 195 125]);
add_block('simulink/Signal Routing/Switch',[effect '/旁路'],'Criteria','u2 ~= 0','SampleTime','0','Position',[380 90 430 150]);
add_block('simulink/Sinks/Out1',[effect '/实际'],'Position',[500 110 530 130]);
wire(effect,'理想',1,'扣除',1);wire(effect,'压降',1,'扣除',2);wire(effect,'扣除',1,'旁路',1);
wire(effect,'开关',1,'旁路',2);wire(effect,'理想',1,'旁路',3);wire(effect,'旁路',1,'实际',1);
tap(effect,'理想',1,'obs_phase_ideal','ObsPhaseIdeal',[25 300 175 325]);
tap(effect,'旁路',1,'obs_phase_actual','ObsPhaseActual',[380 300 530 325]);
logSignal(effect,'理想',1,'obs_phase_ideal','T',[25 380 175 410]);
logSignal(effect,'旁路',1,'obs_phase_actual','T',[380 380 530 410]);
bridge=get_param(sid(mdl,'615'),'PortHandles');measurement=get_param(sid(mdl,'671'),'PortHandles');
delete_line(get_param(measurement.Inport(1),'Line'));e=get_param(effect,'PortHandles');
add_line(mdl,bridge.Outport(1),e.Inport(1),'autorouting','on');add_line(mdl,e.Outport(1),measurement.Inport(1),'autorouting','on');
end

function addObservations(mdl)
% Tap the existing PI signals without changing equations or ports.
for row={'155','speed','N*m';'439','d','V';'453','q','V'}'
 path=getfullname(sid(mdl,row{1}));tag=['ObsPI_' row{2}];
 add_block('simulink/Signal Routing/Mux',[path '/观测汇总'],'Inputs','4','Position',[650 40 655 230]);
 names={sprintf('Zero-Order\nHold'),sprintf('Discrete-Time\nIntegrator'),'Add','Saturation'};
 for k=1:4,wire(path,names{k},1,'观测汇总',k);end
 tap(path,'观测汇总',1,['obs_pi_' row{2}],tag,[730 120 880 145]);
 logSignal(path,'观测汇总',1,['obs_pi_' row{2}],'dt',[730 210 880 240]);
end
plant=getfullname(sid(mdl,'626'));
logSignal(plant,'id_iq_wm_theta',1,'obs_state','dt',[920 565 1070 595]);
logSignal(plant,'Te',1,'obs_torque_fast','T',[920 630 1070 660]);
add_block('simulink/Signal Routing/Mux',[plant '/电压观测'],'Inputs','2','Position',[1200 575 1205 660]);
wire(plant,'vd_actual',1,'电压观测',1);wire(plant,'vq_actual',1,'电压观测',2);
logSignal(plant,'电压观测',1,'obs_vdq_fast','T',[1280 600 1430 630]);
tap(mdl,get_param(sid(mdl,'590'),'Name'),1,'obs_id_ref','ObsIdRef',[990 145 1070 165]);set_param([mdl '/标签_obs_id_ref'],'ShowName','off');

logPath=getfullname(sid(mdl,'695'));mask=Simulink.Mask.create(logPath);mask.Display='disp(''数据记录'');';
mask.Description='原日志保留；obs_*为新增日志。默认dt的控制量记录不能用来判断PWM开关纹波。功率与门极的快速日志按T采样。';
tags={'vd','vq','Vd_re','Vq_re','sector','ObsAnalog','ObsIdRef'};
vars={'obs_vd','obs_vq','obs_vd_actual','obs_vq_actual','obs_sector','obs_analog_current','obs_id_ref'};
for k=1:numel(tags)
 name=['观测_' vars{k}];from(logPath,name,tags{k},[400 50+65*k 490 70+65*k]);
 logSignal(logPath,name,1,vars{k},'dt',[570 45+65*k 740 75+65*k]);
end
from(logPath,'门极','SW',[850 80 940 100]);logSignal(logPath,'门极',1,'obs_gates_fast','T',[1000 75 1150 105]);
carrier=getfullname(sid(mdl,'324'));tap(mdl,get_param(carrier,'Name'),1,'obs_carrier_fast','ObsCarrier',[325 740 405 760]);
set_param([mdl '/标签_obs_carrier_fast'],'ShowName','off');from(logPath,'载波','ObsCarrier',[850 240 950 260]);
logSignal(logPath,'载波',1,'obs_carrier_fast','T',[1000 235 1150 265]);
% Fast phase voltage and current share the numerical grid for power/ripple analysis.
from(logPath,'真实电流','Currentabc',[850 160 950 180]);logSignal(logPath,'真实电流',1,'obs_current_fast','T',[1000 155 1150 185]);

tracking=[mdl '/跟踪观测'];panel(tracking,[90 1875 260 1908],'跟踪观测','按单位分轴；主控制给定，无Chirp辅助参考。');
scopeGroup(tracking,'转速',{'nref','speed'},'rpm',[20 50],1);
scopeGroup(tracking,'d轴',{'ObsIdRef','id'},'A',[20 190],2);
scopeGroup(tracking,'q轴',{'iq_ref','iq'},'A',[20 330],3);
scopeGroup(tracking,'转矩',{'Te','TL'},'N*m',[20 470],4);
errorScope(tracking,'转速误差','nref','speed','rpm',[550 50],5,false);
errorScope(tracking,'d轴误差','ObsIdRef','id','A',[550 190],6,false);
errorScope(tracking,'q轴误差','iq_ref','iq','A',[550 330],7,false);
pi=[mdl '/PI观测'];panel(pi,[400 1875 570 1908],'PI观测','每组顺序：P / I / 限幅前 / 限幅后。速度环单位N*m；电流环单位V。');
scopeGroup(pi,'速度PI',{'ObsPI_speed'},'N*m',[20 50],1);
scopeGroup(pi,'d轴PI',{'ObsPI_d'},'V',[20 190],2);scopeGroup(pi,'q轴PI',{'ObsPI_q'},'V',[20 330],3);
timing=[mdl '/时序观测'];panel(timing,[990 1875 1160 1908],'时序观测','门极按求解步长T记录；当前死区仅平均压降，不产生门极空白。');
scopeGroup(timing,'门极',{'SW'},'logic',[20 50],1,'T');
scopeGroup(timing,'电压指令',{'vd','vq'},'V',[20 190],2);
scopeGroup(timing,'测量电压',{'Vd_re','Vq_re'},'V',[20 330],3,'T');
measurement=[mdl '/测量观测'];panel(measurement,[2300 1875 2470 1908],'测量观测','真实电流、测量电流及误差分别显示。误差为measured - true；包含滤波相位滞后。');
scopeGroup(measurement,'真实电流',{'Currentabc'},'A',[20 50],1);
scopeGroup(measurement,'测量电流',{'Iabc_meas'},'A',[20 190],2);
scopeGroup(measurement,'电角度',{'theta_e','theta_meas'},'rad',[20 330],3);
errorScope(measurement,'电流误差','Iabc_meas','Currentabc','A',[550 50],4,false);
errorScope(measurement,'角度误差','theta_meas','theta_e','rad',[550 330],5,true);
power=[mdl '/功率观测'];panel(power,[2530 1875 2700 1908],'功率观测','相电压按T采样；平均压降按dt记录；功率统计请运行run_observation_demo。');
scopeGroup(power,'理想相电压',{'ObsPhaseIdeal'},'V',[20 50],1,'T');
scopeGroup(power,'实际相电压',{'ObsPhaseActual'},'V',[20 190],2,'T');
scopeGroup(power,'平均压降',{'ObsPowerDrop'},'V',[20 330],3);
groupOverview(tracking,{'转速','转矩','d轴','q轴','转速误差','d轴误差','q轴误差'},[4 2],'dt');
groupOverview(pi,{'速度PI','d轴PI','q轴PI'},[3 1],'dt');
groupOverview(timing,{'门极','电压指令','测量电压'},[3 1],'T');
groupOverview(measurement,{'真实电流','测量电流','电流误差','电角度','角度误差'},[3 2],'dt');
groupOverview(power,{'理想相电压','实际相电压','平均压降'},[3 1],'T');
end

function groupOverview(path,names,layout,sample)
target=[path '/总览'];add_block('simulink/Sinks/Scope',target,'NumInputPorts',num2str(numel(names)), ...
 'Position',[1150 100 1230 100+40*numel(names)],'SampleTime',sample);
c=get_param(target,'ScopeConfiguration');c.LayoutDimensions=layout;c.TimeSpan='0.12';c.OpenAtSimulationStart=false;
dest=get_param(target,'PortHandles');
for k=1:numel(names)
 source=[path '/' names{k}];ph=get_param(source,'PortHandles');
 if numel(ph.Inport)>1
  mux=[path '/汇总_' names{k}];add_block('simulink/Signal Routing/Mux',mux,'Inputs',num2str(numel(ph.Inport)), ...
   'Position',[1030 50+90*k 1035 110+90*k]);mp=get_param(mux,'PortHandles');
  for j=1:numel(ph.Inport),line=get_param(ph.Inport(j),'Line');src=get_param(line,'SrcPortHandle');add_line(path,src,mp.Inport(j),'autorouting','on');end
  add_line(path,mp.Outport(1),dest.Inport(k),'autorouting','on');
 else
  line=get_param(ph.Inport(1),'Line');src=get_param(line,'SrcPortHandle');add_line(path,src,dest.Inport(k),'autorouting','on');
 end
 original=get_param(source,'ScopeConfiguration');c.ActiveDisplay=num2str(k);c.Title=original.Title;c.ShowLegend=true;
end
set_param(path,'OpenFcn','open_system([gcb ''/总览'']);');
end

function errorScope(path,name,positive,negative,unit,xy,index,wrap)
x=xy(1);y=xy(2);from(path,[name '_正'],positive,[x y x+115 y+20]);from(path,[name '_负'],negative,[x y+45 x+115 y+65]);
add_block('simulink/Math Operations/Sum',[path '/' name '_差'],'Inputs','+-','Position',[x+160 y+15 x+180 y+45]);
wire(path,[name '_正'],1,[name '_差'],1);wire(path,[name '_负'],1,[name '_差'],2);src=[name '_差'];
if wrap
 add_block('simulink/User-Defined Functions/Fcn',[path '/' name '_环绕'],'Expr','atan2(sin(u(1)),cos(u(1)))','Position',[x+210 y+10 x+330 y+50]);
 wire(path,src,1,[name '_环绕'],1);src=[name '_环绕'];
end
add_block('simulink/Sinks/Scope',[path '/' name],'Position',[x+360 y x+420 y+75],'SampleTime','dt');wire(path,src,1,name,1);
c=get_param([path '/' name],'ScopeConfiguration');c.ShowLegend=true;c.Title=[name ' [' unit ']'];c.OpenAtSimulationStart=false;
a=Simulink.Annotation(path,sprintf('%02d %s [%s]',index,name,unit));a.Position=[x+160 y-5];a.FontName='Microsoft YaHei';a.FontSize=11;
end

function scopeGroup(path,name,tags,unit,xy,index,sample)
if nargin<7,sample='dt';end
x=xy(1);y=xy(2);signals=cell(1,numel(tags));
for k=1:numel(tags)
 n=sprintf('%s_%d',name,k);from(path,n,tags{k},[x y+35*(k-1) x+115 y+20+35*(k-1)]);signals{k}=n;
end
scope=[path '/' name];add_block('simulink/Sinks/Scope',scope,'NumInputPorts',num2str(numel(tags)), ...
 'Position',[x+360 y x+420 y+75],'SampleTime',sample);
for k=1:numel(tags),wire(path,signals{k},1,name,k);end
c=get_param(scope,'ScopeConfiguration');c.ShowLegend=true;c.Title=[name ' [' unit ']'];
c.OpenAtSimulationStart=false;
a=Simulink.Annotation(path,sprintf('%02d %s [%s]',index,name,unit));a.Position=[x+160 y-5];a.FontName='Microsoft YaHei';a.FontSize=11;
end
function mask=panel(path,pos,label,description)
add_block('built-in/SubSystem',path,'Position',pos,'BackgroundColor','white','ShowName','off','FontName','Microsoft YaHei','FontSize',11);
mask=Simulink.Mask.create(path);mask.Type=label;mask.Display=sprintf('disp(''%s'');',label);mask.Description=description;
end
function param(mask,name,type,prompt,value),mask.addParameter('Name',name,'Type',type,'Prompt',prompt,'Value',value,'Tunable','off');end
function code=statusIcon(label,flags)
code=sprintf('if %s, color(''red''); disp(''%s：开''); else, color(''black''); disp(''%s：关''); end',strjoin(flags,'||'),label,label);
end
function from(path,name,tag,pos),add_block('simulink/Signal Routing/From',[path '/' name],'GotoTag',tag,'Position',pos);end
function goto(path,name,tag,pos),add_block('simulink/Signal Routing/Goto',[path '/' name],'GotoTag',tag,'TagVisibility','global','Position',pos);end
function tap(path,name,port,var,tag,pos),goto(path,['标签_' var],tag,pos);wire(path,name,port,['标签_' var],1);end
function logSignal(path,name,port,var,sample,pos)
sink=['记录_' var];add_block('simulink/Sinks/To Workspace',[path '/' sink],'VariableName',var,'SaveFormat','Timeseries', ...
 'SampleTime',sample,'MaxDataPoints','inf','Position',pos);wire(path,name,port,sink,1);
end
function wire(path,src,sp,dst,dp)
a=get_param([path '/' src],'PortHandles');b=get_param([path '/' dst],'PortHandles');add_line(path,a.Outport(sp),b.Inport(dp),'autorouting','on');
end
function h=sid(mdl,id),h=Simulink.ID.getHandle([mdl ':' id]);end
function checkPreserved(before,after)
assert(isequaln(before.regions,after.regions)&&isequaln(before.scripts,after.scripts)&&isequaln(before.config,after.config));
for old=before.blocks(:)'
 new=after.blocks(strcmp({after.blocks.sid},old.sid));assert(isscalar(new));
 assert(strcmp(old.path,new.path)&&strcmp(old.type,new.type)&&isequal(old.position,new.position)&&strcmp(old.orientation,new.orientation),'Original block identity/position changed.');
 if ~any(endsWith(old.sid,{':671'})) && ~endsWith(old.path,{'/采样设置/捕获'})
  assert(isequaln(old.inputs,new.inputs),'Original input changed: %s',old.path);
 end
 if endsWith(old.path,'/采样设置/启用'),continue;end
 if strcmp(old.path,'PMSM_FOC_R2026a/采样设置'),continue;end
 if endsWith(old.sid,':695'),continue;end % Display-only mask on the existing log collector.
 assert(isequaln(old.params,new.params),'Original parameter changed: %s',old.path);
end
end
