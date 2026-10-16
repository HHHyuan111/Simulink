function result=pmsm_sensorless_model(action,mdl)
% Reversible observer only. All new signal tags are scoped to this subsystem.
if nargin<1,action='install';end
if nargin<2,mdl='PMSM_FOC_R2026a';end
path=[mdl '/无感观测'];here=fileparts(mfilename('fullpath'));
if strcmp(action,'installed'),result=bdIsLoaded(mdl)&&getSimulinkBlockHandle(path)>0;return;end
assert(bdIsLoaded(mdl)&&strcmp(get_param(mdl,'SimulationStatus'),'stopped'));
ws=get_param(mdl,'ModelWorkspace');
if strcmp(action,'remove')
 if getSimulinkBlockHandle(path)<0,result=false;return;end
 backup=get_param(path,'UserData');delete_block(path);
 for k=1:numel(backup.external_blocks),if getSimulinkBlockHandle(backup.external_blocks{k})>0,delete_block(backup.external_blocks{k});end,end
 set_param(mdl,'InitFcn',backup.init,'PreSaveFcn',backup.presave,'StopFcn',backup.stop);
 clear(ws);for k=1:numel(backup.workspace),assignin(ws,backup.workspace(k).name,backup.workspace(k).value);end
 set_param(mdl,'Dirty',backup.dirty);result=true;return;
end
assert(strcmp(action,'install')&&getSimulinkBlockHandle(path)<0,'无感观测已经接入。');
% The legacy Goto named Tcm is the REQUEST, not the applied CCR output.
% Tap the same source as the existing applied-threshold log instead.
lp=get_param([mdl '/输出延迟/记录_log_Tcm_applied'],'PortHandles');
appliedSource=get_param(get_param(lp.Inport,'Line'),'SrcPortHandle');
mp=get_param([mdl '/采样设置/测量电流'],'PortHandles');
currentSource=get_param(get_param(mp.Inport,'Line'),'SrcPortHandle');
feval(mdl,[],[],[],'compile');
sourceDimensions=get_param(appliedSource,'CompiledPortDimensions');
currentDimensions=get_param(currentSource,'CompiledPortDimensions');
feval(mdl,[],[],[],'term');
backup=struct('init',get_param(mdl,'InitFcn'),'presave',get_param(mdl,'PreSaveFcn'),...
 'stop',get_param(mdl,'StopFcn'),'dirty',get_param(mdl,'Dirty'),'workspace',struct('name',{},'value',{}),...
 'external_blocks',{{[mdl '/输出延迟/无感生效阈值']}});
vars=whos(ws);for k=1:numel(vars),backup.workspace(k)=struct('name',vars(k).name,'value',getVariable(ws,vars(k).name));end
part(mdl,'built-in/SubSystem','无感观测',[2300 1265 2450 1305],'BackgroundColor','[0.80 0.89 0.98]');
set_param(path,'UserData',backup);
try
 part([mdl '/输出延迟'],'simulink/Signal Routing/Goto','无感生效阈值',[700 520 900 545],...
  'GotoTag','SLessAppliedThreshold','TagVisibility','global');
 gp=get_param(backup.external_blocks{1},'PortHandles');add_line([mdl '/输出延迟'],appliedSource,gp.Inport,'autorouting','on');
 mask=Simulink.Mask.create(path);mask.Type='Sensorless observer';mask.Display="disp('无感观测')";
 mask.addParameter('Name','enabled','Type','checkbox','Prompt','旁路观测','Value','on','Tunable','off');
 entries={'R_hat','观测相电阻 [Ω]',getVariable(ws,'Rs');'L_hat','观测电感 [H]',getVariable(ws,'Ld');...
  'Kslide_V','滑模注入 [V]',14;'boundary_A','边界层 [A]',.2;'emf_filter_hz','反电动势滤波 [Hz]',800;...
  'pll_fn_hz','PLL自然频率 [Hz]',60;'pll_zeta','PLL阻尼比',.707;...
  'omega_limit_rad_s','电角速度限值 [rad/s]',2000;'direction','旋转方向 ±1 / 0',1};
 for k=1:size(entries,1)
  mask.addParameter('Name',entries{k,1},'Type','edit','Prompt',entries{k,2},'Value',num2str(entries{k,3},17),'Tunable','off');
 end
 for row={'derived_a','离散 a';'derived_b','离散 b [A/V]';'derived_kp','PLL Kp [1/s]';'derived_ki','PLL Ki [1/s²]'}'
  mask.addParameter('Name',row{1},'Type','edit','Prompt',row{2},'Value','0','Enabled','off','Tunable','off');
 end
 % Configuration is published once per model initialization; no plant writes.
 config_sources={'参数','sless_cfg','SLess_cfg';'方向','sless_direction','SLess_direction';...
  '启用','sless_enabled','SLess_enabled'};
 for k=1:size(config_sources,1)
  y=30+55*(k-1);part(path,'simulink/Sources/Constant',config_sources{k,1},[25 y 115 y+25],'Value',config_sources{k,2});
  route(path,config_sources{k,1},1,config_sources{k,3},[150 y 285 y+25]);
 end
 input=sub(path,'采样输入',[360 40 510 100]);
 from(input,'三相电流','Iabc_meas',[25 30 145 55]);
 part(input,'simulink/Signal Attributes/Signal Specification','原电流尺寸',[165 25 215 65],...
  'Dimensions',mat2str(currentDimensions(2:end)));
 part(input,'simulink/Discrete/Zero-Order Hold','任务采样',[250 25 330 65],'SampleTime','timing_control_sample');
 part(input,'simulink/Math Operations/Gain','Clarke',[365 25 510 65],...
  'Gain','[2/3 -1/3 -1/3;0 1/sqrt(3) -1/sqrt(3)]','Multiplication','Matrix(K*u)');
 wire(input,'三相电流',1,'原电流尺寸',1);wire(input,'原电流尺寸',1,'任务采样',1);wire(input,'任务采样',1,'Clarke',1);
 part(input,'simulink/Math Operations/Reshape','电流列向量',[545 25 660 65],'OutputDimensionality','Column vector (2-D)');
 wire(input,'Clarke',1,'电流列向量',1);route(input,'电流列向量',1,'SLess_current',[700 30 850 55]);
 from(input,'ADC状态','ObsADCTiming',[25 125 145 150]);
 part(input,'simulink/Sources/Constant','采样模式',[25 190 145 215],'Value','sless_adc_mode');
 chart(input,'有效样本','sless_input_block.m','timing_control_sample',[205 120 355 220]);
 wire(input,'ADC状态',1,'有效样本',1);wire(input,'采样模式',1,'有效样本',2);
 route(input,'有效样本',1,'SLess_sample_valid',[400 155 560 180]);
 part(input,'simulink/Sources/Digital Clock','任务时刻',[25 280 145 310],'SampleTime','timing_control_sample');
 route(input,'任务时刻',1,'SLess_time',[185 280 335 310]);

 voltage=sub(path,'区间电压',[570 40 720 100]);
 vtags={'生效阈值','SLessAppliedThreshold';'实际载波','ObsCarrier';'控制母线','UDC';'CCR状态','ObsPWMTiming'};
 part(voltage,'simulink/Sources/Digital Clock','原生时刻',[20 25 140 50],'SampleTime','timing_h');
 for k=1:size(vtags,1),from(voltage,vtags{k,1},vtags{k,2},[20 80+55*(k-1) 150 105+55*(k-1)]);end
 part(voltage,'simulink/Signal Attributes/Signal Specification','原阈值尺寸',[165 75 215 110],...
  'Dimensions',mat2str(sourceDimensions(2:end)));
 part(voltage,'simulink/Math Operations/Reshape','阈值行向量',[245 75 290 115],'OutputDimensionality','Row vector (2-D)');
 wire(voltage,'生效阈值',1,'原阈值尺寸',1);wire(voltage,'原阈值尺寸',1,'阈值行向量',1);
 part(voltage,'simulink/Sources/Constant','区间参数',[20 305 150 330],'Value','sless_voltage_cfg');
 chart(voltage,'分段累计','sless_voltage_block.m','timing_h',[230 60 420 310]);
 source={'原生时刻','阈值行向量','实际载波','控制母线','CCR状态','区间参数'};
 for k=1:numel(source),wire(voltage,source{k},1,'分段累计',k);end
 tags={'SLess_voltage','SLess_interval','SLess_ready','SLess_native'};
 for k=1:4,route(voltage,'分段累计',k,tags{k},[480 70+65*(k-1) 650 95+65*(k-1)]);end
 % Explicit control-rate transfer of the already completed physical interval.
 for k=1:3
  name=['发布' num2str(k)];from(voltage,['累计' num2str(k)],tags{k},[25 390+55*k 180 415+55*k]);
  part(voltage,'simulink/Discrete/Zero-Order Hold',name,[220 385+55*k 320 425+55*k],'SampleTime','timing_control_sample');
  wire(voltage,['累计' num2str(k)],1,name,1);
  route(voltage,name,1,[tags{k} '_sample'],[370 390+55*k 575 415+55*k]);
 end
 from(voltage,'原生来源','SLess_native',[25 650 180 675]);
 part(voltage,'simulink/User-Defined Functions/Fcn','生效序号',[220 645 330 680],'Expr','u(9)');
 wire(voltage,'原生来源',1,'生效序号',1);
 part(voltage,'simulink/Discrete/Zero-Order Hold','序号采样',[370 645 470 680],'SampleTime','timing_control_sample');
 wire(voltage,'生效序号',1,'序号采样',1);route(voltage,'序号采样',1,'SLess_sequence',[510 650 680 675]);

 reset=sub(path,'执行许可',[780 40 930 100]);
 feed(reset,{'区间准备','SLess_ready_sample';'观测启用','SLess_enabled'},'复位','sless_reset_block.m');
 route(reset,'复位',1,'SLess_reset',[410 55 560 80]);

 smo=sub(path,'滑模观测',[360 200 510 260]);
 feed(smo,{'测量电流','SLess_current';'施加电压','SLess_voltage_sample';'样本有效','SLess_sample_valid';...
  '复位','SLess_reset';'参数','SLess_cfg'},'隐式校正','sless_smo_block.m');
 for row={1,'SLess_i_hat';2,'SLess_residual';3,'SLess_injection'}'
  route(smo,'隐式校正',row{1},row{2},[410 30+65*row{1} 570 55+65*row{1}]);
 end

 emf=sub(path,'反电动势',[570 200 720 260]);
 feed(emf,{'滑模注入','SLess_injection';'上拍速度','SLess_omega_previous';'方向','SLess_direction';...
  '样本有效','SLess_sample_valid';'复位','SLess_reset';'参数','SLess_cfg'},'滤波校正','sless_emf_block.m');
 tags={'SLess_emf','SLess_vector','SLess_theta_raw','SLess_phase','SLess_magnitude'};
 for k=1:5,route(emf,'滤波校正',k,tags{k},[410 25+55*k 585 50+55*k]);end

 pll=sub(path,'锁相环',[780 200 930 260]);
 feed(pll,{'正交矢量','SLess_vector';'反电动势幅值','SLess_magnitude';'方向','SLess_direction';...
  '样本有效','SLess_sample_valid';'复位','SLess_reset';'观测启用','SLess_enabled';'参数','SLess_cfg'},'归一化PLL','sless_pll_block.m');
 tags={'SLess_theta','SLess_omega','SLess_pll_error','SLess_integral','SLess_saturated','SLess_speed'};
 for k=1:6,route(pll,'归一化PLL',k,tags{k},[415 20+55*k 585 45+55*k]);end
 from(pll,'本拍速度','SLess_omega',[25 465 150 490]);
 part(pll,'simulink/Discrete/Unit Delay','速度历史',[190 460 290 500],'SampleTime','timing_control_sample','InitialCondition','0');
 wire(pll,'本拍速度',1,'速度历史',1);route(pll,'速度历史',1,'SLess_omega_previous',[330 465 535 490]);

 validity=sub(path,'有效判断',[990 200 1140 260]);
 feed(validity,{'电流残差','SLess_residual';'鉴相误差','SLess_pll_error';'反电动势幅值','SLess_magnitude';...
  '速度饱和','SLess_saturated';'样本有效','SLess_sample_valid';'方向','SLess_direction';...
  '复位','SLess_reset';'参数','SLess_cfg'},'锁定判断','sless_validity_block.m');
 route(validity,'锁定判断',1,'SLess_valid',[415 80 580 105]);
 route(validity,'锁定判断',2,'SLess_state',[415 155 580 180]);
 route(validity,'锁定判断',3,'SLess_history',[415 230 580 255]);

 observe=sub(path,'观测',[990 40 1140 100]);
 make_observation(observe,mdl);
 % Scope every added tag inside this layer; no new global Goto exports.
 gotos=find_system(path,'LookUnderMasks','all','BlockType','Goto');
 for k=1:numel(gotos)
  tag=get_param(gotos{k},'GotoTag');
  part(path,'simulink/Signal Routing/Goto Tag Visibility',['可见域_' tag],...
   [25+195*mod(k-1,6) 370+35*floor((k-1)/6) 190+195*mod(k-1,6) 392+35*floor((k-1)/6)],...
   'GotoTag',tag,'ShowName','off');
 end
 set_param(mdl,'InitFcn',sprintf('%s\npmsm_sensorless_init(bdroot);',backup.init),...
  'PreSaveFcn','error(''sensorless:SaveGuard'',''请先退出无感观测，再保存原模型。'');');
 pmsm_sensorless_init(mdl);result=path;
catch err
 try,pmsm_sensorless_model('remove',mdl);catch rollback,err=addCause(err,rollback);end
 rethrow(err);
end
 function p=sub(parent,name,position)
  part(parent,'built-in/SubSystem',name,position,'BackgroundColor','white');p=[parent '/' name];
 end
 function chart(parent,name,source,period,position)
  part(parent,'simulink/User-Defined Functions/MATLAB Function',name,position);
  rt=sfroot;ch=rt.find('-isa','Stateflow.EMChart','Path',[parent '/' name]);
  ch.Script=fileread(fullfile(here,'blocks',source));ch.ChartUpdate='DISCRETE';ch.SampleTime=period;ch.VectorOutputs1D=false;
  type_chart(ch,source);
 end
 function feed(parent,rows,name,source)
  chart(parent,name,source,'timing_control_sample',[220 45 365 65+50*size(rows,1)]);
  for j=1:size(rows,1)
   from(parent,rows{j,1},rows{j,2},[20 40+55*(j-1) 165 65+55*(j-1)]);
   wire(parent,rows{j,1},1,name,j);
  end
 end
end

function part(p,lib,n,pos,varargin)
if strcmp(lib,'simulink/Sources/Constant'),varargin=[varargin {'VectorParams1D','off'}];end
add_block(lib,[p '/' n],'Position',pos,'ShowName','on',varargin{:});
end
function wire(p,a,ap,b,bp),add_line(p,[a '/' num2str(ap)],[b '/' num2str(bp)],'autorouting','on');end
function from(p,n,tag,pos),part(p,'simulink/Signal Routing/From',n,pos,'GotoTag',tag);end
function route(p,src,port,tag,pos)
part(p,'simulink/Signal Routing/Goto',['发布_' tag],pos,'GotoTag',tag,'TagVisibility','scoped');
wire(p,src,port,['发布_' tag],1);
end

function make_observation(p,mdl)
% Evaluation imports never feed an estimator block.
from(p,'真实角度','theta_e',[25 30 155 55]);from(p,'真实转速','speed',[25 95 155 120]);
for row={'真实角度','SLess_truth_theta';'真实转速','SLess_truth_speed'}'
 part(p,'simulink/Discrete/Zero-Order Hold',['采样_' row{1}],[190 25+65*strcmp(row{1},'真实转速') 290 65+65*strcmp(row{1},'真实转速')],'SampleTime','timing_control_sample');
 wire(p,row{1},1,['采样_' row{1}],1);route(p,['采样_' row{1}],1,row{2},[330 30+65*strcmp(row{1},'真实转速') 535 55+65*strcmp(row{1},'真实转速')]);
end
spec={'input_i','SLess_current';'input_v','SLess_voltage_sample';'voltage_interval','SLess_interval_sample';'applied_sequence','SLess_sequence';...
 'i_hat','SLess_i_hat';'i_residual','SLess_residual';'injection','SLess_injection';'emf','SLess_emf';...
 'emf_magnitude','SLess_magnitude';'theta_raw','SLess_theta_raw';'phase_correction','SLess_phase';...
 'theta','SLess_theta';'omega_e','SLess_omega';'speed','SLess_speed';'pll_error','SLess_pll_error';...
 'pll_integral','SLess_integral';'pll_saturated','SLess_saturated';'valid','SLess_valid';'state','SLess_state';...
 'truth_theta','SLess_truth_theta';'truth_speed','SLess_truth_speed';'history','SLess_history';...
 'sample_valid','SLess_sample_valid';'reset','SLess_reset';'control_time','SLess_time'};
for k=1:size(spec,1)
 x=25+610*floor((k-1)/12);y=210+55*mod(k-1,12);name=['源_' spec{k,1}];
 from(p,name,spec{k,2},[x y x+205 y+24]);
 part(p,'simulink/Sinks/To Workspace',['记录_' spec{k,1}],[x+260 y x+500 y+24],...
  'VariableName',['obs_sless_' spec{k,1}],'SaveFormat','Timeseries','SampleTime','timing_control_sample','MaxDataPoints','inf');
 wire(p,name,1,['记录_' spec{k,1}],1);
end
from(p,'原生电压来源','SLess_native',[25 940 230 965]);
part(p,'simulink/Sinks/To Workspace','原生来源记录',[285 940 530 965],...
 'VariableName','obs_sless_voltage_native','SaveFormat','Timeseries','SampleTime','timing_h','MaxDataPoints','inf');
wire(p,'原生电压来源',1,'原生来源记录',1);
% Existing native Scope is cloned to retain the established web-scope format.
create_scope(p,mdl,'角度与速度',[1300 80 1440 150],[2 2],...
 {{'SLess_truth_theta',1,'真值';'SLess_theta',1,'估计'},'电角度','°',180/pi;...
  {'SLess_truth_speed',1,'真值';'SLess_speed',1,'估计'},'转速','rpm',1;...
  {'SLess_theta',1,'估计';'SLess_truth_theta',1,'真值'},'角度误差','°',0;...
  {'SLess_valid',1,'有效';'SLess_state',1,'状态';'SLess_saturated',1,'饱和'},'状态','',1});
create_scope(p,mdl,'观测器内部',[1300 220 1440 290],[3 2],...
 {{'SLess_current',1,'测量';'SLess_i_hat',1,'估计'},'alpha电流','A',1;...
  {'SLess_current',2,'测量';'SLess_i_hat',2,'估计'},'beta电流','A',1;...
  {'SLess_emf',1,'alpha';'SLess_emf',2,'beta'},'反电动势','V',1;...
  {'SLess_pll_error',1,'鉴相误差'},'PLL误差','',1;...
  {'SLess_integral',1,'积分'},'PLL积分','rad/s',1;...
  {'SLess_phase',1,'校正'},'相位校正','°',180/pi});
end

function create_scope(p,mdl,name,pos,layout,groups)
scope=[p '/' name];part(p,[mdl '/跟踪观测/总览'],name,pos,'NumInputPorts',num2str(size(groups,1)),...
 'SampleTime','timing_control_sample','OpenFcn',sprintf('pmsm_sensorless_scope(''open'',''%s'');',scope),'StopFcn','');
for k=1:size(groups,1)
 parent=[p '/' name '_信号' num2str(k)];part(p,'built-in/SubSystem',[name '_信号' num2str(k)],...
  [1550 50+80*(k-1)+400*strcmp(name,'观测器内部') 1700 105+80*(k-1)+400*strcmp(name,'观测器内部')]);
 rows=groups{k,1};lib='simulink/Signal Routing/Bus Creator';if groups{k,4}==0,lib='simulink/Signal Routing/Mux';end
 part(parent,lib,'合并',[480 30 485 40+50*size(rows,1)],'Inputs',num2str(size(rows,1)));
 for j=1:size(rows,1)
  src=['来源' num2str(j)];pick=['通道' num2str(j)];from(parent,src,rows{j,1},[20 35+60*(j-1) 185 60+60*(j-1)]);
  expr=sprintf('u(%d)*%.17g',rows{j,2},groups{k,4});if groups{k,4}==0,expr=sprintf('u(%d)',rows{j,2});end
  convert=['数值' num2str(j)];part(parent,'simulink/Signal Attributes/Data Type Conversion',convert,[200 35+60*(j-1) 250 60+60*(j-1)],'OutDataTypeStr','double');
  part(parent,'simulink/User-Defined Functions/Fcn',pick,[285 30+60*(j-1) 430 65+60*(j-1)],'Expr',expr);
  wire(parent,src,1,convert,1);wire(parent,convert,1,pick,1);
  ln=add_line(parent,[pick '/1'],['合并/' num2str(j)],'autorouting','on');set_param(ln,'Name',rows{j,3});
 end
 if groups{k,4}==0
  part(parent,'simulink/User-Defined Functions/Fcn','环绕误差',[530 45 760 85],'Expr','atan2(sin(u(1)-u(2)),cos(u(1)-u(2)))*180/pi');
  wire(parent,'合并',1,'环绕误差',1);output='环绕误差';
 else,output='合并';end
 part(parent,'built-in/Outport','输出',[820 55 850 75]);wire(parent,output,1,'输出',1);
 wire(p,[name '_信号' num2str(k)],1,name,k);
end
c=get_param(scope,'ScopeConfiguration');c.LayoutDimensions=layout;c.Position=[100 70 1160 810];
c.FrameBasedProcessing=false;c.TimeSpan='0.1';c.TimeUnits='Metric';c.OpenAtSimulationStart=false;
c.DataLogging=false;c.ShowLegend=true;
for k=1:size(groups,1),c.ActiveDisplay=num2str(k);c.Title=groups{k,2};c.YLabel=groups{k,3};c.ShowGrid=true;c.ShowLegend=true;c.AxesScaling='Auto';end
c.ActiveDisplay='1';
end

function type_chart(ch,source)
switch source
 case 'sless_voltage_block.m'
  sizes={'t','1';'threshold','[1 3]';'carrier','1';'bus','1';'diag','[1 12]';'cfg','[1 6]';...
   'weighted','[2 1]';'interval','[2 1]';'ready','1';'native','[12 1]'};boolean={'ready'};
 case 'sless_input_block.m'
  sizes={'diag','[1 15]';'mode','[1 2]';'valid','1'};boolean={'valid'};
 case 'sless_reset_block.m'
  sizes={'ready','1';'enabled','1';'reset','1'};boolean={'ready','reset'};
 case 'sless_smo_block.m'
  sizes={'current','[2 1]';'voltage','[2 1]';'valid','1';'reset','1';'cfg','[1 18]';...
   'estimate','[2 1]';'residual','[2 1]';'injection','[2 1]'};boolean={'valid','reset'};
 case 'sless_emf_block.m'
  sizes={'injection','[2 1]';'omega_previous','1';'direction','1';'valid','1';'reset','1';'cfg','[1 18]';...
   'emf','[2 1]';'vector','[2 1]';'raw_angle','1';'phase','1';'magnitude','1'};boolean={'valid','reset'};
 case 'sless_pll_block.m'
  sizes={'vector','[2 1]';'magnitude','1';'direction','1';'valid','1';'reset','1';'enabled','1';'cfg','[1 18]';...
   'theta','1';'omega','1';'error','1';'integral','1';'saturated','1';'speed','1'};boolean={'valid','reset','saturated'};
 case 'sless_validity_block.m'
  sizes={'residual','[2 1]';'error','1';'magnitude','1';'saturated','1';'sample_valid','1';...
   'direction','1';'reset','1';'cfg','[1 18]';'valid','1';'state','1';'history','[3 1]'};
  boolean={'saturated','sample_valid','reset','valid'};
 otherwise,error('sensorless:Interface','未声明的模块接口。');
end
for k=1:size(sizes,1)
 data=ch.find('-isa','Stateflow.Data','Name',sizes{k,1});data.Props.Array.Size=sizes{k,2};
 data.DataType='double';if ismember(sizes{k,1},boolean),data.DataType='boolean';end
end
end
