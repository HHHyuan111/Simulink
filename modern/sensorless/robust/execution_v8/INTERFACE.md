# 一次初始化执行入口

此目录适配本地 R2026a 的 Simulation 对象生命周期，SMO/PLL/质量门槛和控制器不调参。沿用 v7 故障模块及作用域 Goto。低速工况沿用本地动态请求源，并接入同一 v7 普通程序，包括不可用电流锚点准入。

原入口显式 update 后再 sim，仿真会重新初始化；本入口在观测层装好后只 initialize 一次，在该编译态只读检查结构/工作区，随后分块推进主步长，途中不改状态、图或参数。固定步长运行必须完成 duration/h+1 次主步，包含 0 和终点。每块只写进度，不参与许可判定。正常完成后接口的下一主步时间可能是 NaN，因此终点依据输出日志及原生计数；小模型的离散/连续/偏移采样、回调次数、终点和参数恢复均有实际验证。

官方接口依据：[R2026a Simulation](https://www.mathworks.com/help/releases/R2026a/simulink/slref/simulink.simulation.html)、[step](https://www.mathworks.com/help/releases/R2026a/simulink/slref/simulink.simulation.step.html)。

编译产物使用独立的 `sensorless/.build/v8r1/<UUID>/` 短路径，并在加载前检查代表性生成路径长度。源快照、配置、恢复证明和物理数据仍归档到各 runs 作业目录。

## 时间格式

原两路门极日志 `obs_dead_gates` / `obs_dead_requested` 仍只保留 4000 点。Simulation 对象给出的密集 Time 与直接 sim 的均匀 TimeInfo 编码在末位可能不同。实际 20 ms 数据证明：96 路 Data 全相同、94 路 Time 也全相同；上述两路的整数原生节拍相同，Time 最大相差 3.4694469519536142e-18 s。

`normalize_sensorless_r2_v8_archive` 保留原档，只在派生 `log_format/` 中用已配置 h 重建这两路的均匀时间表示。需验证原始容量、样本数、连续节拍、相同 tick 和不超过 4 ULP 的编码差。没有截取、插值、重采样、改值或许可筛选。其他 94 路数组不变。派生短档严格通过全部 96 路及 R1 的 81 路完整 Time/Data 比对，包含原 52 路。原失败流水及原始档保持。

## 入口与状态

- `validate_sensorless_r2_execution_toy`：独立生命周期组件；包含一次保留的解析错误及一次 API 终点假设错误，后续修正记录不覆盖。
- `validate_sensorless_r2_v8_case`：单次初始化的主模型执行与完整归档，先恢复模型再算指标。
- `run_sensorless_r2_v8.ps1`：先检查前置证据及源指纹，只允许尚无完整物理归档且旧路径已停止的工况。每个实现/工况最多 2 次启动，只有明确的 0xc0000005/0xc000001d 才能重试。
- `run_sensorless_r2_v8_remaining.ps1`：串行收集低速、丢帧、复位；一个工况执行失败时仍保留记录并继续其他独立工况，不把执行完成等同于性能通过。

旧 v5/v7 原生失败未重试或改判，原生根因未确认。此入口不是完整 R2 节点验收，也没有进入 R3、实板 WCET 验证或反馈接管。
