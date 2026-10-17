# R2 故障适配接口（工程假设，旁路）

本目录复用本地 R1 方程与状态结构，不导入 Ref 模型。新增接线位于原有九模块布局中，使用 `SLessV2_` 前缀和作用域 Goto。真值仍只进入 `/观测` 下的评价器。原 SLX 不保存；普通工况控制器及 PI 不改动。

`sensorless_r2_fault_program` 将冻结测试合同转为 22 个 double，布局见 `contracts/nonideal_r2_fault_adapter_design.json`。实际时间基准为 62.5 ns 仿真网格，控制周期 50 μs，JEOS 偏移 28.875 μs。3 μs 观测预算与 5 μs FOC 预算为工程假设，尚无实测 WCET。

| 新日志 | 节拍 | 内容和单位 |
| --- | --- | --- |
| `obs_sless_r2_actual_publications` | 实际完成事件 | 原 13 列发布格式；前 4 列为序号、参考时刻 s、完成时刻 s、年龄 s；5–7 列角度 rad；8 列速度 rpm；9–11 列控制出口 rad/rpm；12 列 PWM 应用时刻 s；13 列完成标志 |
| `obs_sless_r2_fault_queue` | 每个 JEOS | 8 列：流代次、丢帧、软件复位、完整性锁存、接受完成事件、待发序号、待发参考时刻 s、待发完成时刻 s |
| `obs_sless_r2_anchor_valid` | 每个 JEOS | 是否允许当前 ADC 电流作为电压预测器锚点 |
| `obs_sless_r2_release_jitter_s` | 每个 JEOS | 发布抖动 s |
| `obs_sless_r2_interference_s` | 每个 JEOS | FOC 写 CCR 前附加阻塞 s |
| `obs_sless_r2_fault_reference_s` | 每个 JEOS | 故障计划所用参考时刻 s |
| `obs_sless_r2_pwm_events` | 原生 UEV/写入事件，仅时序工况 | 原 PWM 诊断 12 列；时间戳来自事件实际发生时刻，未沿用 1 μs 显示日志推断 62.5 ns 边界 |

原固定 `JEOS+3 μs` 发布显示日志保留；发生抖动或丢帧时，验收使用新增实际完成日志，按包内参考时刻匹配电流/SMO/PLL 采样，不按行号拼接。新增故障原因位为 1024 软件复位、2048 声明丢帧、4096 未知序号/时间故障锁存，原位定义保持。

丢帧只阻断观测消费者，物理 ADC 和控制器继续；不可用数据不进入对齐、微分或电流锚点。已知偏置滤波和电压模型继续因果推进。软件复位清除 SMO/反电势/PLL/质量判断及电流差分历史，保留前端记忆，不代表整板断电。声明丢帧/复位时显式开启新流代次；未知序号跳变仍拒绝并锁存，不能借此放宽原 R0 连续性检查。

时序工况只替换本地物理 PWM 事件执行器：在 JEOS 绑定该帧预算，在实际写入点读取控制请求，UEV 在同刻写入之前执行。最大 38 μs 小于 50 μs 任务周期，因此覆盖 PWM 更新/截止期跨越；不声称已实现真正中断任务重叠，超出范围明确报错。

组件入口为 `validate_sensorless_r2_fault_cores`。其 599 帧恢复是合成质量输入夹具，只能证明许可队列行为；真实重新锁定和恢复时间必须通过完整物理故障轨迹。短时图检查入口 `probe_sensorless_r2_fault_model` 不能代替 0.8 s 故障验收。
