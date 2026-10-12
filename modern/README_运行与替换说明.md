# PMSM FOC 的 R2026a 可运行替换版

> 本文保留首次迁移时的实现说明。当前模型已加入沉沙电机档案、控制修复、教学观测及真实时序选项，运行入口和当前验证状态以[modern/README.md](README.md)为准；不要把下文历史演示参数当成当前参数。

> 2026-10-11 更新：按用户要求撤回层级重构，恢复截图中的平铺模型。当前只调整模块位置、走线和色域，九个色域等宽等高；原 164 个顶层小模块、名称、连接与内部实现保留。当前说明见 `layout/README_平铺整理.md`。`organization/` 是已撤回方案的历史记录，`baseline/` 仅作参考。电机与硬件参数仍待补充，控制算法专项审查尚未完成。

适用环境：MATLAB R2026a、Simulink。本机已安装版本为 R2026a Update 5；不依赖 Simscape、Simscape Electrical、DSP System Toolbox 或 Motor Control Blockset。

本次只恢复 PMSM 模型的运行能力，保留原 FOC、PI 参数、前馈及 SVPWM 算法，原仓库文件不覆盖。

## 直接运行

在 MATLAB 命令窗口输入：

```matlab
open_system('D:\simulink\modern\PMSM_FOC_R2026a.slx');
```

点击绿色“运行”。默认仿真 1 s，速度给定 3000 rpm，直流母线 24 V，PWM 20 kHz，控制周期 50 μs，连续电机方程采用固定步长 ode4、步长 1 μs。

参数已经嵌入模型工作区，直接打开即可运行，不需要先执行原参数脚本，也不依赖当前文件夹中的 PI/SVPWM 背景图片。原模型的 10 s 停止时间缩短到 1 s，便于交互阅读，可自行延长。

如需保留现有 `out` 变量，可以用不同名称接收新仿真结果：

```matlab
pmsm2026a_result = sim('PMSM_FOC_R2026a');
plot(pmsm2026a_result.log_speed.Time, pmsm2026a_result.log_speed.Data);
xlabel('Time (s)'); ylabel('Speed (rpm)'); grid on;
```

参数入口：Model Explorer → `PMSM_FOC_R2026a` → Model Workspace → MATLAB Code。电机参数仍为仓库演示值，尚未替换为实际开发板/电机参数。

## 模块替换表

| 原模块 | 当前替换 | 保留的接口/含义 |
| --- | --- | --- |
| 旧 SPS PMSM | 普通 Simulink Fcn、Mux、连续 Integrator 组成的 dq 电机 | 三相电压、负载转矩输入；相电流、机械速度/角度、转矩、dq 电压输出 |
| Universal Bridge | 六路门极驱动的理想开关逆变桥子系统 | `[AH AL BH BL CH CL]`，由实际 PWM 开关状态生成相电压 |
| DC Voltage Source | Constant `Vdc` | 固定母线电压 |
| Voltage Measurement | Gain 1 | 母线电压反馈 |
| Three-Phase V-I Measurement | 信号测量子系统 | 线电压 `[Vab Vbc Vca]`、相电流、显式 `Currentabc` 标签 |
| abc → αβ0 | 2/3 幅值不变 Clarke 矩阵 | 与相电流峰值口径一致 |
| αβ0 → dq0 | 普通 Fcn 运算 | d 轴对齐 A 相，q 轴为 `-α*sinθ+β*cosθ` |
| dq0 → αβ0 | 普通 Fcn 运算 | 与正 Park 互逆 |
| 电机测量 Bus Selector | 测量向量拆分子系统 | 原六路机械/电流输出及两路电压输出顺序保留 |
| DSP Chirp1/Chirp2 | 周期扫频时间、余弦公式、ZOH | 10 s 内 0→500 Hz / 0→5000 Hz；仅用于原监测支路 |
| powergui | 移除；在模型配置中使用 Simulink 求解器 | 此版本没有 SPS/Simscape 物理网络 |
| 未连接 AC Voltage Source | 移除 | 原模型没有使用它施加纹波 |

原速度环、电流环、转矩到 iq 换算、前馈、SVPWM 函数、载波比较、六路互补门极与主要 Scope 保留。顶层小模块直接展开，保留原有子系统和 Goto/From；波形记录入口为顶层 `Validation logging`，输出同名的 12 路 `log_*` 记录。

另修正了速度误差监测支路的零速除零：归一化分母从 `0.1*n` 改为 `max(abs(0.1*n),1)`（下限 1 rpm）。这只影响监测显示，不进入控制反馈，默认 3000 rpm 时数值不变。

## 电机方程与边界

```text
we = p * wm
Ld * did/dt = vd - Rs*id + we*Lq*iq
Lq * diq/dt = vq - Rs*iq - we*(Ld*id + phis)
Te = 1.5*p*(phis*iq + (Ld-Lq)*id*iq)
J * dwm/dt = Te - Tload - F*wm
dtheta_m/dt = wm
```

三相绕组按浮动星点、正弦磁链处理；相电压由开关桥极点电压去掉共模分量得到。当前 `Ld=Lq`，模型仍保留凸极转矩项。

这是用于恢复 FOC 闭环运行和逐块学习的信号方程模型。逆变桥采用理想互补开关，没有复现原 IGBT 的 1 mΩ 导通电阻、器件损耗、二极管换流、死区、母线电容或模拟采样电路；不能将它的高频细节当作真实板子的预测结果。后续增加死区时，需要同时扩展桥臂续流模型，不能只把门极拉低。

原 SVPWM 过调制顺序归一化问题、速度环单位与采样封装等问题仍记录在《仓库阅读报告》中，本次未修改。正常验证工况中的 PWM 阈值会单独检查范围；这不表示已验证全部过调制工况。

## 验证与复现

- `validation_results.json`：完整默认工况、零指令、反转、负载突变、求解步长减半的数值结果与通过状态。
- `validation_waveforms.png`：默认运行和负载突变波形。
- `validation_results.mat`：默认工况的完整控制周期采样记录。
- `validation_default.csv`：默认工况按 1 ms 导出的主要波形。
- `validate.log`：MATLAB 执行日志。

本机验证结果：

| 工况 | 末 20 ms 平均转速 | 结果 |
| --- | ---: | --- |
| 默认 3000 rpm，完整运行 1 s | 3000.003 rpm | 通过 |
| 零指令、零负载 | 0 rpm | 通过 |
| 反转 -1500 rpm，阻力方向相应反向 | -1500.000 rpm | 通过 |
| 0.08 s 时负载由 `0.3*Tn` 升为 `0.6*Tn` | 2999.996 rpm | 通过 |
| 电气求解步长由 1 μs 减半至 0.5 μs | 3000.000 rpm | 稳态速度比较通过 |

上述工况的关键记录均为有限值，门极互补，PWM 阈值位于 0～25 μs 载波范围内，未解析库链接为 0。默认工况的稳态电磁转矩约 0.12179 N·m，与负载加黏性摩擦所需 0.12084 N·m 相差约 0.00095 N·m（记录在控制采样时刻）。

步长减半后的启动 iq 采样峰值从约 11.53 A 变为约 11.29 A，变化约 2.1%。本次步长检查确认了稳态速度的一致性，不能据此宣称高频纹波或峰值已经完全收敛。

重跑验证：

```matlab
addpath('D:\simulink\modern');
validate_pmsm_r2026a;
```

`build_pmsm_r2026a` 是首次迁移脚本。为保护现有整理与后续修改，主模型文件存在时会拒绝覆盖。当前纯布局脚本为 `layout/tidy_flat_layout.m`，只改变图形属性；布局坐标由 `layout/prepare_flat_tidy.py` 生成。旧排版和层级重构脚本已停用，防止意外覆盖。截图对应的平铺备份保存在 `organization/backups/pre_structure_20261010/`；已撤回的层级版和窗口未保存状态也分别保留了备份。

后续逐块阅读这份模型，再将已确认的实际采样、PWM 更新和固件控制算法接入。当前目标是恢复运行并提供清楚的模块接口，尚未做 PI 调优或开发板参数标定。
