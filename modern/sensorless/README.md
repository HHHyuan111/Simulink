# Sensorless 开发

基于远端 `main` 的 `8676342ad23f2d980bd4ff9fff0aeb5641a2f540`，开发分支 `dev`，工作树 `D:/simulink/dev`。

当前节点：N0，冻结基线、测试标准、参数与信号接口；完成后等待用户验收。尚未实现或接入SMO、PLL。

- `contracts/acceptance_v1.json`：验收阈值与判定规则。
- `contracts/test_plan_v1.json`：固定场景、事件、窗口及复跑要求。
- `contracts/parameters_v1.json`：本地参数名称、单位、来源及范围。
- `contracts/signals_v1.json`：输入、内部状态、评价信号及观测页面。
- `baseline/source_manifest.json`：基准提交与文件指纹。
- `baseline/n0_inventory.json`：实际MATLAB工作区、编译速率及基线运行结果。
- `baseline/log_schema.json`：实际旧日志清单，后续旁路回归按此清单检查。
- `milestones/N0.md`：本节点验收记录。

原有主模型、固定参考和PI保持；后续算法在当前模型中做可撤销旁路接入。每个节点提交记录后停在验收点，不自动进入下一节点。

N0基线检查入口，在独立MATLAB进程执行：

```matlab
cd('D:/simulink/dev/modern'); addpath('sensorless'); sensorless_n0_inventory
```

本地原始数据存于 `runs/`，不随Git提交。提交配置、指标、原始数据指纹和复现入口。
