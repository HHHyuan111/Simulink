# PMSM FOC：当前 R2026a 模型

当前入口为 **`PMSM_FOC_R2026a.slx`**，保留原有小模块及九个等宽等高色域，在测量和调制接口增加可选教学环节。原仓库的模型文件保留在 `2_PMSM_FOC_MATLAB/`。

2026-10-11：已完成[速度环单位与采样修复](control/README_速度环第一步.md)，当时保留 164 个顶层块、165 个内部块及现有布局。数学和采样检查通过，动态响应仍需整定。

同日新增[首批教学开关](teaching/README_教学开关第一批.md)：时序、采样和角度三组设置共11个选项。默认全部关闭，PI 增益不变；原有329个块的位置及九个色域保持一致。完整实物时序、死区及功率级非线性尚未实现。

第二批完成[成体系的观测与实物因素](teaching/README_观测与实物第二批.md)：五个分轴观测入口、采样前模拟一阶低通、死区周期平均压降和导通压降，新增三项开关，仍全部默认关闭。读取了AxDr_L的dev固件配置，新增频率和ADC量程的临时对照实验；没有直接复制固件PI或覆盖演示电机参数。原有384个块的位置和算法保留。

2026-10-12：[电流环与调制基础修复](control/README_算法基础第二步.md)完成d轴参数绑定、完整dq前馈、最终0.96母线裕量圆限幅及合并回算、SVPWM过调制归一化，并明确母线按电流任务采样。电流环区新增“解耦”（默认开）和“限压”，原532个块的位置及九宫格保留，PI数值没有整定。

![当前模型](layout/flat_tidy.png)

## 打开与运行

环境：MATLAB R2026a + Simulink，已在 R2026a Update 5 验证。不需要 Simscape Electrical、DSP System Toolbox 或 Motor Control Blockset。

克隆仓库后，在 MATLAB 中进入仓库的 `modern` 文件夹，运行：

```matlab
open_pmsm_model
```

也可直接双击 `PMSM_FOC_R2026a.slx`，点击“运行”。参数已嵌入 Model Workspace，不需要先运行原参数脚本。入口：Model Explorer → PMSM_FOC_R2026a → Model Workspace → MATLAB Code。

默认设置：24 V 母线、3000 rpm 转速给定、20 kHz PWM/电流任务、10 kHz速度任务、ode4 固定步长 1 μs、仿真 1 s。电机已对齐固件当前沉沙200W标称档案：5极对、Rs=0.105125Ω、Ld=Lq=103.7615μH、J=32×10⁻⁶kg·m²；尚未经过实板辨识校准。

[电机参数迁入](hardware/README_沉沙电机参数.md)区分11.5A RMS额定电流、16.2635A幅值与8A台架iq指令上限；默认负载为0.207N·m。原PI的9个增益固定不变，14项非理想因素开关仍默认关闭；算法解耦开关默认开。参数已嵌入SLX，不依赖外部参数函数。8A对应约0.339N·m，不能以这个指令上限要求电机持续输出0.69N·m额定转矩。

```matlab
pmsm_result = sim('PMSM_FOC_R2026a');
plot(pmsm_result.log_speed.Time, pmsm_result.log_speed.Data);
xlabel('Time (s)'); ylabel('Speed (rpm)'); grid on;
```

## 当前实现

旧 SPS 电机、逆变桥和坐标变换等已用普通 Simulink 块替代；电机使用连续 dq 方程，逆变器使用六路互补门极驱动的理想开关桥，后接可旁路的周期平均功率级压降。速度PI输出单位为转矩，转矩换算使用Ld−Lq；电流PI之后接完整dq前馈和方向保持的电压圆限幅，最终残差与原PI轴限幅残差合并回算。SVPWM保持原扇区编码，已修正超调制顺序归一化并新增时间、占空比及边界观测。

画布顺序：

| 位置 | 左 | 中 | 右 |
| --- | --- | --- | --- |
| 第一行 | 速度环 | 电流环 | 坐标变换 |
| 第二行 | SVPWM | 逆变器与 PMSM | 采样反馈 |
| 第三行 | 数据观测 | 调制观测 | 辅助观测 |

模型现有188个顶层块、479个内部块，共667个块。真实时序更新保留上一版622个块的身份与位置，新增部分位于已有设置和观测内部；九个色域大小仍均为860×580。

双击“时序设置”“采样设置”“角度设置”“功率设置”选择教学因素；入口显示“开 / 关”，有启用项时文字标红。设置在运行前修改。第三行底部五个观测入口直接打开分轴总览。批量对比演示：

```matlab
addpath('teaching')
run_teaching_demo('timing')      % 速度任务分频与整周期输出延迟
run_teaching_demo('noise_filter') % 采样噪声与数字滤波
run_observation_demo('overview')  % 跟踪、PI、测量、调制、功率、限压回算六页报告
run_observation_demo('firmware_io') % 固件20/10kHz与ADC折算、平均死区对照
```

脚本临时选择开关并记录参数，不保存覆盖主模型，也不重新整定 PI。电机为固件标称档案，ADC折算已按图纸设置；噪声、运放动态、Ron/Vf等仍为演示值，未完成实板校准。

## 验证记录

- `validation_results.json`：新增教学层前的算法基线记录，含默认运行、零指令、反转、负载突变、求解步长减半共五个工况。
- `validation_waveforms.png`：默认工况和负载突变波形。
- `layout/flat_tidy_verification.json`：修改前学习快照的布局验证；当时布局整理前后 12 路记录逐点相同。当前速度环算法修复会改变波形。
- `control/speed_loop_stage1_results.json`：速度环单位修复、十组 PI 逐拍测试、实际采样周期检查，以及修改前后动态比较。
- `control/speed_loop_stage1_reload_check.json`：关闭后重新加载，嵌入参数、编译周期、块数量及库链接检查通过。
- `teaching/teaching_validation.json`：新增因素关闭时原12路日志逐点比较，14项组件检查、三组短时闭环、编译后速度任务周期与原模块位置检查。
- `teaching/teaching_reload_check.json`：当前教学版本保存后重新加载检查。
- `teaching/teaching_demo_check.json`：四组教学演示及工作区参数恢复检查。
- `teaching/teaching_comparison.png`：时序、测量及角度的教学对比波形。
- `teaching/observation_validation.json`：第二批新增因素关闭时原22路日志逐点相同；模拟低通、模拟/数字级联、ADC折算、四组压降组件及五组120ms闭环检查；实际速度执行周期100μs。
- `teaching/observation_reload_check.json`：第二批保存后重新加载和1s默认工况对照。
- `teaching/report_firmware_io/`：相同PI下的固件I/O参数对照、五页分组波形和参数记录。
- `hardware/chensha_validation.json`：算法第二步之前的电机参数迁入记录，含前后1s运行、PI数值/块与位置不变、10kHz速度任务及保存重载结果一致检查。
- `hardware/report_chensha/`：算法第二步之前的沉沙标称参数五页观测波形。
- `control/algorithm_stage2_results.json`：当前电流环/调制修复的组件、闭环、保存重载、原模块几何、编译周期与冗余标签清理一致性记录。
- `control/algorithm_stage2_comparison.png`、`control/report_algorithm/`：修复前后启动比较、低压恢复及当前六页分组报告。

算法基线的五个工况通过脚本中定义的检查。当前教学版本另有上述组件和闭环检查，未解析库链接为0。检查不覆盖全部控制边界，也不代表真实硬件验证。

历史演示电机的默认启动峰值约3261.63rpm；迁入沉沙参数后、算法第二步之前约3135.85rpm。当前默认启动峰值3135.03rpm、1s末2999.546rpm、iq反馈峰值8.525A。已重跑负向启动、实际反转、可持续范围内负载阶跃和母线恢复；3678组SVPWM向量及两轴独立PI检查通过，冗余观测标签清理前后45路时间序列逐点相同。动态尚未按实板目标整定；低压压力工况iq峰值27.887A，主动10A保护仍未实现。详见[本轮结果与边界](control/README_算法基础第二步.md)。

在 `modern` 文件夹中重跑：

```matlab
validate_pmsm_r2026a
```

脚本会更新结果 JSON 和波形图，并生成本地 MAT、CSV 数据。布局验证 JSON 是历史比较记录，复现其前后比较需要本地整理前备份。

## 已知问题与下一步

当前可作为算法与教学仿真的开发基线。d轴参数绑定、完整dq前馈、最终限压与合并回算、SVPWM过调制边界已完成本轮修复与专项验证。后续重点：

1. 改善速度环启动、反转和饱和恢复的动态响应，定义性能验收指标。
2. 校准已接入的PWM更新事件、ADC触发及顺序转换参数，核对各任务之间的保持与延迟。
3. 完善低侧有效窗口失效处理，加入ABZ测角测速、上电对齐及主动保护。
4. 完善真实门极死区、二极管续流、器件参数及母线测量链，再按实测校准。
5. 对齐固件PDFF、显式积分器及数值精度；当前Backward Euler隐式PI尚非固件位级实现。

当前桥的门极没有真实死区空白；已增加可选的周期平均死区/导通压降，不能用于逐开关沿续流或器件损耗分析。已有等效电流域测量误差、模拟/数字低通、角度模型，以及可选顺序ADC转换和低侧有效窗口；实际前端电路和事件参数尚待校准。Chirp为辅助观测信号，没有接入主控制给定。尚不能作为已完成开发板适配的发布基线。

固件来源和差异见[AxDr固件对照](../review/learning/AxDr固件对照.md)，图纸核对见[原理图与仿真对照](../review/learning/AxDr原理图与仿真对照.md)。目前已迁入dev快照的沉沙电机标称参数、基本任务频率和台架指令限幅；固件PDFF、测角测速、对齐及保护链仍需单独迁移和验证。

速度环当前状态见[第一步说明](control/README_速度环第一步.md)。[逐模块解读](../review/learning/PMSM模型逐模块解读.md)与 Word 文档保留修改前学习快照的说明；其余开发安排见[STM32G474 开发计划](../review/learning/STM32G474仿真开发计划.md)。原作者 SheeperXu；迁移和修复基于原仓库模型。

当前模型SHA-256：`db31d893ca9f0359e6b36e580056da9b74a46457f127da0c1bcccbab4775edec`。当前版本以`timing/timing_stage3_results.json`为准；算法第二步、电机参数迁入及更早的教学/观测记录均为历史版本记录。

2026-10-12已发布[真实时序与低侧采样窗口版本](timing/README_真实时序与采样窗口.md)：PWM/CCR更新、顺序ADC、控制执行相位、有效窗口和事件观测已加入现有局部模块，PI与原布局保留。桌面模型和工作区已备份，主文件已替换并重新打开；`timing/timing_stage3_results.json`的`publication_status=published`。新增开关默认关闭，触发相位及软件耗时尚待实测。三页报告及验证边界见该说明。
