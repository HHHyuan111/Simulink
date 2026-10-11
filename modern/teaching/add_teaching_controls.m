function add_teaching_controls
% Add local teaching effects to the existing model. Never rebuild the plant.
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);
mdl='PMSM_FOC_R2026a';source=fullfile(root,[mdl '.slx']);
expected='57049d757a95e7d2674a6ad8d99165c5b1eb71985704233892192f3fc0103d5d';
assert(strcmp(teach_hash(source),expected),'Source changed; refusing to overwrite it.');
work=fullfile(root,'.build','teaching_stage1');if ~isfolder(work),mkdir(work);end
copyfile(source,fullfile(work,'before.slx'));
load_system(source);guard=onCleanup(@()close_system(mdl,0));
assert(isempty(get_param(mdl,'InitFcn')),'Unexpected existing model initialization.');
before=teach_snapshot(mdl);mw=get_param(mdl,'ModelWorkspace');
fprintf('TEACHING_BASELINE_120MS\n');
cache=fullfile(work,'before.mat');
if isfile(cache)
 cached=load(cache,'baseline','before');assert(isequaln(before,cached.before),'Baseline snapshot mismatch.');baseline=cached.baseline;
else
 in=Simulink.SimulationInput(mdl);in=setModelParameter(in,'StopTime','0.12');baseline=sim(in);
 save(cache,'baseline','before','-v7');
end

timing=[mdl '/时序设置'];current=[mdl '/采样设置'];angle=[mdl '/角度设置'];
makeTiming(timing,[640 1250 800 1285]);
makeCurrent(current,[2440 1225 2600 1260]);
makeAngle(angle,[2450 580 2610 615]);
mw.MATLABCode=[mw.MATLABCode newline '% Teaching defaults; InitFcn derives active timing from the mask.' newline ...
    'teaching_Ts_speed=Ts_speed;' newline 'teach_pwm_on=0;' newline 'teach_pwm_cycles=1;' newline];
reload(mw);
set_param(mdl,'InitFcn',fileread(fullfile(folder,'teaching_model_init.m')));
set_param(sid(mdl,'155'),'SampleTime','teaching_Ts_speed');
set_param(sid(mdl,'190'),'SampleTime','teaching_Ts_speed');
set_param(sid(mdl,'200'),'GotoTag','Iabc_meas');
set_param(sid(mdl,'199'),'GotoTag','theta_meas');
set_param(sid(mdl,'233'),'GotoTag','theta_meas');
makePwmDelay(mdl);
set_param(mdl,'SimulationCommand','update');
after=teach_snapshot(mdl);scope=checkOriginal(before,after);
fprintf('TEACHING_VALIDATION\n');
report=validate_teaching_controls(baseline);
assert(report.all_passed,'Teaching validation failed; main SLX has not been saved.');
report.original_scope=scope;report.before_sha256=expected;
report.top_blocks=numel(find_system(mdl,'SearchDepth',1,'Type','Block'));
report.total_blocks=numel(after.blocks);report.original_blocks_preserved=numel(before.blocks);
report.defaults=teach_settings(mdl);
assert(allDefaultsOff(mdl));
reload(mw);
checkOriginal(before,teach_snapshot(mdl));
save_system(mdl,source);
report.after_sha256=teach_hash(source);
teach_writejson(fullfile(folder,'teaching_validation.json'),report);
save(fullfile(work,'after.mat'),'report','-v7');
print(['-s' mdl],'-dpng','-r120',fullfile(root,'layout','flat_tidy.png'));
fprintf('TEACHING_SAVED %s\n',report.after_sha256);
end

function makeTiming(path,pos)
mask=baseMask(path,pos,'时序设置', ...
 '运行前设置。速度任务分频与整控制周期输出延迟是教学近似；未模拟 ADC 触发相位、CCR 预装载、抖动或实际中断耗时。');
param(mask,'speed_on','checkbox','速度分频','off','');
param(mask,'speed_divider','edit','速度周期 / 电流周期','20','');
param(mask,'pwm_on','checkbox','输出延迟','off','');
param(mask,'pwm_cycles','edit','延迟周期数 [× dt]','1','');
mask.Display=statusIcon('时序设置',{'speed_on','pwm_on'});
end

function makeCurrent(path,pos)
mask=baseMask(path,pos,'采样设置', ...
 ['运行前设置；参数均为演示值。等效电流域模型：增益/零偏/采样噪声 → 同步采样 → 量化/饱和 → 数字滤波 → 整周期传递延迟。' ...
 '未模拟分流电阻、模拟 RC、放大器或有效采样窗口。全部关闭时直通原信号。']);
tabs=mask.addDialogControl('tabcontainer','tabs');
for item={'error','误差';'adc','ADC';'filter','滤波与延迟'}'
 t=tabs.addDialogControl('tab',item{1});t.Prompt=item{2};
end
param(mask,'bias_on','checkbox','零偏','off','error');
param(mask,'bias_A','edit','三相零偏 [A]','[0.05 -0.03 0]','error');
param(mask,'gain_on','checkbox','增益误差','off','error');
param(mask,'phase_gain','edit','三相增益','[1.01 0.99 1]','error');
param(mask,'noise_on','checkbox','采样噪声','off','error');
param(mask,'noise_rms','edit','每相噪声 RMS [A]','0.02','error');
param(mask,'noise_seed','edit','随机种子','9474','error');
param(mask,'adc_on','checkbox','ADC 量化与饱和','off','adc');
param(mask,'adc_bits','edit','分辨率 [bit，演示]','12','adc');
param(mask,'adc_span','edit','双极量程 ± [A]','20','adc');
param(mask,'filter_on','checkbox','数字低通','off','filter');
param(mask,'filter_hz','edit','等效低通频率 [Hz]','500','filter');
param(mask,'delay_on','checkbox','采样传递延迟','off','filter');
param(mask,'delay_cycles','edit','延迟周期数 [× dt]','1','filter');
mask.addParameter('Name','control_period','Type','edit','Value','dt','Visible','off','Tunable','off');
mask.Display=statusIcon('采样设置',{'bias_on','gain_on','noise_on','adc_on','filter_on','delay_on'});
mask.Initialization=sprintf([ ...
 'validateattributes(bias_A,{''double''},{''vector'',''numel'',3,''real'',''finite''});\n' ...
 'validateattributes(phase_gain,{''double''},{''vector'',''numel'',3,''real'',''finite'',''positive''});\n' ...
 'validateattributes(noise_rms,{''double''},{''scalar'',''real'',''finite'',''nonnegative''});\n' ...
 'validateattributes(noise_seed,{''double''},{''scalar'',''real'',''finite'',''integer'',''>='',1,''<='',4294967293});\n' ...
 'validateattributes(adc_bits,{''double''},{''scalar'',''real'',''finite'',''integer'',''>='',1,''<='',24});\n' ...
 'validateattributes(adc_span,{''double''},{''scalar'',''real'',''finite'',''positive''});\n' ...
 'validateattributes(filter_hz,{''double''},{''scalar'',''real'',''finite'',''positive'',''<'',1/(2*control_period)});\n' ...
 'validateattributes(delay_cycles,{''double''},{''scalar'',''real'',''finite'',''integer'',''>='',1,''<='',20});']);
add_block('simulink/Signal Routing/From',[path '/真实电流'],'GotoTag','Currentabc','Position',[25 95 110 115]);
add_block('simulink/Math Operations/Gain',[path '/增益'],'Gain','1+gain_on*(phase_gain-1)', ...
 'Position',[150 85 245 125]);
add_block('simulink/Sources/Constant',[path '/零偏'],'Value','bias_on*bias_A','Position',[150 160 245 190]);
add_block('simulink/Math Operations/Sum',[path '/偏置求和'],'Inputs','++','Position',[295 90 315 120]);
add_block('simulink/Sources/Random Number',[path '/噪声源'],'Mean','[0 0 0]', ...
 'Variance','noise_rms^2','Seed','noise_seed+[0 1 2]','SampleTime','dt','Position',[150 240 245 280]);
add_block('simulink/Math Operations/Gain',[path '/噪声开关'],'Gain','noise_on','Position',[280 240 350 280]);
add_block('simulink/Math Operations/Sum',[path '/模拟测量'],'Inputs','++','Position',[395 90 415 120]);
add_block('simulink/Discrete/Zero-Order Hold',[path '/捕获'],'SampleTime','dt','Position',[450 85 510 125]);
add_block('simulink/Discontinuities/Quantizer',[path '/量化'],'QuantizationInterval','2*adc_span/2^adc_bits', ...
 'Position',[550 45 620 85]);
add_block('simulink/Discontinuities/Saturation',[path '/量程'],'LowerLimit','-adc_span', ...
 'UpperLimit','adc_span-2*adc_span/2^adc_bits','Position',[660 45 730 85]);
add_block('simulink/Sources/Constant',[path '/ADC开关'],'Value','adc_on','Position',[655 120 720 145]);
addSwitch(path,'ADC选择',[770 85 820 145]);
add_block('simulink/Discrete/Discrete Transfer Fcn',[path '/数字低通'], ...
 'Numerator','[1-exp(-2*pi*filter_hz*dt) 0]','Denominator','[1 -exp(-2*pi*filter_hz*dt)]', ...
 'SampleTime','dt','Position',[870 40 985 80]);
add_block('simulink/Sources/Constant',[path '/滤波开关'],'Value','filter_on','Position',[870 135 950 160]);
addSwitch(path,'滤波选择',[1030 85 1080 145]);
add_block('simulink/Discrete/Delay',[path '/传递延迟'],'DelayLength','delay_cycles', ...
 'InitialCondition','0','SampleTime','dt','Position',[1130 40 1205 80]);
add_block('simulink/Sources/Constant',[path '/延迟开关'],'Value','delay_on','Position',[1120 135 1205 160]);
addSwitch(path,'延迟选择',[1250 85 1300 145]);
add_block('simulink/Sources/Constant',[path '/启用'],'Value','bias_on||gain_on||noise_on||adc_on||filter_on||delay_on', ...
 'Position',[1325 155 1405 180]);
addSwitch(path,'总选择',[1450 85 1500 145]);
add_block('simulink/Signal Routing/Goto',[path '/测量电流'],'GotoTag','Iabc_meas','TagVisibility','global', ...
 'Position',[1560 95 1685 115]);
wire(path,'真实电流',1,'增益',1);wire(path,'增益',1,'偏置求和',1);wire(path,'零偏',1,'偏置求和',2);
wire(path,'偏置求和',1,'模拟测量',1);wire(path,'噪声源',1,'噪声开关',1);wire(path,'噪声开关',1,'模拟测量',2);
wire(path,'模拟测量',1,'捕获',1);wire(path,'捕获',1,'量化',1);wire(path,'量化',1,'量程',1);
wire(path,'量程',1,'ADC选择',1);wire(path,'ADC开关',1,'ADC选择',2);wire(path,'捕获',1,'ADC选择',3);
wire(path,'ADC选择',1,'数字低通',1);wire(path,'数字低通',1,'滤波选择',1);
wire(path,'滤波开关',1,'滤波选择',2);wire(path,'ADC选择',1,'滤波选择',3);
wire(path,'滤波选择',1,'传递延迟',1);wire(path,'传递延迟',1,'延迟选择',1);
wire(path,'延迟开关',1,'延迟选择',2);wire(path,'滤波选择',1,'延迟选择',3);
wire(path,'延迟选择',1,'总选择',1);wire(path,'启用',1,'总选择',2);wire(path,'真实电流',1,'总选择',3);
wire(path,'总选择',1,'测量电流',1);
logSignal(path,'真实电流',1,'log_iabc_true',[25 360 160 390]);
logSignal(path,'总选择',1,'log_iabc_meas',[1450 360 1585 390]);
logSignal(path,'噪声开关',1,'log_iabc_noise',[280 360 415 390]);
logSignal(path,'ADC选择',1,'log_iabc_adc',[770 360 905 390]);
logSignal(path,'滤波选择',1,'log_iabc_filter',[1030 360 1165 390]);
end

function makeAngle(path,pos)
mask=baseMask(path,pos,'角度设置', ...
 '运行前设置。使用电角单位；偏置与量化为电角度，延迟按 dt 整周期。全部关闭时直通原角度；暂不实现角度预测、传感器接口或丢帧。');
param(mask,'bias_on','checkbox','角度偏置','off','');
param(mask,'bias_deg','edit','偏置 [电角度 °]','2','');
param(mask,'quant_on','checkbox','角度量化','off','');
param(mask,'step_deg','edit','量化步长 [电角度 °]','0.1','');
param(mask,'delay_on','checkbox','角度延迟','off','');
param(mask,'delay_cycles','edit','延迟周期数 [× dt]','1','');
mask.Display=statusIcon('角度设置',{'bias_on','quant_on','delay_on'});
mask.Initialization=sprintf([ ...
 'validateattributes(bias_deg,{''double''},{''scalar'',''real'',''finite''});\n' ...
 'validateattributes(step_deg,{''double''},{''scalar'',''real'',''finite'',''positive'',''<='',360});\n' ...
 'validateattributes(delay_cycles,{''double''},{''scalar'',''real'',''finite'',''integer'',''>='',1,''<='',20});']);
add_block('simulink/Signal Routing/From',[path '/真实角度'],'GotoTag','theta_e','Position',[25 75 110 95]);
add_block('simulink/Sources/Constant',[path '/偏置'],'Value','bias_on*bias_deg*pi/180','Position',[25 155 115 185]);
add_block('simulink/Math Operations/Sum',[path '/偏置求和'],'Inputs','++','Position',[155 75 175 95]);
add_block('simulink/Discontinuities/Quantizer',[path '/量化'],'QuantizationInterval','step_deg*pi/180','Position',[220 30 300 70]);
add_block('simulink/Sources/Constant',[path '/量化开关'],'Value','quant_on','Position',[220 120 300 150]);
addSwitch(path,'量化选择',[350 60 400 120]);
add_block('simulink/User-Defined Functions/Fcn',[path '/角度环绕'],'Expr','u(1)-2*pi*floor(u(1)/(2*pi))', ...
 'Position',[445 70 605 110]);
add_block('simulink/Discrete/Delay',[path '/传递延迟'],'DelayLength','delay_cycles','InitialCondition','0', ...
 'SampleTime','dt','Position',[650 25 730 65]);
add_block('simulink/Sources/Constant',[path '/延迟开关'],'Value','delay_on','Position',[650 125 730 155]);
addSwitch(path,'延迟选择',[780 60 830 120]);
add_block('simulink/Sources/Constant',[path '/启用'],'Value','bias_on||quant_on||delay_on','Position',[880 135 970 165]);
addSwitch(path,'总选择',[1020 60 1070 120]);
add_block('simulink/Signal Routing/Goto',[path '/测量角度'],'GotoTag','theta_meas','TagVisibility','global', ...
 'Position',[1120 75 1245 95]);
add_block('simulink/Math Operations/Sum',[path '/角度差'],'Inputs','+-','Position',[1120 225 1140 255]);
add_block('simulink/User-Defined Functions/Fcn',[path '/最短角差'], ...
 'Expr','atan2(sin(u(1)),cos(u(1)))','Position',[1190 220 1370 260]);
wire(path,'真实角度',1,'偏置求和',1);wire(path,'偏置',1,'偏置求和',2);
wire(path,'偏置求和',1,'量化',1);wire(path,'量化',1,'量化选择',1);wire(path,'量化开关',1,'量化选择',2);
wire(path,'偏置求和',1,'量化选择',3);wire(path,'量化选择',1,'角度环绕',1);
wire(path,'角度环绕',1,'传递延迟',1);wire(path,'传递延迟',1,'延迟选择',1);
wire(path,'延迟开关',1,'延迟选择',2);wire(path,'角度环绕',1,'延迟选择',3);
wire(path,'延迟选择',1,'总选择',1);wire(path,'启用',1,'总选择',2);wire(path,'真实角度',1,'总选择',3);
wire(path,'总选择',1,'测量角度',1);wire(path,'总选择',1,'角度差',1);wire(path,'真实角度',1,'角度差',2);
wire(path,'角度差',1,'最短角差',1);
logSignal(path,'真实角度',1,'log_theta_true',[25 330 160 360]);
logSignal(path,'总选择',1,'log_theta_meas',[1020 330 1155 360]);
logSignal(path,'最短角差',1,'log_theta_error',[1190 330 1325 360]);
end

function makePwmDelay(parent)
out=getfullname(sid(parent,'295'));
ph=get_param(out,'PortHandles');line=get_param(ph.Inport(1),'Line');src=get_param(line,'SrcPortHandle');
delete_line(line);
path=[parent '/输出延迟'];
add_block('built-in/SubSystem',path,'Position',[320 945 345 975],'BackgroundColor','white', ...
 'ShowName','off','FontName','Microsoft YaHei','FontSize',9);
mask=Simulink.Mask.create(path);mask.Display='disp(''延迟'');';
mask.Description='整控制周期的集中输出延迟；在时序设置中启用。不是实际 CCR 预装载事件模型。';
add_block('simulink/Sources/In1',[path '/指令'],'Position',[25 75 55 95]);
add_block('simulink/Discrete/Delay',[path '/周期延迟'],'DelayLength','teach_pwm_cycles','InitialCondition','0', ...
 'SampleTime','dt','Position',[100 25 180 65]);
add_block('simulink/Sources/Constant',[path '/启用'],'Value','teach_pwm_on','Position',[100 120 180 150]);
addSwitch(path,'选择',[230 60 280 120]);
add_block('simulink/Sinks/Out1',[path '/生效'],'Position',[335 80 365 100]);
wire(path,'指令',1,'周期延迟',1);wire(path,'周期延迟',1,'选择',1);wire(path,'启用',1,'选择',2);
wire(path,'指令',1,'选择',3);wire(path,'选择',1,'生效',1);
logSignal(path,'指令',1,'log_Tcm_requested',[25 230 160 260]);
logSignal(path,'选择',1,'log_Tcm_applied',[230 230 365 260]);
inph=get_param(path,'PortHandles');add_line(parent,src,inph.Inport(1),'autorouting','on');
add_line(parent,inph.Outport(1),ph.Inport(1),'autorouting','on');
end

function mask=baseMask(path,pos,label,description)
add_block('built-in/SubSystem',path,'Position',pos,'BackgroundColor','white','ShowName','off');
set_param(path,'FontName','Microsoft YaHei','FontSize',11,'Tag','TeachingControl');
mask=Simulink.Mask.create(path);mask.Type=label;mask.Description=description;
mask.Display=sprintf('disp(''%s'');',label);
end
function param(mask,name,type,prompt,value,container)
args={'Name',name,'Type',type,'Prompt',prompt,'Value',value,'Tunable','off'};
if ~isempty(container),args=[args {'Container',container}];end
mask.addParameter(args{:});
end
function code=statusIcon(label,flags)
code=sprintf('if %s, color(''red''); disp(''%s：开''); else, color(''black''); disp(''%s：关''); end', ...
 strjoin(flags,'||'),label,label);
end
function addSwitch(parent,name,pos)
add_block('simulink/Signal Routing/Switch',[parent '/' name], ...
 'Criteria','u2 ~= 0','Position',pos);
end
function logSignal(parent,name,port,var,pos)
sink=['记录_' var];
add_block('simulink/Sinks/To Workspace',[parent '/' sink],'VariableName',var, ...
 'SaveFormat','Timeseries','SampleTime','dt','MaxDataPoints','inf','Position',pos);
wire(parent,name,port,sink,1);
end
function wire(parent,src,sp,dst,dp)
a=get_param([parent '/' src],'PortHandles');b=get_param([parent '/' dst],'PortHandles');
add_line(parent,a.Outport(sp),b.Inport(dp),'autorouting','on');
end
function h=sid(mdl,id),h=Simulink.ID.getHandle([mdl ':' id]);end
function tf=allDefaultsOff(mdl)
s=teach_settings(mdl);tf=true;
for k=1:numel(s),for j=1:numel(s(k).parameters)
 p=s(k).parameters(j);if endsWith(p.name,'_on'),tf=tf&&strcmp(p.value,'off');end
end,end
end
function r=checkOriginal(a,b)
assert(numel(a.blocks)==329);
allow={'155','SampleTime';'190','SampleTime';'200','GotoTag';'199','GotoTag';'233','GotoTag'};
changed=struct('sid',{},'parameter',{});
for k=1:numel(a.blocks)
 old=a.blocks(k);idx=find(strcmp({b.blocks.sid},old.sid));assert(isscalar(idx),'Original block missing.');new=b.blocks(idx);
 assert(strcmp(old.path,new.path)&&strcmp(old.type,new.type)&&isequal(old.position,new.position)&& ...
  strcmp(old.orientation,new.orientation),'Original block moved or replaced: %s',old.path);
 oldMask=old.mask;newMask=new.mask;
 if endsWith(old.sid,':155')
  oldMask=rmfield(oldMask,'MaskValues');newMask=rmfield(newMask,'MaskValues');
 end
 assert(isequaln(oldMask,newMask),'Original mask changed: %s',old.path);
 if ~endsWith(old.sid,':295')
  assert(isequaln(old.inputs,new.inputs),'Original wiring changed: %s',old.path);
 end
 names=fieldnames(old.params);
 for j=1:numel(names)
  key=names{j};if isequaln(old.params.(key),new.params.(key)),continue;end
  short=extractAfter(old.sid,':');assert(any(strcmp(allow(:,1),short)&strcmp(allow(:,2),key)), ...
   'Unexpected original parameter change: %s / %s',old.path,key);
  changed(end+1)=struct('sid',char(short),'parameter',key); %#ok<AGROW>
 end
end
assert(numel(changed)==5);assert(isequaln(a.regions,b.regions)&&isequaln(a.scripts,b.scripts)&&isequaln(a.config,b.config));
r=struct('original_blocks',329,'original_positions_and_regions_unchanged',true, ...
 'original_scripts_and_pi_math_unchanged',true,'changed_original_parameters',changed, ...
 'only_original_rewired_input','Demux2: optional output delay inserted after SVPWM');
end
