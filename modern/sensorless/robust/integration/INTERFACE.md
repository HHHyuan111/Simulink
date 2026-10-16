# 本地非理想观测适配 R1

本层通过`pmsm_sensorless_v2_model`在内存中适配本地主模型，复用已验证的SMO/PLL数学核心和N2八部分布局。新增“发布许可”模块；内部47个Goto均为`SLessV2_`作用域标签。原模型外部只增加两个测量支路：实际生效CCR阈值、数字低通前的实际ADC电流。原模型算法代码不替换、不保存SLX。

估计端参数来自独立工程配置，原有R/L/SMO/PLL参数沿用有单位的Mask，新增滤波、压降和执行预算以只读Mask显示。35元素配置仅为MATLAB Function固定尺寸接口，字段顺序在`sensorless_v2_config_rt`中集中定义；参数读取和文件I/O位于MATLAB Function实时路径之外，编译初始化只更新数值，不修改Mask。

测量路径：原模型的增益、偏置、噪声、连续模拟RC、顺序ADC、削顶量化、数字IIR实际启用。观测端对滤后电流扣除估计偏置的RC/IIR启动响应，再除以独立标定增益；利用上一有效样本的差分，把ABC分别提前0.3125、1.8125、3.3125μs至JEOS参考。首拍及坏帧后的首个好帧没有差分历史，明确记录；不逆滤波、不回填真值。对齐是有限阶外推，动态和噪声误差留给R2。

电压路径：生效CCR和实际载波产生固件门极命令，经过估计死区，再由电流RL预测值和历史估计反电势判断续流。符号预测按原生62.5ns运行，不将一个50μs旧电流符号保持整周期；在JEOS用校准电流和因果差分的低频超前估计锚定。0.25A符号余量是工程假设，未证明覆盖实板误差。重构电压经过估计模拟RC的原生ZOH递推、RL加权区间积分、数字IIR，与滤后电流匹配。真实RC为连续模型，两者间O(h)误差及4500/5000Hz参数失配须在R2实测精度中体现。

相位：原SMO注入提取滤波、离散观测极点、旋转RL区间补偿保持N1方程。额外前端补偿仅用上一拍估计电角速度，独立计算连续RC和离散数字IIR的相位；不使用真实转速、不拟合真实角度、不重复补偿。电压重构所需历史反电势由已经校正相位的矢量恢复幅值，避免再旋转一次。

零流续流不确定性：对无法唯一确定的极点，以完整可行母线/二极管区间给出条件电压误差包络；包络同样经过非负RC/IIR及RL权重，保留跨区间记忆。它只量化在估计门极与电流模型条件下的续流歧义，不是涵盖死区失配、温漂和电流预测误差的总电压上界。每一拍都记录，不据此删除零交越或改善精度统计。

发布路径：JEOS捕获原始θ/ω及有效性，原生时钟在JEOS+3μs才把已捕获的数据包公开；计算中输入变化不会改写待发布包。原模型CCR延迟为观测3μs+含速度环最坏假设的FOC5μs+明确干扰，2μs只作截止期裕量。MCU执行时间未实测。ADC削顶/窗口/时序失败独立撤销旧包许可；故障恢复锁存必须先见到新包解锁，再见到重新锁定的新包，才允许重新发布控制值。R0原因位继续使用，新增512表示恢复锁存。原有200拍窗口和400拍锁定要求不放宽，故障后最早第599个连续好样本完成时恢复。

|日志|速率/内容|
|---|---|
|obs_sless_v2_input_i / current_ABC|JEOS，滤后校准对齐αβ/ABC，A|
|obs_sless_v2_measurement|JEOS，ABC孔径结束s、ABC年龄s、rail、window_good、timing_good、差分历史、零序A、对齐修正范数A|
|obs_sless_v2_voltage_native|原生，36列定义如下|
|obs_sless_v2_input_v / voltage_uncertainty|JEOS，匹配滤后的RL区间电压V、条件续流歧义包络V|
|obs_sless_v2_phase_correction / front_phase|JEOS，原观测链/新增前端的独立相位rad|
|obs_sless_v2_publication|原生，13列定义如下|
|obs_sless_v2_control_permit / deny_reason|原生，控制许可及可组合原因位|
|其余obs_sless_v2_*|N2相同单位，valid表示观测质量锁定，不等于control_permit|

native列：1时间s，2:3重构αβ电压V，4:5模拟滤后V，6:7瞬时续流包络V，8:13估计AH/AL/BH/BL/CH/CL，14:16预测电流ABC A，17:19历史估计反电势ABC V，20:22歧义ABC，23:25全关ABC，26:28生效阈值s，29载波s，30母线V，31实际CCR序号，32区间边界，33区间就绪，34上区间歧义时长s，35:36模拟滤后包络V。

publication列：1样本序号，2JEOS参考s，3计算完成s，4当前数据年龄s，5采样角rad，6当前预测角rad，7计划PWM角rad，8原始rpm，9许可采样角rad，10许可PWM角rad，11许可rpm，12计划PWM生效s，13本拍新包到达。禁止许可时9:11为0；任何消费方必须连同control_permit使用。此节点仍是旁路，原有带位置反馈FOC没有切换到估计角。

Scope继续使用本地原生观测格式；角速度Scope比较相同JEOS参考的估计/真值，原始内部数值不会冒充延后可用控制输出。真值只能进入“观测”评价区。新增发布和故障诊断为完整原生timeseries；R1审阅图从归档日志生成。

查看入口：独立MATLAB会话中添加`sensorless`、`sensorless/robust`和本目录，执行`open_pmsm_sensorless_v2`；执行`close_pmsm_sensorless_v2`恢复。入口拒绝覆盖已经打开的用户模型。

数学与Simulink语义参考：[MathWorks Discrete Transfer Fcn](https://www.mathworks.com/help/simulink/slref/discretetransferfcn.html)、[SMO输入与内部滤波接口](https://www.mathworks.com/help/mcb/ref/slidingmodeobserver.html)。本层使用本地实现和独立公式验证，并未导入这些示例模型。
