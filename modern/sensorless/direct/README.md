# 主模型直接接入 SMO

按用户 2026-10-19 的要求，正常算法开发不引入引用模型包装、高频真值评价器或故障刺激平台。历史实验保留记录，当前模型不装入这些模块；后续算法沿用这一范围。

本地电机/FOC、工程假设下的 ADC/滤波、死区/压降、真实采样时刻和计算延迟保持。SMO、反电动势和 PLL 复用原数学核心。电压重构继续使用现有因果方程，仅允许有效 ADC 数据校正电流预测；`robust/faults` 路径在此仅提供该电压数学函数，没有加载故障模型构造器。发布模块只处理正常采样与计算完成，不带故障计划或注入端口。

工作模型生成在 `sensorless/models/direct/PMSM_FOC_R2026a.slx`，原始主模型不变。参数保存在模型工作区，观测命名与单位保持原约定，内部信号使用作用域 Goto/From。普通 Scope 和日志按 50 μs 采样；另记录实际完成的数据包（13 列原发布数据，14 列许可，15 列原因位）。真实角度和转速只进入控制周期观测与离线误差计算。

在独立 MATLAB 会话内：

```matlab
addpath('D:/simulink/dev/modern/sensorless/direct');
base=sensorless_direct_setup;
open_system(fullfile(base,'models/direct/PMSM_FOC_R2026a.slx'));
```

日常查看直接打开保存模型并运行即可。从 Git 获取代码后如需完整重做本节点验证，在各自独立的 MATLAB 会话中依次执行 `run_sensorless_direct_baseline`、`run_sensorless_direct('first')`、`run_sensorless_direct('repeat')`；它们生成同为 0.25 s 的原控制对照、首次 SMO 和独立复跑，不依赖本地旧归档。已有结果目录保留，不覆写。

标准在运行前写入 `acceptance.json`：3000 rpm、0.25 s、固定 0.162–0.25 s 窗口、至少 20 电周期，角度 RMS ≤3°/峰值 ≤8°，转速均值误差 ≤1%/RMS ≤2%，电机均值偏差 ≤1%/斜率 ≤50 rpm/s，实际完成事件许可占比 ≥99%。同时检查 5000 个样本、实际 3 μs 发布延迟、原 52 路控制日志及两次一致性。

此入口目前针对固定工程参数。电机或物理配置更改后需同步重新计算模型工作区与观测参数；不能只修改参数显示值后沿用旧验证结果。模型不使用观测角度接管 FOC。
