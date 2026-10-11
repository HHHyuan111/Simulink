# PMSM FOC：当前 R2026a 模型

当前入口为 **`PMSM_FOC_R2026a.slx`**，保留原有小模块及九个等宽等高色域，在测量和调制接口增加可选教学环节。原仓库的模型文件保留在 `2_PMSM_FOC_MATLAB/`。

2026-10-11：已完成[速度环单位与采样修复](control/README_速度环第一步.md)，当时保留 164 个顶层块、165 个内部块及现有布局。数学和采样检查通过，动态响应仍需整定。

同日新增[首批教学开关](teaching/README_教学开关第一批.md)：时序、采样和角度三组设置共11个选项。默认全部关闭，PI 增益不变；原有329个块的位置及九个色域保持一致。完整实物时序、死区及功率级非线性尚未实现。

![当前模型](layout/flat_tidy.png)

## 打开与运行

环境：MATLAB R2026a + Simulink，已在 R2026a Update 5 验证。不需要 Simscape Electrical、DSP System Toolbox 或 Motor Control Blockset。

克隆仓库后，在 MATLAB 中进入仓库的 `modern` 文件夹，运行：

```matlab
open_pmsm_model
```

也可直接双击 `PMSM_FOC_R2026a.slx`，点击“运行”。参数已嵌入 Model Workspace，不需要先运行原参数脚本。入口：Model Explorer → PMSM_FOC_R2026a → Model Workspace → MATLAB Code。

默认设置：24 V 母线、3000 rpm 转速给定、20 kHz PWM、50 μs 控制周期、ode4 固定步长 1 μs、仿真 1 s。电机参数为演示值，尚未标定为实际电机。

```matlab
pmsm_result = sim('PMSM_FOC_R2026a');
plot(pmsm_result.log_speed.Time, pmsm_result.log_speed.Data);
xlabel('Time (s)'); ylabel('Speed (rpm)'); grid on;
```

## 当前实现

旧 SPS 电机、逆变桥和坐标变换等已用普通 Simulink 块替代；电机使用连续 dq 方程，逆变器使用六路互补门极驱动的理想开关桥。原控制结构保留；速度 PI 增益已按转矩输出统一，采样周期参数已连接到实际离散块，转矩换算中的电感项已改为 Ld−Lq。电流环、前馈和原 SVPWM 算法继续审查。

画布顺序：

| 位置 | 左 | 中 | 右 |
| --- | --- | --- | --- |
| 第一行 | 速度环 | 电流环 | 坐标变换 |
| 第二行 | SVPWM | 逆变器与 PMSM | 采样反馈 |
| 第三行 | 数据观测 | 调制观测 | 辅助观测 |

模型现有 168 个顶层块、216 个内部块，共384个块。新增三个设置入口及一个小型输出延迟块，原有329个块均保留；九个色域大小仍均为 860 × 580。

双击“时序设置”“采样设置”“角度设置”选择教学因素；入口显示“开 / 关”，有启用项时文字标红。设置在运行前修改。批量对比演示：

```matlab
addpath('teaching')
run_teaching_demo('timing')      % 速度任务分频与整周期输出延迟
run_teaching_demo('noise_filter') % 采样噪声与数字滤波
```

脚本临时选择开关并记录参数，不保存覆盖主模型，也不重新整定 PI。所有演示参数尚未标定为真实板级值。

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

算法基线的五个工况通过脚本中定义的检查。当前教学版本另有上述组件和闭环检查，未解析库链接为0。检查不覆盖全部控制边界，也不代表真实硬件验证。

当前算法基线的默认启动峰值约 3261.63 rpm，超调约 8.72%；负载阶跃后最大速度偏差约 95.07 rpm。这些动态指标尚未按硬件目标验收。按当前安排暂缓整定，先理解实物时序、采样与功率级因素。[非理想因素与教学开关设计](../review/learning/非理想因素与教学开关设计.md)中的首批选项已实现，其余项及必要的算法正确性修复仍需继续开发并独立验证。

在 `modern` 文件夹中重跑：

```matlab
validate_pmsm_r2026a
```

脚本会更新结果 JSON 和波形图，并生成本地 MAT、CSV 数据。布局验证 JSON 是历史比较记录，复现其前后比较需要本地整理前备份。

## 已知问题与下一步

当前可用于读懂控制链和开展仿真开发。算法专项审查发现的问题尚未修改：

1. 改善速度环启动、反转和饱和恢复的动态响应，定义性能验收指标。
2. 修正 d 轴 PI 参数绑定。
3. 核对 dq 解耦前馈，并补充最终电压矢量限幅与抗积分饱和。
4. 修复 SVPWM 过调制的顺序归一化问题，补充边界工况验证。
5. 根据 STM32G474RET6 固件和实际电路接入 PWM 更新、ADC 采样、角度测量、死区与器件非理想因素。

当前理想桥没有死区或器件损耗；已有等效电流域采样误差和角度模型，但没有实际采样电路或有效采样窗口。Chirp 为辅助观测信号，没有接入主控制给定。尚不能作为已完成开发板适配的发布基线。

速度环当前状态见[第一步说明](control/README_速度环第一步.md)。[逐模块解读](../review/learning/PMSM模型逐模块解读.md)与 Word 文档保留修改前学习快照的说明；其余开发安排见[STM32G474 开发计划](../review/learning/STM32G474仿真开发计划.md)。原作者 SheeperXu；迁移和修复基于原仓库模型。

当前模型 SHA-256：`88f7d9b63986307df6dad91373373b8fe2107cfde5414aea55637b9909006611`。
