function report = build_native_smo(mdl)
% Replace only the current SMO equations with a flat native-block diagram.
p = [mdl '/无感观测/滑模观测'];
assert(getSimulinkBlockHandle([p '/隐式校正'])>0,'The accepted SMO source is missing.');
Simulink.SubSystem.deleteContents(p);

% All signals are alpha/beta column vectors. Coefficients are still calculated
% by pmsm_sensorless_v2_init from the existing motor and observer settings.
from('区间电压','SLessV2_voltage_sample',[30 120 200 145]);
from('测量电流','SLessV2_current',[30 350 200 375]);
from('样本有效','SLessV2_sample_valid',[30 720 200 745]);
from('复位','SLessV2_reset',[30 800 200 825]);
publish('测量电流/1','SMO_measured',[230 350 380 375]);
publish('样本有效/1','SMO_sample_valid',[230 720 400 745]);
publish('复位/1','SMO_reset',[230 800 400 825]);

from('本拍电流反馈','SLessV2_i_hat',[30 40 200 65]);
delay('电流状态',[240 30 300 75]);wire('本拍电流反馈/1','电流状态/1');
gain('电流递推 a','sless_cfg(4)',[345 30 405 75],'电流状态/1');
gain('电压递推 b','sless_cfg(5)',[345 110 405 155],'区间电压/1');
sumblock('电流预测','++',[465 65 495 95],{'电流递推 a/1','电压递推 b/1'});
publish('电流预测/1','SMO_prediction',[550 65 730 90]);

% Closed-form implicit correction, not an explicit Euler approximation.
read('预测值','SMO_prediction',[30 220 200 245]);
read('校正用电流','SMO_measured',[30 280 200 305]);
sumblock('预测偏差','+-',[255 230 285 260],{'预测值/1','校正用电流/1'});
publish('预测偏差/1','SMO_delta',[330 225 475 250]);
read('线性偏差','SMO_delta',[520 185 670 210]);
constant('隐式分母','1+sless_cfg(5)*sless_cfg(6)',[520 125 690 155]);
operation('线性残差','simulink/Math Operations/Divide',[745 170 835 215], ...
    {'线性偏差/1','隐式分母/1'});
read('判定偏差','SMO_delta',[520 275 670 300]);
operation('偏差绝对值','simulink/Math Operations/Abs',[705 270 755 305],{'判定偏差/1'});
constant('隐式分段阈值','sless_cfg(8)+sless_cfg(5)*sless_cfg(7)',[520 350 755 380]);
operation('处于边界层','simulink/Logic and Bit Operations/Relational Operator', ...
    [805 280 865 320],{'偏差绝对值/1','隐式分段阈值/1'},'Operator','<=');
read('饱和偏差','SMO_delta',[520 440 670 465]);
operation('偏差符号','simulink/Math Operations/Sign',[705 435 755 470],{'饱和偏差/1'});
gain('饱和校正 bK','sless_cfg(5)*sless_cfg(7)',[800 435 890 480],'偏差符号/1');
read('饱和解输入','SMO_delta',[705 515 865 540]);
sumblock('饱和区残差','+-',[935 440 965 470],{'饱和解输入/1','饱和校正 bK/1'});
switchblock('分段残差',[1030 275 1090 335], ...
    '线性残差/1','处于边界层/1','饱和区残差/1');
publish('分段残差/1','SMO_corrected_residual',[1150 280 1375 305]);
constant('边界层电流','sless_cfg(8)',[1150 395 1300 425]);
operation('残差归一化','simulink/Math Operations/Divide',[1415 275 1500 320], ...
    {'分段残差/1','边界层电流/1'});
operation('边界层饱和','simulink/Discontinuities/Saturation',[1550 275 1610 320], ...
    {'残差归一化/1'},'UpperLimit','1','LowerLimit','-1');
gain('滑模增益 K','sless_cfg(7)',[1660 275 1720 320],'边界层饱和/1');
publish('滑模增益 K/1','SMO_corrected_injection',[1770 285 2010 310]);

% Valid samples update the implicit solution; invalid samples only predict.
read('有效校正电流','SMO_measured',[30 580 200 605]);
read('有效校正残差','SMO_corrected_residual',[30 635 255 660]);
sumblock('有效电流估计','++',[305 590 335 620],{'有效校正电流/1','有效校正残差/1'});
from('本拍注入反馈','SLessV2_injection',[480 600 700 625]);
delay('注入状态',[745 590 805 635]);wire('本拍注入反馈/1','注入状态/1');
publish('注入状态/1','SMO_injection_previous',[850 600 1090 625]);
gain('历史注入 b','sless_cfg(5)',[745 680 825 725],'注入状态/1');
read('无效样本预测','SMO_prediction',[480 760 675 785]);
sumblock('纯模型电流估计','+-',[880 700 910 730],{'无效样本预测/1','历史注入 b/1'});
read('电流更新许可','SMO_sample_valid',[1040 660 1250 685]);
switchblock('样本电流选择',[1320 600 1380 660], ...
    '有效电流估计/1','电流更新许可/1','纯模型电流估计/1');
constant('零矢量','[0;0]',[1475 525 1545 555]);
read('电流复位许可','SMO_reset',[1450 660 1625 685]);
switchblock('电流复位',[1680 600 1740 660], ...
    '零矢量/1','电流复位许可/1','样本电流选择/1');
output('电流复位/1','SLessV2_i_hat',[1810 615 2040 640]);

read('残差更新值','SMO_corrected_residual',[1040 805 1265 830]);
read('残差更新许可','SMO_sample_valid',[1040 860 1265 885]);
switchblock('样本残差选择',[1320 800 1380 860], ...
    '残差更新值/1','残差更新许可/1','零矢量/1');
read('残差复位许可','SMO_reset',[1450 860 1625 885]);
switchblock('残差复位',[1680 800 1740 860], ...
    '零矢量/1','残差复位许可/1','样本残差选择/1');
output('残差复位/1','SLessV2_residual',[1810 815 2040 840]);

read('注入更新值','SMO_corrected_injection',[1040 1005 1275 1030]);
read('注入更新许可','SMO_sample_valid',[1040 1060 1275 1085]);
read('历史注入保持','SMO_injection_previous',[1040 1120 1275 1145]);
switchblock('样本注入选择',[1320 1000 1380 1060], ...
    '注入更新值/1','注入更新许可/1','历史注入保持/1');
read('注入复位许可','SMO_reset',[1450 1060 1625 1085]);
switchblock('注入复位',[1680 1000 1740 1060], ...
    '零矢量/1','注入复位许可/1','样本注入选择/1');
output('注入复位/1','SLessV2_injection',[1810 1015 2040 1040]);

annotation('电流预测',[30 5],16);
annotation('隐式滑模校正 · αβ 两轴逐元素计算',[520 70],16);
annotation('有效样本、保持与复位',[1040 560],16);
annotation('参数沿用 sless_cfg；状态周期与采样相位沿用 timing_control_sample。',[30 900],11);
annotation('i⁻ = a î[k−1] + b v[k−1,k]；r = δ/(1+bg) 或 δ−bK·sign(δ)。',[30 945],11);
annotation('z = K·sat(r / 边界层)；无效样本使用 i⁻−b z[k−1]，复位清零。',[30 985],11);
set_param(p,'ZoomFactor','FitSystem','ScreenColor','white');
report=struct('scope','SMO only','native_blocks',true,'new_subsystems',0, ...
    'sample_time','timing_control_sample','coefficient_source','sless_cfg');

    function add(name,library,pos,varargin)
        add_block(library,[p '/' name],'Position',pos,'FontName','Microsoft YaHei', ...
            'FontSize','10',varargin{:});
    end
    function wire(source,target),add_line(p,source,target,'autorouting','on');end
    function from(name,tag,pos)
        add(name,'simulink/Signal Routing/From',pos,'GotoTag',tag,'ShowName','off','IconDisplay','Tag');
    end
    function read(name,tag,pos),from(name,tag,pos);end
    function publish(source,tag,pos)
        name=['发布_' tag];add(name,'simulink/Signal Routing/Goto',pos, ...
            'GotoTag',tag,'TagVisibility','local','ShowName','off','IconDisplay','Tag');wire(source,[name '/1']);
    end
    function output(source,tag,pos)
        name=['输出_' tag];add(name,'simulink/Signal Routing/Goto',pos, ...
            'GotoTag',tag,'TagVisibility','scoped','ShowName','off','IconDisplay','Tag');wire(source,[name '/1']);
    end
    function delay(name,pos)
        add(name,'simulink/Discrete/Unit Delay',pos,'SampleTime','timing_control_sample','InitialCondition','[0;0]');
    end
    function gain(name,value,pos,source)
        add(name,'simulink/Math Operations/Gain',pos,'Gain',value,'Multiplication','Element-wise(K.*u)');
        wire(source,[name '/1']);
    end
    function constant(name,value,pos)
        add(name,'simulink/Sources/Constant',pos,'Value',value,'VectorParams1D','off');
    end
    function sumblock(name,signs,pos,sources)
        operation(name,'simulink/Math Operations/Sum',pos,sources,'Inputs',signs,'IconShape','round');
    end
    function switchblock(name,pos,yes,condition,no)
        operation(name,'simulink/Signal Routing/Switch',pos,{yes,condition,no},'Criteria','u2 ~= 0');
    end
    function operation(name,library,pos,sources,varargin)
        add(name,library,pos,varargin{:});
        for index=1:numel(sources),wire(sources{index},[name '/' num2str(index)]);end
    end
    function annotation(text,pos,size)
        a=Simulink.Annotation(p,text);a.Position=pos;a.FontName='Microsoft YaHei';a.FontSize=size;
    end
end
