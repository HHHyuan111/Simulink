function c=pmsm_switch_catalog
% Contracts for implemented switches. This table does not implement algorithms.
c=struct('section',{},'key',{},'name',{},'category',{},'off',{},'on',{},'parameters',{},'requires',{},'conflicts',{},'observe',{},'boundary',{});
add('时序设置','speed_on','速度分频','调度','使用Ts_speed','使用dt乘分频数',{'speed_divider'},{},{},'速度任务周期、速度与电流响应','改变执行周期，不等于自动改变带宽或整定PI。');
add('时序设置','pwm_on','整周期输出延迟','等效时序','旁路新增输出延迟','指令延迟指定个dt',{'pwm_cycles'},{},{'时序设置.real_on'},'请求调制量与实际输出','集中等效延迟；不能与真实事件时序叠加。');
add('时序设置','real_on','真实时序','事件时序','沿用简化任务与载波模式','顺序ADC、JEOS计算、CCR预装载生效',{'trigger_us','sync_us','compute_us','update_mode','grid_divider'},{},{'时序设置.pwm_on','采样设置.delay_on'},'ADC/PWM事件、任务相位','不含完整CPU调度；部分时刻尚未实测。');
add('时序设置','window_on','低侧采样窗口','有效性','不按低侧窗口屏蔽样本','检查采样孔径是否落在有效导通窗口',{'settle_us'},{'时序设置.real_on'},{},'采样有效标志、真值与测量值','无效样本置零仅为教学演示。');
add('时序设置','invalid_hold_on','无效样本保持','处理策略','窗口失效采用原置零演示','保持上次有效样本',{}, {'时序设置.window_on','时序设置.real_on'},{},'有效标志、实际送入控制器的电流','保持不是完整电流重构，也不保证闭环安全。');
add('采样设置','bias_on','电流零偏','测量误差','新增零偏为零','三相分别叠加固定零偏',{'bias_A'},{},{},'三相真值、测量值与误差','电流域等效值，待逐通道标定。');
add('采样设置','gain_on','电流增益误差','测量误差','新增增益为1','三相使用设定增益',{'phase_gain'},{},{},'三相真值、测量值与误差','不表示完整放大器非线性。');
add('采样设置','noise_on','电流噪声','测量误差','新增噪声为零','按dt生成三相随机噪声',{'noise_rms','noise_seed'},{},{},'噪声、测量电流、dq电流','固定种子便于复现；不模拟全部开关尖峰。');
add('采样设置','adc_on','ADC量化与饱和','测量误差','旁路量化和量程限制','使用电流域ADC量化与饱和',{'adc_bits','adc_span'},{},{},'ADC码、量化前后电流','adc_span为全跨度；非正负各一份量程。');
add('采样设置','filter_on','数字低通','处理策略','旁路数字滤波','一阶离散低通',{'filter_hz'},{},{},'滤波前后电流、幅值与滞后','既影响噪声也影响信号；初态保留模型定义。');
add('采样设置','delay_on','整周期采样延迟','等效时序','旁路新增采样延迟','测量结果延迟指定个dt',{'delay_cycles'},{},{'时序设置.real_on'},'原测量值、控制器使用值','与真实时序互斥，防止重复计入延迟。');
add('采样设置','analog_on','模拟低通','前端近似','旁路模拟低通','采样前一阶连续低通',{'analog_hz'},{},{},'模拟滤波前后、ADC后电流','等效带宽，不是完整运放电路模型。');
add('角度设置','bias_on','角度偏置','测量误差','新增偏置为零','叠加电角偏置',{'bias_deg'},{},{},'真角度、测量角度、最短角差','单位为电角度；非机械角度。');
add('角度设置','quant_on','角度量化','测量误差','旁路角度量化','按电角步长量化',{'step_deg'},{},{},'角度误差、dq电流','不含完整ABZ解码与测速。');
add('角度设置','delay_on','角度延迟','等效时序','旁路新增角度延迟','角度延迟指定个dt',{'delay_cycles'},{},{},'角度误差、dq电流','初始输出保留模型定义；不含预测补偿。');
add('功率设置','dead_on','平均死区压降','历史教学近似','不扣除平均死区项','按周期平均公式施加电压误差',{'dead_us','blend_A'},{},{'功率设置.gate_on'},'平均压降、相电压与三相电流','与门极死区互斥；blend_A是旧模型平滑参数。');
add('功率设置','drop_on','器件导通压降','功率近似','不施加新增Ron/Vf压降','按当前桥模式计入导通/续流压降',{'ron','vf'},{},{},'实际相电压、三相电流','详细桥与旧平均模型的压降公式不同；应记录桥模式。');
add('功率设置','gate_on','门极死区','功率非理想','旁路新增门极死区，使用理想桥路径','关断立即、开通延后；两管关断时续流',{'gate_us','zero_A'},{},{'功率设置.dead_on'},'请求/实际门极、相电压、三相电流','当前要求Ld=Lq；zero_A是近零数值带，不是器件实测参数。');
add('功率设置','comp_on','死区补偿','控制算法','补偿电压为零','按测量电流极性与滞环施加基础前馈',{'comp_us','hysteresis_A'},{'功率设置.gate_on'},{},'补偿电压、三相电流、dq与转矩','基础方法保留为对照；效果不保证在所有工况改善。');
    function add(section,key,name,category,off,on,parameters,requires,conflicts,observe,boundary)
        c(end+1)=struct('section',section,'key',key,'name',name,'category',category,'off',off,'on',on, ...
            'parameters',{parameters},'requires',{requires},'conflicts',{conflicts},'observe',observe,'boundary',boundary);
    end
end
