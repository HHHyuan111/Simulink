# 原生Scope：控制响应

当前教学方向使用原生Scope观察同一时刻的相关信号。自定义矢量动画暂停，不作为当前工作台入口。

## 打开与运行

```matlab
cd('D:/simulink/modern')
open_pmsm_model
addpath('teaching')
open_pmsm_control_scope
```

也可以双击07观测区的“控制响应”。它使用可撤销的“跟踪观测/控制响应”原生Scope，以2×2显示。原来的“跟踪观测/总览”及其接线完整保留。

Scope用于查看当前模型的一次运行。打开后按模型的运行按钮或Ctrl+T；可使用原生缩放、自动缩放、图例和游标测量。四个画面共用同一仿真时间范围，单位分开。

| 位置 | 主题 | 曲线 |
| --- | --- | --- |
| 左上 | 转速，rpm | n_ref给定、n_true真实机械转速 |
| 左下 | d轴电流，A | id_ref给定、id_true真实值、id_fb控制器反馈 |
| 右下 | q轴电流，A | iq_ref给定、iq_true真实值、iq_fb控制器反馈 |
| 右上 | 转矩，N·m | Te电磁转矩、TL负载 |

电流真实值直接取自电机已有状态源，与obs_state来源相同；反馈值来自原坐标变换输出。没有用给定值代替真实值，也没有重新计算一套电机模型。转速图的真实转速目前不包含额外的“实际速度PI输入”曲线；编码器测速及滤波仍在原测速实验中观察。

默认先看全程建立关系，再放大变速、增载或电流变化的局部。原生Scope可在图例中切换曲线可见性；真实值与反馈值重合时，一条曲线会覆盖另一条，属于一致的表现。细小起伏保留原始结果，不进行平滑。

## 模型与固定实验

整理作为可撤销的观测层保存于脚本，打开原模型时自动应用。控制算法、参数、原SLX和reference_v1保持。旧的独立示波器和误差观测保留，主入口先聚焦四个画面。

已有GUI固定实验通过pmsm_presented_call暂时移除新增观测和布局，按旧计算基线运行，结束后恢复显示。已有封存实验继续使用原结果查看入口；本批没有把历史MAT加载到Scope，也没有新增结果回放动画。历史结果的原生对照可后续采用Simulation Data Inspector。

命令行直接操作固定参考或运行严格实验前：

```matlab
pmsm_current_sampling_scope('remove')
pmsm_pwm_scope('remove')
pmsm_electrical_scope('remove')
pmsm_native_scope('remove')
pmsm_presentation('remove')
% 原固定参考、实验或复跑入口
pmsm_presentation('apply')
pmsm_native_scope('install')
pmsm_electrical_scope('install')
pmsm_pwm_scope('install')
```

观测层启用时不直接保存SLX；它的配置已保存于脚本。原生Scope里的临时量程和显示调整用于当前会话，重建观测层会恢复默认布局。

## 本批验证与下一步

验收检查理想角度和角度偏置两种20ms工况：开启观测前后逐条比较原有Time/Data；核对Scope实际缓冲的10条曲线与原日志时间和数值一致；检查2×2画面顺序、完整还原、固定参考恢复和异常退出后的显示恢复。实际结果见native_scope_validation.json。验证范围不包含全工况或实板标定。

2026-10-14本机R2026a Update 5验收通过：104条原始Time/Data逐点一致，8组Scope显示矩阵与原日志数值完全一致；撤销前后悬空连线均为0，原SLX与固定参考保持。另已打开原模型运行200ms原生Scope预览：[截图](native_control_scope.jpg)，来源见native_control_scope_source.json。预览不是额外的全工况验收。

下一步先根据2×2 Scope的体验微调，再用同样原生方式组织“电流与电压”和“PWM与采样”。频域图围绕死区、噪声等具体实验逐项增加，不一次铺开全部页面。

原生功能依据：[MathWorks R2026a Scope配置](https://www.mathworks.com/help/releases/R2026a/simulink/slref/spbscopes.scope.timescopeconfiguration.html)。

## 白底与画面比例

默认绘图区和示波器背景为白色，坐标文字为黑色，通过 pmsm_scope_style 统一应用白底与蓝红曲线样式，使用 MATLAB 随附原生 web Scope 的样式消息。每次从教学入口打开都会重新应用该样式；配色兼容性目前验证于本机 R2026a。窗口采用2×2等大画面，避免四行布局过于细长。原生缩放、图例和数据游标继续使用。

当前实现撤销时只关闭并删除新增观测块，旧 Scope 的配置和接线保持原样。主模型保持打开。


白底版本实际预览：[控制响应](native_control_scope_white.jpg)，来源见 native_control_scope_white_source.json。四个画面逐一启用自动纵轴量程，避免新建画面的默认[-10,10]挡住转速曲线。已在桌面实际打开 Scope 后检查撤销与重建，记录见 native_scope_live_restore.json。这一记录对应旧的复用实现；2026-10-15已改为独立临时观测块，取消对旧 Scope 的改名、改端口和逐画面恢复。




## 蓝红配色与采样密度

三页原生 Scope 使用同一套白底、黑色坐标、蓝红主色。第三条信号使用中性灰色和线型区分；给定/参考采用虚线。三相电流的 A/B/C 相对应蓝/红/灰，在真实电流与测量电流两幅画面中保持一致。样式集中保存在 `pmsm_scope_style.m`，从教学入口打开时重新应用。此适配使用 R2026a 随附原生 web Scope 样式消息；升级 MATLAB 时需重新验收。

曲线密度首先取决于真实观测周期。控制响应及电气页按控制采样周期观察；PWM与采样页使用 `timing_h` 的事件网格，当前真实时序演示为62.5ns。三页的观测日志均关闭抽点，PWM日志最多保留64000点。Scope可能为屏幕像素自动优化绘制，放大时间轴后再判断边沿；不要靠插值或平滑制造新测量点。需要研究电机端开关纹波时，应单独建立高采样率观测页，不把控制反馈曲线当作连续相电流的完整高频记录。

频域页的4倍FFT补零仅细化显示，真实分辨率和统计指标保持原口径。时间域与频域各自保留原始数据。

2026-10-15：控制响应改为独立的临时原生观测块，撤销时直接删除新增块，避免调整旧七输入/八画面Scope触发R2026a缓存错误。原有控制实现及原示波器均保留。

蓝红版本桌面验收见 native_scope_style_validation.json；预览来源见 native_scope_blue_red_previews.json。打开、撤销和异常恢复后用户设置一致；仿真回调重新计算工作区运行变量，已在记录中单独列出。控制、电气截图来自20ms演示，只用于界面验收。PWM截图来自1ms真实时序演示。

新增按需观测：[电流与采样](电流与采样Scope.md)，比较真实电流、零阶保持输出和最终反馈，并同时观察ADC触发及JEOS。
