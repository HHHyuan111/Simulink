# AxDr_L dev 与当前PMSM仿真的对照

读取日期：2026-10-11。固件本地只读克隆：`D:\AxDr_L`；分支`dev`；提交`48d6e86814ac6657b1313b4c92ef24c88f492e07`。以下结论针对这个源码快照，未验证烧录版本。未修改、编译或刷写固件。后续收到用户提供的原理图，图纸核对及板级建模补充见[AxDr原理图与仿真对照](AxDr原理图与仿真对照.md)；图纸不代表实板校准结果。

## 已找到的配置

后续电机迁入进度：按用户“先改电机参数”的要求，已将该快照沉沙200W的标称电参、惯量、额定量、20/10kHz基本任务周期及8A iq指令限幅写入同一个主模型，并保持PI增益不变。下面的表格保留读取固件时第二批观测的迁入范围；当前电机状态以[参数迁入说明](../../modern/hardware/README_沉沙电机参数.md)及其验证记录为准，PDFF、ABZ测速和保护尚未迁入。

| 项目 | 固件快照 | 仿真这轮如何使用 |
| --- | --- | --- |
| FOC/电流执行 | 20kHz | 与仿真50μs一致 |
| 速度执行 | 10kHz，计数分频2 | `firmware_io`临时开启速度分频2；原教学示例分频20仍保留 |
| 位置执行 | 5kHz | 当前仿真没有位置环，暂不迁入 |
| 测速相关配置 | 1kHz宏、ABZ窗口2拍，实时路径每快环喂入位置 | 需要继续追踪估计器实际更新、保持和滤波，不把1kHz宏直接当速度PI频率 |
| PWM | TIM1，中心对齐模式2，PSC=0、ARR=4000 | 时钟配置160MHz，推算20kHz；尚未模拟真实计数/CCR更新事件 |
| 定时器死区 | DTG=80，CKD=1；板级目标0.5μs | 80/160MHz=0.5μs；仅用于周期平均压降，不宣称门极死区已复刻 |
| ADC | 12位、同步PCLK/4、47.5周期采样，ADC1三个注入rank | 暂时对齐12位的折算量程；顺序采样尚未实现 |
| ADC触发 | TIM1_CC4下降沿，CCR4=3900 | 后续时序事件模型的依据；不能直接套用模型t=0采样 |
| 电流rank/相序 | target读取A=JDR3、B=JDR2、C=JDR1 | 顺序实际上为C→B→A，需用原理图核对引脚网络；当前仿真三相同时采样 |
| 快环入口 | ADC1整组JEOS后调用fast_loop_step | 三相采样存在不同采样时刻，控制计算还要等整组转换完成 |
| ADC参考、分流、增益 | 3.3V、1mΩ、20倍 | 推算1LSB=3.3/(4096×0.001×20)=0.040283203125A |
| 电流零偏 | 每相独立校准计数 | 仿真折算量程暂假定零电流=2048码，±82.5A；实板校准码未获取 |
| 母线分压 | 20kΩ/1kΩ | 理想上限69.3V、1LSB约0.016919V；本轮尚未建母线ADC和分压误差 |
| 编码器 | 当前选ABZ，10000计数/机械转，方向−1 | 尚未迁入；当前角度开关以电角为单位，不能直接填10000当电角分辨率 |
| 当前电机选择 | 沉沙200W，5极对，Rs=0.105125Ω，Ld=Lq=103.7615μH，J=32×10⁻⁶kg·m² | 存档，未覆盖原4极对演示电机；需确认实际使用档案和工况 |
| 速度控制 | rad/s误差，PDFF限幅输出iq_ref[A]，给定权重0.5 | 与现仿真rpm误差→转矩PI→iq换算不同，不能只复制增益 |
| 电流控制 | 并行PI；主链直接产出vd/vq，独立诊断解耦选项不代表主链开启前馈 | 需要做相同输入的算法对照；不将现模型前馈当成固件已启用功能 |

依据当前160MHz时钟与ADC同步四分频，推算ADC时钟40MHz；按12位转换12.5周期，一路采样加转换约`(47.5+12.5)/40MHz=1.5μs`，三个rank约4.5μs，尚未计入触发同步和软件耗时。这是源码和器件时序的估算，不是示波器实测。12位转换周期依据[ST STM32G4 ADC培训资料](https://www.st.com/resource/en/product_training/STM32G4-Analog-ADC.pdf)。

## 逐项源码入口

以下链接固定在读取的提交，避免dev分支后续变动影响对照。

- [board_config.h：频率、采样与功率板参数](https://github.com/HHHyuan111/AxDr_L/blob/48d6e86814ac6657b1313b4c92ef24c88f492e07/firmware/AxDr_App/User/config/board_config.h)
- [algorithm_config.h：速度/位置任务与控制选项](https://github.com/HHHyuan111/AxDr_L/blob/48d6e86814ac6657b1313b4c92ef24c88f492e07/firmware/AxDr_App/User/control/algorithm_config.h)
- [tim.c：TIM1初始化](https://github.com/HHHyuan111/AxDr_L/blob/48d6e86814ac6657b1313b4c92ef24c88f492e07/firmware/AxDr_App/Core/Src/tim.c)
- [adc.c：注入组配置](https://github.com/HHHyuan111/AxDr_L/blob/48d6e86814ac6657b1313b4c92ef24c88f492e07/firmware/AxDr_App/Core/Src/adc.c)
- [target_adc.c：触发计数和JDR相序](https://github.com/HHHyuan111/AxDr_L/blob/48d6e86814ac6657b1313b4c92ef24c88f492e07/firmware/AxDr_App/User/bsp/target_adc.c)
- [target_pwm.c：CCR写入](https://github.com/HHHyuan111/AxDr_L/blob/48d6e86814ac6657b1313b4c92ef24c88f492e07/firmware/AxDr_App/User/bsp/target_pwm.c)
- [target_irq.c：整组完成回调](https://github.com/HHHyuan111/AxDr_L/blob/48d6e86814ac6657b1313b4c92ef24c88f492e07/firmware/AxDr_App/User/bsp/target_irq.c)
- [control_cascade.c：环路分频及PDFF入口](https://github.com/HHHyuan111/AxDr_L/blob/48d6e86814ac6657b1313b4c92ef24c88f492e07/firmware/AxDr_App/User/control/control_cascade.c)
- [foc_control.c：实际控制主链](https://github.com/HHHyuan111/AxDr_L/blob/48d6e86814ac6657b1313b4c92ef24c88f492e07/firmware/AxDr_App/User/control/foc_control.c)
- [motor_config.h：当前电机档案和单位](https://github.com/HHHyuan111/AxDr_L/blob/48d6e86814ac6657b1313b4c92ef24c88f492e07/firmware/AxDr_App/User/config/motor_config.h)
- [encoder_config.h：ABZ配置](https://github.com/HHHyuan111/AxDr_L/blob/48d6e86814ac6657b1313b4c92ef24c88f492e07/firmware/AxDr_App/User/config/encoder_config.h)
- [mc_deadtime_comp.c：独立诊断压降工具](https://github.com/HHHyuan111/AxDr_L/blob/48d6e86814ac6657b1313b4c92ef24c88f492e07/firmware/AxDr_App/User/diagnostic/core/mc_deadtime_comp.c)

## 接下来按这个顺序对齐

1. 先修复当前教学模型已知的d轴参数绑定、q轴前馈、最终电压限幅/抗饱和和SVPWM过调制边界，保持每次变更可独立验证。
2. 对照`foc_transform`、`foc_svm`、`control_pid`，建立相同输入下的MATLAB与C核心输出比较。核对电流幅值、速度单位、相序、占空比极性和PI/PDFF差别。
3. 建立PWM计数→CC4触发→C/B/A顺序采样→JEOS→计算→CCR写入→预装载生效的事件链。CCR是否启用预装载、更新在哪个边界生效、计算是否跨过更新点需要沿HAL和实测继续确认；这轮没有假定整周期延迟就等于真实固件。
4. 已从原理图确认低侧分流位置、放大电阻比例、偏置路径、RC与主电容组。放大器/驱动/MOSFET具体料号未标，继续核对BOM/实装；按原理图对照中的A-D批次迁入，不将演示参数默认为实板值。沿HAL已确认CCR预装载由PWM配置函数启用，实际触发相位、更新事件与计算跨边界情况还需核对和实测。
5. 再建立具有足够时间分辨率的门极死区与二极管续流，替换平均等效项；最后迁入实际电机/ABZ测速与板级实测数据进行校准。PI整定继续后置。
