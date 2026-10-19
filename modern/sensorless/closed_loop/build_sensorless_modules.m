function report = build_sensorless_modules(mdl)
% Expand the accepted discrete observer equations into ordinary Simulink blocks.
% Initialization still owns parameter derivation; no coefficient is retuned here.
root = [mdl '/无感观测'];
replace([root '/滑模观测/隐式校正'], @smo, ...
    {'测量电流','[2 1]';'区间电压','[2 1]';'样本有效','1';'复位','1';'观测参数','[1 18]'}, ...
    {'估计电流','电流残差','滑模注入'}, [3 4]);
replace([root '/反电动势/滤波校正'], @emf, ...
    {'滑模注入','[2 1]';'上拍速度','1';'方向','1';'样本有效','1';'复位','1';'观测参数','[1 18]';'前端参数','[1 35]'}, ...
    {'反电势','校正矢量','原始角度','链路相位','反电势幅值','前端相位'}, [4 5]);
replace([root '/锁相环/归一化PLL'], @pll, ...
    {'正交矢量','[2 1]';'反电势幅值','1';'方向','1';'样本有效','1';'复位','1';'观测启用','1';'观测参数','[1 18]'}, ...
    {'当前角度','电角速度','鉴相误差','积分状态','速度饱和','机械转速'}, [4 5]);
report = struct('core_subsystems',3,'matlab_functions_in_core',0, ...
    'period','timing_control_sample','parameters_changed',false);
end

function replace(path, build, inputs, outputs, booleans)
ph = get_param(path,'PortHandles'); pos = get_param(path,'Position');
src = zeros(1,numel(ph.Inport)); dst = cell(1,numel(ph.Outport));
for k=1:numel(src)
    ln=get_param(ph.Inport(k),'Line'); src(k)=get_param(ln,'SrcPortHandle'); delete_line(ln);
end
for k=1:numel(dst)
    ln=get_param(ph.Outport(k),'Line'); dst{k}=get_param(ln,'DstPortHandle'); delete_line(ln);
end
parent=get_param(path,'Parent'); delete_block(path);
add_block('built-in/SubSystem',path,'Position',pos,'TreatAsAtomicUnit','on', ...
    'SystemSampleTime','timing_control_sample','BackgroundColor','white');
ports(path,inputs,outputs,booleans); build(path);
if isequal(build,@emf),scalarOutputs=3:6;elseif isequal(build,@pll),scalarOutputs=1:6;else,scalarOutputs=[];end
for k=scalarOutputs
    target=[path '/' outputs{k}];op=get_param(target,'PortHandles');ln=get_param(op.Inport,'Line');
    previous=get_param(ln,'SrcPortHandle');delete_line(ln);name=['标量_' outputs{k}];
    block(path,name,'simulink/Math Operations/Reshape',[2350 50+80*k 2440 80+80*k],'OutputDimensionality','1-D array');
    np=get_param([path '/' name],'PortHandles');add_line(path,previous,np.Inport,'autorouting','on');
    w(path,[name '/1'],[outputs{k} '/1']);
end
ph=get_param(path,'PortHandles');
for k=1:numel(src),add_line(parent,src(k),ph.Inport(k),'autorouting','on');end
for k=1:numel(dst)
    for target=dst{k}(:)',add_line(parent,ph.Outport(k),target,'autorouting','on');end
end
end

function smo(p)
% Prediction and implicit correction are separate from the sample-state muxes.
parameters(p,'观测参数',18,[4 5 6 7 8],{'a','b','g','K','边界层'});
delay(p,'上拍电流',[70 580 155 615],'[0;0]');
delay(p,'上拍注入',[70 655 155 690],'[0;0]');
sub(p,'电流预测',[300 70 455 155], ...
    {'上拍电流','[2 1]';'区间电压','[2 1]';'a','1';'b','1'}, {'预测电流'}, @prediction);
sub(p,'隐式边界层',[520 70 690 195], ...
    {'预测电流','[2 1]';'测量电流','[2 1]';'b','1';'g','1';'K','1';'边界层','1'}, {'残差','注入'}, @correction);
sub(p,'样本与复位选择',[755 70 935 270], ...
    {'测量电流','[2 1]';'预测电流','[2 1]';'校正残差','[2 1]';'校正注入','[2 1]'; ...
     '上拍注入','[2 1]';'b','1';'样本有效','1';'复位','1'}, ...
    {'估计电流','电流残差','滑模注入'}, @smo_selection, [7 8]);
feed(p,'上拍电流','电流预测/1'); feed(p,'区间电压','电流预测/2');
feedtag(p,'a','电流预测/3',[200 280 275 305]);feedtag(p,'b','电流预测/4',[200 325 275 350]);
w(p,'电流预测/1','隐式边界层/1');feed(p,'测量电流','隐式边界层/2');
for k=1:4,keys={'b','g','K','边界层'};feedtag(p,keys{k},['隐式边界层/' num2str(k+2)],[390 290+45*k 470 315+45*k]);end
feed(p,'测量电流','样本与复位选择/1');w(p,'电流预测/1','样本与复位选择/2');
w(p,'隐式边界层/1','样本与复位选择/3');w(p,'隐式边界层/2','样本与复位选择/4');
feed(p,'上拍注入','样本与复位选择/5');feedtag(p,'b','样本与复位选择/6',[650 370 725 395]);
feed(p,'样本有效','样本与复位选择/7');feed(p,'复位','样本与复位选择/8');
for k=1:3,w(p,['样本与复位选择/' num2str(k)],[outname(p,k) '/1']);end
w(p,'样本与复位选择/1','上拍电流/1');w(p,'样本与复位选择/3','上拍注入/1');
note(p,'i− = a i[k−1] + b v[k−1,k]；先校正本拍，再保存下一拍状态。',[300 520]);
end

function prediction(p)
node(p,'电流项','Product',1,0,{'上拍电流/1','a/1'});
node(p,'电压项','Product',1,2,{'区间电压/1','b/1'});
node(p,'预测求和','Sum',2,1,{'电流项/1','电压项/1'},'Inputs','++');
w(p,'预测求和/1','预测电流/1');
end

function correction(p)
node(p,'预测偏差','Sum',1,0,{'预测电流/1','测量电流/1'},'Inputs','+-');
node(p,'bK','Product',1,2,{'b/1','K/1'});
node(p,'分段阈值','Sum',2,2,{'边界层/1','bK/1'},'Inputs','++');
node(p,'偏差绝对值','Abs',2,0,{'预测偏差/1'});
node(p,'边界层内','Relational Operator',3,0,{'偏差绝对值/1','分段阈值/1'},'Operator','<=');
node(p,'bg','Product',1,4,{'b/1','g/1'});constant(p,'一','1',1,5);
node(p,'隐式分母','Sum',2,4,{'一/1','bg/1'},'Inputs','++');
node(p,'线性残差','Divide',3,3,{'预测偏差/1','隐式分母/1'});
node(p,'偏差符号','Sign',2,6,{'预测偏差/1'});
node(p,'饱和压降','Product',3,6,{'bK/1','偏差符号/1'});
node(p,'外侧残差','Sum',4,6,{'预测偏差/1','饱和压降/1'},'Inputs','+-');
choose(p,'分段残差',4,2,'线性残差/1','边界层内/1','外侧残差/1');
node(p,'归一化残差','Divide',5,2,{'分段残差/1','边界层/1'});
node(p,'边界层饱和','Saturation',6,2,{'归一化残差/1'},'UpperLimit','1','LowerLimit','-1');
node(p,'滑模电压','Product',7,2,{'K/1','边界层饱和/1'});
w(p,'分段残差/1','残差/1');w(p,'滑模电压/1','注入/1');
note(p,'向量按 α、β 两轴逐元素计算；分段条件与原隐式公式一致。',[260 710]);
end

function smo_selection(p)
node(p,'有效电流','Sum',1,0,{'测量电流/1','校正残差/1'},'Inputs','++');
node(p,'历史注入作用','Product',1,3,{'b/1','上拍注入/1'});
node(p,'无效样本预测','Sum',2,3,{'预测电流/1','历史注入作用/1'},'Inputs','+-');
choose(p,'电流选择',3,0,'有效电流/1','样本有效/1','无效样本预测/1');
constant(p,'零矢量','[0;0]',2,5);
choose(p,'残差选择',3,2,'校正残差/1','样本有效/1','零矢量/1');
choose(p,'注入选择',3,4,'校正注入/1','样本有效/1','上拍注入/1');
choose(p,'电流复位',4,0,'零矢量/1','复位/1','电流选择/1');
choose(p,'残差复位',4,2,'零矢量/1','复位/1','残差选择/1');
choose(p,'注入复位',4,4,'零矢量/1','复位/1','注入选择/1');
w(p,'电流复位/1','估计电流/1');w(p,'残差复位/1','电流残差/1');w(p,'注入复位/1','滑模注入/1');
end

function pll(p)
parameters(p,'观测参数',18,[3 11 12 13 14 16],{'Ts','Kp','Ki','速度限值','极对数','低幅阈值'});
delay(p,'上拍角度',[70 620 155 655],'0');delay(p,'上拍积分',[70 685 155 720],'0');
delay(p,'上拍速度',[70 750 155 785],'0');
sub(p,'归一化鉴相',[300 70 475 220], ...
    {'正交矢量','[2 1]';'角度','1';'幅值','1';'方向','1';'样本有效','1';'观测启用','1';'低幅阈值','1'}, ...
    {'误差','允许更新'}, @phase_detector,5);
sub(p,'条件积分与限速',[545 70 740 230], ...
    {'误差','1';'上拍积分','1';'上拍速度','1';'允许更新','1';'复位','1';'Ts','1';'Kp','1';'Ki','1';'速度限值','1'}, ...
    {'电角速度','积分状态','速度饱和'}, @pll_regulator,[4 5]);
sub(p,'角度更新与输出',[810 70 1005 220], ...
    {'上拍角度','1';'电角速度','1';'鉴相误差','1';'复位','1';'Ts','1';'极对数','1'}, ...
    {'当前角度','下拍角度','鉴相误差','机械转速'}, @angle_step,4);
feed(p,'正交矢量','归一化鉴相/1');feed(p,'上拍角度','归一化鉴相/2');
feed(p,'反电势幅值','归一化鉴相/3');feed(p,'方向','归一化鉴相/4');
feed(p,'样本有效','归一化鉴相/5');feed(p,'观测启用','归一化鉴相/6');
feedtag(p,'低幅阈值','归一化鉴相/7',[200 370 280 395]);
w(p,'归一化鉴相/1','条件积分与限速/1');feed(p,'上拍积分','条件积分与限速/2');
feed(p,'上拍速度','条件积分与限速/3');w(p,'归一化鉴相/2','条件积分与限速/4');feed(p,'复位','条件积分与限速/5');
keys={'Ts','Kp','Ki','速度限值'};for k=1:4,feedtag(p,keys{k},['条件积分与限速/' num2str(k+5)],[400 300+50*k 485 325+50*k]);end
feed(p,'上拍角度','角度更新与输出/1');w(p,'条件积分与限速/1','角度更新与输出/2');
w(p,'归一化鉴相/1','角度更新与输出/3');feed(p,'复位','角度更新与输出/4');
feedtag(p,'Ts','角度更新与输出/5',[720 380 795 405]);feedtag(p,'极对数','角度更新与输出/6',[720 430 795 455]);
w(p,'角度更新与输出/1','当前角度/1');w(p,'角度更新与输出/2','上拍角度/1');
w(p,'条件积分与限速/1','电角速度/1');w(p,'条件积分与限速/1','上拍速度/1');
w(p,'角度更新与输出/3','鉴相误差/1');w(p,'条件积分与限速/2','积分状态/1');
w(p,'条件积分与限速/2','上拍积分/1');w(p,'条件积分与限速/3','速度饱和/1');w(p,'角度更新与输出/4','机械转速/1');
note(p,'输出 θ[k]，保存 θ[k+1]；无许可时保持积分和速度，复位清零。',[300 590]);
end

function phase_detector(p)
sub(p,'矢量归一化',[300 55 460 135],{'矢量','[2 1]'}, {'x','y','非零'},@normalize);
feed(p,'正交矢量','矢量归一化/1');
node(p,'角度余弦','Trigonometric Function',2,2,{'角度/1'},'Operator','cos');
node(p,'角度正弦','Trigonometric Function',2,3,{'角度/1'},'Operator','sin');
node(p,'y乘余弦','Product',3,1,{'矢量归一化/2','角度余弦/1'});
node(p,'x乘正弦','Product',3,3,{'矢量归一化/1','角度正弦/1'});
node(p,'正交鉴相','Sum',4,2,{'y乘余弦/1','x乘正弦/1'},'Inputs','+-');
constant(p,'零','0',1,6);
node(p,'方向有效','Relational Operator',2,5,{'方向/1','零/1'},'Operator','~=');
node(p,'观测开启','Relational Operator',2,6,{'观测启用/1','零/1'},'Operator','~=');
node(p,'幅值许可','Relational Operator',3,5,{'幅值/1','低幅阈值/1'},'Operator','>=');
node(p,'更新许可','Logical Operator',4,5,{'方向有效/1','观测开启/1','幅值许可/1','样本有效/1','矢量归一化/3'},'Operator','AND','Inputs','5');
choose(p,'有效误差',5,2,'正交鉴相/1','更新许可/1','零/1');
w(p,'有效误差/1','误差/1');w(p,'更新许可/1','允许更新/1');
end

function normalize(p)
block(p,'分量','simulink/Signal Routing/Demux',[225 65 230 175],'Outputs','2');w(p,'矢量/1','分量/1');
sub(p,'矢量模长',[310 240 455 320],{'x','1';'y','1'}, {'模长'}, @hypot_blocks);
w(p,'分量/1','矢量模长/1');w(p,'分量/2','矢量模长/2');
constant(p,'零','0',1,5);constant(p,'一','1',2,5);
node(p,'非零幅值','Relational Operator',3,3,{'矢量模长/1','零/1'},'Operator','>');
choose(p,'归一化分母',4,3,'矢量模长/1','非零幅值/1','一/1');
node(p,'归一化x','Divide',5,0,{'分量/1','归一化分母/1'});
node(p,'归一化y','Divide',5,2,{'分量/2','归一化分母/1'});
w(p,'归一化x/1','x/1');w(p,'归一化y/1','y/1');w(p,'非零幅值/1','非零/1');
end

function pll_regulator(p)
node(p,'积分系数','Product',1,0,{'Ki/1','Ts/1'});
node(p,'积分增量','Product',2,0,{'积分系数/1','误差/1'});
node(p,'试算积分','Sum',3,0,{'上拍积分/1','积分增量/1'},'Inputs','++');
node(p,'比例项','Product',2,2,{'Kp/1','误差/1'});
node(p,'试算速度','Sum',4,1,{'比例项/1','试算积分/1'},'Inputs','++');
node(p,'试算绝对值','Abs',4,3,{'试算速度/1'});
node(p,'未超限','Relational Operator',5,3,{'试算绝对值/1','速度限值/1'},'Operator','<=');
node(p,'实际积分变化','Sum',4,5,{'试算积分/1','上拍积分/1'},'Inputs','+-');
node(p,'饱和方向','Product',5,5,{'试算速度/1','实际积分变化/1'});constant(p,'零','0',4,7);
node(p,'退出饱和','Relational Operator',6,5,{'饱和方向/1','零/1'},'Operator','<=');
node(p,'积分许可','Logical Operator',6,3,{'未超限/1','退出饱和/1'},'Operator','OR','Inputs','2');
choose(p,'条件积分',7,1,'试算积分/1','积分许可/1','上拍积分/1');
choose(p,'运行积分',8,1,'条件积分/1','允许更新/1','上拍积分/1');
node(p,'校正速度','Sum',9,1,{'比例项/1','运行积分/1'},'Inputs','++');
choose(p,'速度保持',10,1,'校正速度/1','允许更新/1','上拍速度/1');
node(p,'负速度限值','Gain',9,4,{'速度限值/1'},'Gain','-1');
node(p,'上限钳位','MinMax',11,1,{'速度限值/1','速度保持/1'},'Function','min','Inputs','2');
node(p,'双向限速','MinMax',12,1,{'负速度限值/1','上限钳位/1'},'Function','max','Inputs','2');
node(p,'速度绝对值','Abs',11,4,{'速度保持/1'});
node(p,'限速标志','Relational Operator',12,4,{'速度绝对值/1','速度限值/1'},'Operator','>');
constant(p,'假','false',11,6);
choose(p,'速度复位',13,0,'零/1','复位/1','双向限速/1');
choose(p,'积分复位',13,2,'零/1','复位/1','运行积分/1');
choose(p,'标志复位',13,4,'假/1','复位/1','限速标志/1');
w(p,'速度复位/1','电角速度/1');w(p,'积分复位/1','积分状态/1');w(p,'标志复位/1','速度饱和/1');
end

function angle_step(p)
constant(p,'零','0',1,5);constant(p,'整周','2*pi',3,4);constant(p,'每分秒数','60',2,6);
node(p,'角度增量','Product',1,0,{'Ts/1','电角速度/1'});
node(p,'下拍未环绕角度','Sum',2,0,{'上拍角度/1','角度增量/1'},'Inputs','++');
node(p,'角度环绕','Math Function',3,0,{'下拍未环绕角度/1','整周/1'},'Operator','mod');
choose(p,'当前角复位',4,0,'零/1','复位/1','上拍角度/1');
choose(p,'下拍角复位',4,2,'零/1','复位/1','角度环绕/1');
choose(p,'误差复位',4,4,'零/1','复位/1','鉴相误差/1');
node(p,'机械角速度','Divide',1,3,{'电角速度/1','极对数/1'});
node(p,'每分钟弧度','Product',2,3,{'机械角速度/1','每分秒数/1'});
node(p,'转速换算','Divide',3,3,{'每分钟弧度/1','整周/1'});
w(p,'当前角复位/1','当前角度/1');w(p,'下拍角复位/1','下拍角度/1');
w(p,'误差复位/1','鉴相误差/1');w(p,'转速换算/1','机械转速/1');
end

function emf(p)
parameters(p,'观测参数',18,[1 2 3 4 9 10 13],{'R','L','Ts','a','观测极点','滤波极点','速度限值'});
parameters(p,'前端参数',35,[2 20 23 24],{'前端周期','前端速度限值','模拟带宽','数字带宽'});
delay(p,'上拍反电势',[70 760 155 795],'[0;0]');
sub(p,'反电势低通',[280 65 440 175], ...
    {'上拍反电势','[2 1]';'滑模注入','[2 1]';'滤波极点','1';'样本有效','1';'复位','1'}, {'反电势'}, @emf_filter,[4 5]);
sub(p,'离散链路相位',[510 65 685 255], ...
    {'上拍速度','1';'复位','1';'速度限值','1';'Ts','1';'a','1';'观测极点','1';'滤波极点','1';'R','1';'L','1'}, {'相位','复位速度'}, @chain_phase,2);
sub(p,'前端滤波相位',[510 325 685 465], ...
    {'上拍速度','1';'前端速度限值','1';'前端周期','1';'模拟带宽','1';'数字带宽','1'}, {'相位'}, @front_phase);
sub(p,'正交矢量与补偿',[760 65 945 205], ...
    {'反电势','[2 1]';'方向','1';'链路相位','1';'前端相位','1'}, {'校正矢量','原始角度','幅值'}, @emf_vector);
feed(p,'上拍反电势','反电势低通/1');feed(p,'滑模注入','反电势低通/2');
feedtag(p,'滤波极点','反电势低通/3',[180 260 260 285]);feed(p,'样本有效','反电势低通/4');feed(p,'复位','反电势低通/5');
w(p,'反电势低通/1','上拍反电势/1');w(p,'反电势低通/1','反电势/1');
feed(p,'上拍速度','离散链路相位/1');feed(p,'复位','离散链路相位/2');
keys={'速度限值','Ts','a','观测极点','滤波极点','R','L'};
for k=1:numel(keys),feedtag(p,keys{k},['离散链路相位/' num2str(k+2)],[310 340+48*k 405 365+48*k]);end
w(p,'离散链路相位/2','前端滤波相位/1');
keys={'前端速度限值','前端周期','模拟带宽','数字带宽'};
for k=1:4,feedtag(p,keys{k},['前端滤波相位/' num2str(k+1)],[530 530+48*k 630 555+48*k]);end
w(p,'反电势低通/1','正交矢量与补偿/1');feed(p,'方向','正交矢量与补偿/2');
w(p,'离散链路相位/1','正交矢量与补偿/3');w(p,'前端滤波相位/1','正交矢量与补偿/4');
w(p,'正交矢量与补偿/1','校正矢量/1');w(p,'正交矢量与补偿/2','原始角度/1');
w(p,'离散链路相位/1','链路相位/1');w(p,'正交矢量与补偿/3','反电势幅值/1');w(p,'前端滤波相位/1','前端相位/1');
end

function emf_filter(p)
constant(p,'一','1',1,4);constant(p,'零矢量','[0;0]',3,5);
node(p,'历史权重','Product',1,0,{'滤波极点/1','上拍反电势/1'});
node(p,'新样本系数','Sum',2,3,{'一/1','滤波极点/1'},'Inputs','+-');
node(p,'样本权重','Product',2,1,{'新样本系数/1','滑模注入/1'});
node(p,'滤波递推','Sum',3,0,{'历史权重/1','样本权重/1'},'Inputs','++');
choose(p,'有效采样更新',4,0,'滤波递推/1','样本有效/1','上拍反电势/1');
choose(p,'滤波复位',5,0,'零矢量/1','复位/1','有效采样更新/1');w(p,'滤波复位/1','反电势/1');
end

function chain_phase(p)
constant(p,'零','0',1,6);constant(p,'一','1',2,6);
choose(p,'复位速度选择',1,0,'零/1','复位/1','上拍速度/1');
clamp(p,'速度钳位','复位速度选择/1','速度限值/1',2,0);
node(p,'每拍电角度','Product',3,0,{'速度钳位/1','Ts/1'});
node(p,'正弦','Trigonometric Function',4,0,{'每拍电角度/1'},'Operator','sin');
node(p,'余弦','Trigonometric Function',4,2,{'每拍电角度/1'},'Operator','cos');
sub(p,'观测器极点相位',[950 80 1115 160],{'正弦','1';'余弦','1';'极点','1'}, {'相位'}, @pole_phase);
sub(p,'提取低通相位',[950 270 1115 350],{'正弦','1';'余弦','1';'极点','1'}, {'相位'}, @pole_phase);
w(p,'正弦/1','观测器极点相位/1');w(p,'余弦/1','观测器极点相位/2');feed(p,'观测极点','观测器极点相位/3');
w(p,'正弦/1','提取低通相位/1');w(p,'余弦/1','提取低通相位/2');feed(p,'滤波极点','提取低通相位/3');
node(p,'观测延迟相位','Sum',7,0,{'每拍电角度/1','观测器极点相位/1'},'Inputs','++');
node(p,'提取总相位','Sum',8,0,{'观测延迟相位/1','提取低通相位/1'},'Inputs','++');
node(p,'区间实部','Sum',5,5,{'余弦/1','a/1'},'Inputs','+-');
node(p,'区间旋转相位','Trigonometric Function',6,5,{'正弦/1','区间实部/1'},'Operator','atan2');
node(p,'电气衰减率','Divide',5,7,{'R/1','L/1'});
node(p,'RL相位','Trigonometric Function',6,7,{'速度钳位/1','电气衰减率/1'},'Operator','atan2');
node(p,'消除区间相位','Sum',9,0,{'提取总相位/1','区间旋转相位/1'},'Inputs','+-');
node(p,'完整链路相位','Sum',10,0,{'消除区间相位/1','RL相位/1'},'Inputs','++');
w(p,'完整链路相位/1','相位/1');w(p,'复位速度选择/1','复位速度/1');
end

function pole_phase(p)
constant(p,'一','1',1,4);
node(p,'极点正弦','Product',1,0,{'极点/1','正弦/1'});
node(p,'极点余弦','Product',1,2,{'极点/1','余弦/1'});
node(p,'实部','Sum',2,2,{'一/1','极点余弦/1'},'Inputs','+-');
node(p,'极点相位','Trigonometric Function',3,0,{'极点正弦/1','实部/1'},'Operator','atan2');w(p,'极点相位/1','相位/1');
end

function front_phase(p)
constant(p,'整周','2*pi',1,6);constant(p,'负整周','-2*pi',1,7);
clamp(p,'速度钳位','上拍速度/1','前端速度限值/1',1,0);
node(p,'模拟截止角频率','Product',2,3,{'整周/1','模拟带宽/1'});
node(p,'模拟RC相位','Trigonometric Function',3,0,{'速度钳位/1','模拟截止角频率/1'},'Operator','atan2');
node(p,'数字负角频率','Product',2,6,{'负整周/1','数字带宽/1'});
node(p,'数字衰减指数','Product',3,6,{'数字负角频率/1','前端周期/1'});
node(p,'数字极点','Math Function',4,6,{'数字衰减指数/1'},'Operator','exp');
node(p,'数字每拍角度','Product',2,1,{'速度钳位/1','前端周期/1'});
node(p,'数字正弦','Trigonometric Function',3,2,{'数字每拍角度/1'},'Operator','sin');
node(p,'数字余弦','Trigonometric Function',3,4,{'数字每拍角度/1'},'Operator','cos');
sub(p,'数字IIR相位',[1030 220 1190 300],{'正弦','1';'余弦','1';'极点','1'}, {'相位'}, @pole_phase);
w(p,'数字正弦/1','数字IIR相位/1');w(p,'数字余弦/1','数字IIR相位/2');w(p,'数字极点/1','数字IIR相位/3');
node(p,'前端总相位','Sum',7,0,{'模拟RC相位/1','数字IIR相位/1'},'Inputs','++');w(p,'前端总相位/1','相位/1');
end

function emf_vector(p)
block(p,'反电势分量','simulink/Signal Routing/Demux',[205 65 210 155],'Outputs','2');w(p,'反电势/1','反电势分量/1');
node(p,'负α反电势','Gain',1,2,{'反电势分量/1'},'Gain','-1');
node(p,'原始x','Product',2,0,{'方向/1','反电势分量/2'});
node(p,'原始y','Product',2,2,{'方向/1','负α反电势/1'});
sub(p,'链路旋转',[650 65 810 165],{'x','1';'y','1';'相位','1'}, {'x','y'}, @rotate);
sub(p,'前端旋转',[905 65 1065 165],{'x','1';'y','1';'相位','1'}, {'x','y'}, @rotate);
w(p,'原始x/1','链路旋转/1');w(p,'原始y/1','链路旋转/2');feed(p,'链路相位','链路旋转/3');
w(p,'链路旋转/1','前端旋转/1');w(p,'链路旋转/2','前端旋转/2');feed(p,'前端相位','前端旋转/3');
block(p,'矢量合并','simulink/Signal Routing/Mux',[1130 80 1135 170],'Inputs','2');
w(p,'前端旋转/1','矢量合并/1');w(p,'前端旋转/2','矢量合并/2');
node(p,'列向量','Reshape',7,0,{'矢量合并/1'},'OutputDimensionality','Column vector (2-D)');w(p,'列向量/1','校正矢量/1');
node(p,'原始辐角','Trigonometric Function',3,4,{'原始y/1','原始x/1'},'Operator','atan2');constant(p,'整周','2*pi',3,6);
node(p,'辐角环绕','Math Function',4,4,{'原始辐角/1','整周/1'},'Operator','mod');w(p,'辐角环绕/1','原始角度/1');
sub(p,'反电势模长',[650 620 810 700],{'x','1';'y','1'}, {'模长'}, @hypot_blocks);
w(p,'反电势分量/1','反电势模长/1');w(p,'反电势分量/2','反电势模长/2');w(p,'反电势模长/1','幅值/1');
end

function rotate(p)
node(p,'余弦','Trigonometric Function',1,0,{'相位/1'},'Operator','cos');
node(p,'正弦','Trigonometric Function',1,3,{'相位/1'},'Operator','sin');
node(p,'x余弦','Product',2,0,{'余弦/1','x/1'});
node(p,'y正弦','Product',2,2,{'正弦/1','y/1'});
node(p,'x正弦','Product',2,4,{'正弦/1','x/1'});
node(p,'y余弦','Product',2,6,{'余弦/1','y/1'});
node(p,'旋转x','Sum',3,1,{'x余弦/1','y正弦/1'},'Inputs','+-');
node(p,'旋转y','Sum',3,5,{'x正弦/1','y余弦/1'},'Inputs','++');
w(p,'旋转x/1','x/1');w(p,'旋转y/1','y/1');
end

function hypot_blocks(p)
% Scaled norm keeps the original hypot behavior near zero and at large values.
node(p,'x绝对值','Abs',1,0,{'x/1'});node(p,'y绝对值','Abs',1,2,{'y/1'});
node(p,'尺度','MinMax',2,0,{'x绝对值/1','y绝对值/1'},'Function','max','Inputs','2');
constant(p,'零','0',1,5);constant(p,'一','1',2,5);
node(p,'非零','Relational Operator',3,3,{'尺度/1','零/1'},'Operator','>');
choose(p,'除法尺度',4,3,'尺度/1','非零/1','一/1');
node(p,'缩放x','Divide',5,0,{'x/1','除法尺度/1'});node(p,'缩放y','Divide',5,2,{'y/1','除法尺度/1'});
node(p,'x平方','Product',6,0,{'缩放x/1','缩放x/1'});node(p,'y平方','Product',6,2,{'缩放y/1','缩放y/1'});
node(p,'平方和','Sum',7,1,{'x平方/1','y平方/1'},'Inputs','++');
node(p,'平方根','Sqrt',8,1,{'平方和/1'});node(p,'还原尺度','Product',9,1,{'尺度/1','平方根/1'});
w(p,'还原尺度/1','模长/1');
end

function ports(p,inputs,outputs,booleans)
if nargin<4,booleans=[];end
for k=1:size(inputs,1)
    args={};if ismember(k,booleans),args={'OutDataTypeStr','boolean'};end
    block(p,inputs{k,1},'built-in/Inport',[25 60+75*(k-1) 55 80+75*(k-1)], ...
        'Port',num2str(k),'PortDimensions',inputs{k,2},args{:});
end
for k=1:numel(outputs)
    name=outputs{k};if any(strcmp(inputs(:,1),name)),name=['输出_' name];end
    block(p,name,'built-in/Outport',[2650 60+80*(k-1) 2680 80+80*(k-1)],'Port',num2str(k));
end
end

function sub(p,name,pos,inputs,outputs,build,booleans)
if nargin<8,booleans=[];end
path=[p '/' name];block(p,name,'built-in/SubSystem',pos,'BackgroundColor','white');
ports(path,inputs,outputs,booleans);build(path);
end

function parameters(p,source,width,indices,names)
name=[source '展开'];path=[p '/' name];
row=strcmp(source,'前端参数');block(p,name,'built-in/SubSystem',[80 875+210*row 240 955+210*row],'BackgroundColor','[0.96 0.96 0.96]');
ports(path,{'参数向量',['[1 ' num2str(width) ']']},names);
block(path,'一维参数','simulink/Math Operations/Reshape',[105 45 180 80],'OutputDimensionality','1-D array');
block(path,'参数分解','simulink/Signal Routing/Demux',[230 35 235 45+35*width],'Outputs',num2str(width));
w(path,'参数向量/1','一维参数/1');w(path,'一维参数/1','参数分解/1');
for k=1:width
    j=find(indices==k,1);
    if isempty(j)
        unused=['保留参数' num2str(k)];block(path,unused,'simulink/Sinks/Terminator',[310 32+35*k 330 52+35*k]);
        w(path,['参数分解/' num2str(k)],[unused '/1']);
    else,w(path,['参数分解/' num2str(k)],[names{j} '/1']);end
end
w(p,[source '/1'],[name '/1']);
for k=1:numel(names)
    tag=coefficient_tag(names{k});dest=['参数_' names{k}];
    block(p,dest,'simulink/Signal Routing/Goto',[320+200*mod(k-1,4) 875+210*row+55*floor((k-1)/4) 460+200*mod(k-1,4) 900+210*row+55*floor((k-1)/4)], ...
        'GotoTag',tag,'TagVisibility','local','ShowName','off');
    w(p,[name '/' num2str(k)],[dest '/1']);
end
end

function feedtag(p,tag,dest,pos)
name=['读取_' tag '_' strrep(dest,'/','_')];
block(p,name,'simulink/Signal Routing/From',pos,'GotoTag',coefficient_tag(tag),'ShowName','off');w(p,[name '/1'],dest);
end

function delay(p,name,pos,initial)
block(p,name,'simulink/Discrete/Unit Delay',pos,'SampleTime','timing_control_sample','InitialCondition',initial);
end

function constant(p,name,value,col,row)
block(p,name,'simulink/Sources/Constant',position(col,row),'Value',value,'VectorParams1D','off');
end

function choose(p,name,col,row,yes,condition,no)
node(p,name,'Switch',col,row,{yes,condition,no},'Criteria','u2 ~= 0');
end

function clamp(p,name,input,limit,col,row)
path=[p '/' name];block(p,name,'built-in/SubSystem',position(col,row));
ports(path,{'输入','1';'限值','1'}, {'输出'});
node(path,'负限值','Gain',1,2,{'限值/1'},'Gain','-1');
node(path,'上限','MinMax',1,0,{'限值/1','输入/1'},'Function','min','Inputs','2');
node(path,'下限','MinMax',2,0,{'负限值/1','上限/1'},'Function','max','Inputs','2');w(path,'下限/1','输出/1');
w(p,input,[name '/1']);w(p,limit,[name '/2']);
end

function node(p,name,type,col,row,sources,varargin)
switch type
    case {'Sum','Product','Gain','Abs','Sign','MinMax','Math Function','Trigonometric Function','Reshape','Sqrt'}
        library=['simulink/Math Operations/' type];
    case {'Switch'},library=['simulink/Signal Routing/' type];
    case {'Relational Operator','Logical Operator'},library=['simulink/Logic and Bit Operations/' type];
    case 'Saturation',library='simulink/Discontinuities/Saturation';
    case 'Divide',library='simulink/Math Operations/Divide';
    otherwise,error('sensorless:BasicBlock','Unknown basic block %s',type);
end
block(p,name,library,position(col,row),varargin{:});
for k=1:numel(sources),w(p,sources{k},[name '/' num2str(k)]);end
end

function pos=position(col,row)
pos=[130+175*col 45+90*row 240+175*col 85+90*row];
end

function block(p,name,library,pos,varargin)
add_block(library,[p '/' name],'Position',pos,'FontName','Microsoft YaHei','FontSize','10',varargin{:});
end

function feed(p,source,dest),w(p,[source '/1'],dest);end
function w(p,source,dest)
parts=strsplit(dest,'/');target=[p '/' parts{1}];
if getSimulinkBlockHandle(target)>0 && strcmp(get_param(target,'BlockType'),'Inport')
    dest=['输出_' dest];
end
add_line(p,source,dest,'autorouting','on');
end
function name=outname(p,k)
blocks=find_system(p,'SearchDepth',1,'BlockType','Outport');
for j=1:numel(blocks),if str2double(get_param(blocks{j},'Port'))==k,name=get_param(blocks{j},'Name');return;end,end
error('sensorless:Port','Missing output port');
end
function note(p,text,pos)
a=Simulink.Annotation(p,text);a.Position=pos;a.FontName='Microsoft YaHei';a.FontSize=11;
end

function tag=coefficient_tag(name)
labels={'边界层','boundary_A';'速度限值','omega_limit';'极对数','pole_pairs'; ...
    '低幅阈值','emf_min';'观测极点','observer_pole';'滤波极点','filter_pole'; ...
    '前端周期','frontend_period';'前端速度限值','frontend_omega_limit'; ...
    '模拟带宽','analog_hz';'数字带宽','digital_hz'};
i=find(strcmp(labels(:,1),name),1);if ~isempty(i),name=labels{i,2};end
tag=['coef_' name];
end
