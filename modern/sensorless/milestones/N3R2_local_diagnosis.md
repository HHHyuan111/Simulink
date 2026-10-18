# R2 本机继续定位与独立模型交接

2026-10-18 下午。用户暂无另一台电脑或另一套 MATLAB，继续在本机定位。原正式矩阵保持 **1/14、失败停止、零重试**，不重新启动旧候选或已失败短检。

当前结论：**R2 未通过，无仿真或矩阵在后台运行。** 本轮已得到同一观测子模型不加载父模型、零仿真仍会原生退出的独立复现；根因尚未确认。最新[独立复查结果](N3R2/child_only_build_20261018/summary.json)及文末说明是本轮停止位置。

本轮按实际进程号及文件时间，整理 34 条既有失败，其中 23 份存在可匹配的崩溃文本。首帧模块分布于数组管理、语言解释器、Simulink 模块、仿真时钟等 9 个库；最新生成短检的私有文本首帧位于 `m_lxe.dll`。正式第二项的 Windows 事件进程号 `0x33bc` 与实际 PID 13244 匹配，模块为安装目录中的 `icuin74.dll`。这些是定位线索；导出符号可能只是最近的公开名称，不能据此认定具体函数或根因。[脱敏堆栈与原始指纹](N3R2/crash_context_20261018/summary.json)。原始崩溃文本可能含会话/许可信息，仅留本机。

针对 11 个相关 DLL 的只读检查显示：本机既有 GUI 观察到的加载路径均在当前 R2026a 安装目录，签名均有效；对应 13 份组件文件清单未发现缺失路径。清单没有预期内容散列，因此这不是完整安装一致性或依赖兼容性证明，未维修/重装 MATLAB，未更新 BIOS 或改系统设置。[安装观察](N3R2/crash_context_20261018/installation_observation.json)、[清单观察](N3R2/crash_context_20261018/manifest_observation.json)。

|独立诊断|预定判据与实际结果|结论边界|
|---|---|---|
|独立 C 整数计算|固定 65536 个 uint32、32 次 LCG；100000 轮 FNV 均正确，最终完整 262144 字节 SHA256 与独立 Python 参考相同|59.844 s 触及次数上限，未满足原定 60 s；原结果保持未通过，未重跑|
|首次 MATLAB 整数计算|前瞻补充允许尚未启动的单独 MATLAB 对照；60.0869 s、427 轮，全量字节每轮均正确，零仿真调用|本次未复现解释器数值/原生错误，不证明硬件健康或根因修复；不把原两阶段计划改判通过|
|停止态生命周期|一个进程预定最多 20 轮/300 s，“加载—参考恢复—图/参数捕获—关闭”，首失败即停|20 轮、50.645 s 全部状态相同，原/副本均未保存，未复现异常；不放行物理验收|
|参数与恢复元数据往返|两个新小模型，各保存/关闭/重开一次；没有加载原主模型或仿真|确认下述交接缺陷，并验证存储适配|

[独立参考、原始阶段状态和来源](N3R2/local_diagnostics_20261018/summary.json)。参考由 Python 任意精度逐次递推产生，并与独立闭式递推验证全部种子；没有在失败后重新生成参考。C 程序的 60 s 判据和上限设置过近，原退出 11 及 `all_passed=false` 均保留；MATLAB 是另行登记的首次执行，未重启 C 进程。

## 确认的模型交接缺陷

已有生成路径通过 `assignin` 将配置写入仍以 `MATLAB Code` 为来源的父模型工作区，然后保存模型。小模型实测：重开时嵌入代码将基值从运行时的 2 还原为代码中的 1，额外运行时配置消失；默认 `UserDataPersistent=off` 的恢复备份也消失。它会影响交付模型的新进程运行/恢复，不是此前加载/初始化原生异常的已证实原因。

独立正对照将已计算的精确值存为 `Model File` 工作区，并持久化拥有的恢复备份。保存/重开后，18 项观测配置、35 项前端配置、类型、行列方向和备份结构均完全相同。相关数据源行为见 [MathWorks 模型工作区说明](https://www.mathworks.com/help/simulink/slref/simulink.modelworkspace.html)和[数据源说明](https://www.mathworks.com/help/simulink/ug/specify-source-for-data-in-model-workspace.html)。

源代码还包含有意设置的 `sensorless:SaveGuard`，阻止保存装入观测层的模型。原保护保持。新独立导出适配仅在确认文件位于本次拥有的 runs 目录后，核对并清除这个已知保存回调；不忽略其他回调或错误，也不保存原 SLX。恢复时仍使用原移除函数还原回调、工作区和图。

新导出适配已按单独登记的[交接标准](../contracts/nonideal_r2_portable_model_design.json)验证实际 R2 模型：构建进程 53296、独立重开进程 19144；父/子各 86 个变量逐值、类型和维度完全一致，模型文件存储，9 输入零反馈输出、持久化原恢复备份均通过，并实际移除后恢复原图/固定参考。该项仅为停止态结构/参数交接，不计作 96 路短检、正式矩阵或原生异常修复。[交接报告与来源](N3R2/portable_execution_20261018/summary.json)。全部 SMO/PLL 方程、工程假设、日志和验收阈值保持。

## 已定位的生成兼容性缺口

随后按[分进程执行设计](../contracts/nonideal_r2_portable_execution_design.json)构建通用工况导出入口。构建进程 58472 通过；首执行入口漏建基线资料子目录，在复制 `baseline/n0_inventory.json` 时退出 1，未加载模型。原失败保持。前瞻登记[加载前资料分发修正](../contracts/nonideal_r2_staged_preload_repair.json)，从构建归档原文件断言推导修正，仅补目录、执行来源绑定和完成标志；没有重建模型或修改物理执行段。

修正后的唯一执行进程 13724 已加载保存模型，父/子各 86 个参数、备份和图检查通过。在首次 Rapid 目标构建时，返回 `Simulink:tools:rapidAccelBuildFailed`：Simulink Coder 不支持为 `Universal Bridge/续流` 指定的连续更新。**这次是明确的兼容性错误，退出 1；物理启动次数 0，严格 96 路短检未通过。** 两次执行入口失败均保留，不再次启动同版执行器。[实际阶段报告](N3R2/portable_execution_20261018/staged/execution_report.json)。

原续流函数是连续状态输入上的无状态代数函数，原求解器是 `ode4`。直接把它改为每 62.5 ns 离散更新会丢掉 RK4 次步上的连续状态计算，不能据此声称等价。独立[组件标准](../contracts/nonideal_r2_freewheel_inheritance_probe.json)检验 `INHERITED` 是否实际保持连续采样、原函数逐值输出及积分一致，并检查生成运行。PID 23216 完成全部预定执行：三种诊断场景、27 种无直通门极组合、每路 21601 拍；连续与继承 Normal、继承 Normal 与 Rapid 的全部 13 路 Time/Data/类型/维度严格相同，两个模式实际编译采样均为 `[0,0]`，积分结果相同。该项未加载主模型，不代表完整电机等价。[组件报告及原始指纹](N3R2/continuous_codegen_20261018/component/report.json)。[官方更新方式说明](https://www.mathworks.com/help/simulink/slref/matlabfunction.html)描述继承方式可继承输入的连续采样；本次实际执行结果仍是采用该适配的必要证据。

随后前瞻登记[主模型连续继承适配](../contracts/nonideal_r2_continuous_codegen_adaptation.json)。构建 PID 37240 已通过保存、实际恢复续流元数据与原图检查；独立执行 PID 65940 重开参数/图/备份均通过。在明确登记的首次 compile/term 速率查询开始时，返回 `Simulink:modelReference:MultiInstanceToWksAndScope`：带 To Workspace/Scope 日志的子模型仍为默认 `Multi`，不允许这种声明，实际只有一个引用实例也会报错。物理启动次数仍为 0，保留失败，不重启该候选。[本次主模型阶段报告](N3R2/continuous_codegen_20261018/main/execution_report.json)。

按[单实例日志组件标准](../contracts/nonideal_r2_single_reference_logging_probe.json)独立验证已通过：父模型和零输出引用子模型的全部三路日志 Normal/Rapid 时间、数据、类型、维度严格一致；原生 320001 拍、JEOS 400 次完整。[组件记录](N3R2/single_instance_codegen_20261018/single_reference_component/report.json)。使用 `ModelReferenceNumInstancesAllowed=Single` 是对子模型实际实例数的显式限制，不关闭日志或降级报错。[官方实例声明规则](https://www.mathworks.com/help/simulink/gui/totalnumberofinstancesallowedpertopmodel.html)与[多实例限制](https://www.mathworks.com/help/rtw/ug/configure-multiinstance-code-generation.html)。

接着前瞻登记[单实例主模型适配](../contracts/nonideal_r2_single_instance_codegen_adaptation.json)。构建 PID 33104 保存及实际恢复通过；执行 PID 67176 重开后 86 值/图/备份/桥元数据/单实例声明通过。主模型显式 compile/term 实测续流采样为连续 `[0,0]`；Rapid 目标 DLL 已构建，首次 20 ms 物理运行完整结束，原生计数 320001、96 路原始日志、工作区保持、原图/桥/固定参考恢复及短检事件指标通过。随后原 81 路日志严格比较失败，进程退出 1，整个资格检查保持失败。**物理执行和恢复通过不等于完整资格通过。** 未启动长矩阵。[主模型实际结果](N3R2/single_instance_codegen_20261018/summary.json)，[执行入口与限制](../robust/single_instance_codegen/INTERFACE.md)。

只读归档分析未加载或仿真模型，核对原始/规范化散列后比较全部 96 路：所有 Time、类型、维度完全相同；83 路 Data 完全相同。13 路 Data 差异全部属于原 52 路控制日志，新增 44 路观察日志 Data 全部相同。不同项为 `log_Tcm`、`log_Tcm_requested`、`log_v_alpha`、`log_v_beta`、`obs_aw_d/q`、`obs_mod`、`obs_pi_d/q/speed`、`obs_vd/vq`、`obs_voltage`；最大绝对差为电压日志约 1.38601e-10。即使差值很小，也不改判严格比较，不放宽阈值。完整逐路差异见[归档分析](N3R2/single_instance_codegen_20261018/archive_attribution/report.json)。

另发现未执行到的旧验证器还要求新入口未提供的 `execution.initialized_once` 元数据字段；这是独立的报告适配缺项，不能伪造字段或借它解释掉已发现的 13 路真实 Data 差异。物理源/模型、旧失败以及原始归档全部不修改。

据差异分布推断，整父模型代码生成改变了原控制浮点计算结果；尚未证明具体运算符或编译优化是原因。后续先按[新的独立组件标准](../contracts/nonideal_r2_accelerated_reference_logging_probe.json)，把代码生成仅用于子模型，父模型保持 Normal，对照已归档组件基准完整三路日志。该项不加载主电机模型；通过后仍需另行登记主模型生成边界适配与完整 96 路短检。

## 独立子模型构建也复现原生异常

上述三路 Normal 父模型/Accelerator 子模型组件对照通过后，前瞻登记[实际观测器生成边界](../contracts/nonideal_r2_observer_codegen_boundary.json)。构建 PID 56152 通过；独立执行 PID 5244 加载后，86 值、图、备份核对通过，在首次 `slbuild(child,'ModelReferenceSimTarget')` 中原生 `0xc0000005`。物理启动次数 0，候选失败即停。[阶段结果](N3R2/observer_codegen_20261018/summary.json)。匹配 PID/时间的私有崩溃文本 20116 字节，脱敏首帧位于 `m_lxe.dll`；导出符号只能作线索，不据此确定源码函数。[指纹与白名单帧](N3R2/observer_codegen_20261018/native_crash.json)。

为区分父模型上下文与子模型构建，前瞻登记[独立构建标准](../contracts/nonideal_r2_child_only_build_probe.json)，复制同字节子模型 `sr2_0f5b7518.slx`、176 个绑定运行源码及必要元数据，排除父模型文件、私有日志和原始崩溃文本。在新偏好/生成目录的 PID 28368 中，仅加载该子模型，核对 Model File 86 值、9 个 double 输入、零输出、Single、空回调、无嵌套引用；明确将 CurrentSystem 指向子模型。首次且唯一目标构建仍退出 `0xc0000005`，全程零 sim、未加载父模型。Windows Application Error 的 PID `0x6ed0` 匹配，故障模块为 unknown；没有找到匹配的 MATLAB 崩溃文本。原源码/模型指纹完整。JSON 配置向量的行列比较字段 false 仅因 JSON 解码列向量；模型文件字节相同、值比较 true，未改值或方向。

这把触发范围缩到**独立观测子模型生成构建及本机执行环境**；排除了“必须先运行主电机或加载父模型才会触发”的必要条件，仍不能区分软件缺陷、安装依赖、执行环境或硬件原因。[结果与包指纹](N3R2/child_only_build_20261018/summary.json)。独立复现包位于本地 `runs/N3R2_child_only_build_repro.zip`，183 项、332360 字节，包含精确清单和 build-only 入口，没有对外发送。原复查入口禁止本机重试。

下一节点应基于这个独立包继续缩减实际 11 图观测器的生成依赖/组合触发条件，并保留每项前瞻标准；不能把编译开关或再次启动同一模型当作根因修复。新的严格 96 路资格检查及正式 14 项仍有缺口，不启动长工况/R3，不接管反馈，不作实板/WCET结论。本轮节点是得到独立复现和可审查证据，**不是完成 R2**。

MathWorks 关于某些 Intel 13/14 代桌面处理器的崩溃说明要求同时核对受影响型号及独立机器对照等条件；本机是移动 i9-14900HX，且没有独立主机对照，不符合据此认定该问题的证据条件。没有按桌面处理器文章修改 BIOS、频率或电压。[官方适用条件](https://www.mathworks.com/matlabcentral/answers/2174514-why-does-matlab-sporadically-crash-on-my-13th-or-14th-generation-intel-processor)。
