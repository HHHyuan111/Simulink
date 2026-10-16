# Sensorless 开发

基于远端 `main` 的 `8676342ad23f2d980bd4ff9fff0aeb5641a2f540`，开发分支 `dev`，工作树 `D:/simulink/dev`。

当前节点：用户要求在真实节拍与非理想条件下继续实现，并授权先按工程假设推进。N3R0的电压/节拍/控制许可组件与独立复现通过，等待本节点验收；尚未接入主模型做组合性能测试。旧N3保持15/16复现未通过，0 μs详细桥原生异常缺项不改判。N0/N1/N2已由用户确认，观测角度尚未接入控制反馈。

- `contracts/acceptance_v1.json`：验收阈值与判定规则。
- `contracts/test_plan_v1.json`：固定场景、事件、窗口及复跑要求。
- `contracts/parameters_v1.json`：本地参数名称、单位、来源及范围。
- `contracts/signals_v1.json`：输入、内部状态、评价信号及观测页面。
- `baseline/source_manifest.json`：基准提交与文件指纹。
- `baseline/n0_inventory.json`：实际MATLAB工作区、编译速率及基线运行结果。
- `baseline/log_schema.json`：实际旧日志清单，后续旁路回归按此清单检查。
- `milestones/N0.md`：本节点验收记录。
- `milestones/N1.md`：N1实现、独立验证、复跑及开发失败记录。
- `milestones/N1/`：组件指标、两张观测图和来源指纹。
- `milestones/N2.md`：本地接入、严格回归、跨进程核验、运行限制与查看入口。
- `milestones/N2/`：完整报告、参数、结构图、归档波形和首末区间明细。
- `milestones/N3.md`：性能结果、完整复现缺项、有效标志局限及下一步。
- `milestones/N3/`：完整固定窗口指标、事件指标、误有效区间、波形、源码和数据指纹。
- `contracts/nonideal_v2.json`：独立于v1的非理想工程假设、正常/故障工况及更严格的有效性目标。
- `milestones/N3R0.md`：非理想适配前置节点的实现、组件验证和未完成项。
- `robust/INTERFACE.md`：独立电压、节拍和发布许可核心；未自动装入当前GUI模型。
- `INTERFACE.md`：模块、Goto作用域、参数单位、时间及日志约定。

原有主模型、固定参考和PI保持；后续算法在当前模型中做可撤销旁路接入。每个节点提交记录后停在验收点，不自动进入下一节点。

N0基线检查入口，在独立MATLAB进程执行：

```matlab
cd('D:/simulink/dev/modern'); addpath('sensorless'); sensorless_n0_inventory
```

本地原始数据存于 `runs/`，不随Git提交。提交配置、指标、原始数据指纹和复现入口。

N1组件验证（独立MATLAB进程，不加载PMSM模型）：

```matlab
cd('D:/simulink/dev/modern'); addpath('sensorless');
r=validate_sensorless_n1;
```

在另一个全新MATLAB进程中执行 `repeat_sensorless_n1(r.folder)`，其中路径取上一进程输出的结果目录。已有归档的具体入口见N1记录。`render_sensorless_n1(结果目录)`只读取归档数据生成图片。

打开本地dev模型中的旁路层：

```matlab
cd('D:/simulink/dev/modern'); addpath('sensorless');
open_pmsm_sensorless;
% 查看结束后：close_pmsm_sensorless
```

N2科学检查入口为 `validate_sensorless_n2`。复跑与原始数据核验方法见 N2 记录；波形采用 `export_sensorless_n2_review` 导出全控制速率 CSV，再由 `render_sensorless_n2.py` 绘制，绘图依赖 numpy/matplotlib。已交付图片是归档数据图，不是原生 Scope 截屏。

N3完整矩阵入口为 `run_sensorless_n3.ps1 -Label formal -IncludeBaselines`，复跑用 `-Label replay -ReplayOf 正式轮目录`。每个工况独立MATLAB进程，只有明确原生异常才允许一次重试，不以重复运行选优。

`verify_sensorless_n3_replay`要求完整16工况；本次缺项另用 `audit_sensorless_n3_archives` 出具不完整报告，整体 `all_passed=false`。审阅当前成果不等于批准接管，N3缺项解决前不进入下一节点。
