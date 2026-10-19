# 本地 SMO 无感闭环

工作模型：`../models/closed_loop/PMSM_SMO_ClosedLoop.slx`。从本地已通过的 SMO 旁路模型适配，直接接入原 FOC；启动、切换、速度 PI、Park/反 Park 和解耦均不读取真实转子角度或速度。

控制阶段为对齐 → I/F 起动 → 估计角平滑切换 → 退出起动 Id → 无感速度闭环。`闭环结果观测` 内两个原生 Scope 分别显示 0–0.50 s 全过程、最后 88 ms 稳态。真实转子量只在观测区用于对照。Scope 内的「SMO反馈」在起动阶段显示 I/F 内部速度，估计权重达到 1 后才完全来自 SMO。

在 MATLAB 打开模型和原生 Scope，不自动运行：

```matlab
addpath('D:/simulink/dev/modern/sensorless/closed_loop');
open_sensorless_closed
```

点击模型运行按钮得到本次 Scope 波形。未运行时没有历史波形，不向原生 Scope 注入归档数据。

独立执行入口为 `run_closed.ps1`：`-Step first -Label closed_a` 使用独立隐藏会话，`-Step repeat -Label closed_b` 使用独立可见会话并保留 Scope。标签使用英文字母、数字、下划线；每个标签新建一份本地归档，保留实际执行模型、预登记标准、原始 signals.mat、数据指纹及 metrics/report.json。Git 提交源码、模型、标准、指标与原生截图，原始大文件保留本地。

`acceptance.json` 是实施前确定的验收标准；`INTERFACE.md` 说明本地接口、单位与节拍；`DESIGN.md` 记录首轮失败及基于实际轨迹的起动/PLL 动态适配。工程假设的 ADC、滤波、死区、器件压降和计算延迟仍在模型中，当前结果不代表实板验证。
