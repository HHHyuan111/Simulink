# 原生执行异常的分层隔离

标准先登记在 `contracts/nonideal_r2_core_replay_diagnostic.json`、`nonideal_r2_reduced_graph_diagnostic.json`、`nonideal_r2_native_logger_diagnostic.json` 和 `nonideal_r2_original_only_diagnostic.json`。已完成的记录位于 `milestones/N3R2/isolation_20261017`，原始输入/输出位于本地 `runs`。

`probe_sensorless_r2_core_replay` 只读取归档并推进原纯函数。`probe_sensorless_r2_reduced_graph` 构造五个原 MATLAB Function 包装器及作用域 Goto，按 50 μs 样本序号输入，和纯函数严格比较。原物理参考时间为 `28.875 μs + k×50 μs`，诊断图时间为 `k×50 μs`；没有仿真原生监督器。

`probe_sensorless_r2_native_logger` 则单独用 62.5 ns 合成刺激检查原监督评价/启用式记录器。刺激故意包含 2 ms 多一个节拍的误有效，预期结果必须准确超过 2 ms；它不运行 SMO/PLL 或真实电机。

`probe_sensorless_r2_original_only` 加载原主模型，配置同一非理想工程工况，不安装观测层。一次初始化后推进原 native 网格，归档原 52 路，恢复模型，再做完整数据及时间节拍比较。该对照不是正式 R3 验收，也不能替代 R2 故障恢复证据。

已完成的核心/缩减图不得换标签再运行。两个 PowerShell 入口按全部既有目录检查已完成或原生失败状态；重复调用会在启动 MATLAB 前拒绝。构建期错误保留原目录，只有明确的执行前脚本/配置修正可用新目录完成首次有效计算。不得重跑已完成的数值失败。

`probe_sensorless_r2_native_queue` 另用原发布队列包装器运行 12800001 个原生节拍，按独立整数时刻检查 15995 次发布、五帧丢失、一次复位、1 μs 抖动和逐拍输出约束。其资格状态是明确的合成输入，不代表真实 SMO/PLL 的 599 个健康机会。`run_sensorless_r2_queue_probe.ps1` 仅允许执行一次，并在整模型任务运行时拒绝启动。三个新增 MATLAB 文件的静态检查无诊断项。

`record_sensorless_r2_host_observation.ps1` 只读取 Windows 已记录的硬件事件和邻近应用崩溃事件，不改电源、频率、驱动或 BIOS。已更正的处理器事件可作为独立线索，不足以确认当前 MATLAB 异常的原因。

`render_sensorless_r2_core_isolation.py` 读取核心 MAT 生成恢复图，`curate_sensorless_r2_isolation.py` 核对原模型/R1 冻结文件及运行时源码指纹，只发布报告、指纹和图片。私有环境路径、控制台、转储和大数据不入 Git。核心诊断没有前端/电压预测器反馈、原生发布队列或 CCR 时序，所有 R2 整模型状态保持不变。
