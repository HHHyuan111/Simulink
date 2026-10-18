# Sensorless 开发

基于远端 `main` 的 `8676342ad23f2d980bd4ff9fff0aeb5641a2f540`，开发分支 `dev`，工作树 `D:/simulink/dev`。

当前节点：R2 尚未通过。14 项长工况已有完整轨迹与通过的指标证据，其中 13 项开发执行及恢复通过，旧动态项原执行仍保留后处理失败。缺 5 帧恢复 29.9 ms、观测器复位恢复 67.1 ms，均无误放行；低速减速误放行 1.870 ms 接近 2 ms 上限。不同版本开发证据不拼成正式验收。2026-10-18 已冻结 820 文件候选，正式缺帧首次执行通过；第二项 +3000 rpm 初始化原生异常，按零重试规则停止，正式结果 1/14。后续独立生成目标的小模型检查通过，但主模型新后端短检在加载阶段原生异常；纯加载及停止态检查未复现，根因仍未确认，当前无长时测试运行。继续条件见[执行缺口记录](milestones/N3R2_execution_environment.md)，不重启原正式矩阵。旧 N3 保持 15/16 复现未通过，0 μs 详细桥缺项不改判。观测角度尚未接入控制反馈。

本机后续已修复参数/恢复备份持久化及生成兼容配置。整父模型生成的 20 ms 运行与恢复完成，但原控制 13 路 Data 严格比较失败；只生成观测子模型又出现原生异常，独立子模型、零仿真构建也复现。已有 183 项独立复查包及来源记录，当前没有仿真/矩阵运行；R2 不改判。最新状态及边界见[本机定位与适配记录](milestones/N3R2_local_diagnosis.md)。

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
- `milestones/N3R1.md`：非理想本地接入、完整短时复现/回归、故障入口与待验收记录。
- `milestones/N3R2.md`：已完成的评价/记录检查、两版执行历史、长工况编译异常与剩余工作；R2未通过。
- `milestones/N3R2_followup.md`：启动许可修正、五组稳态结果、全部失败历史及尚余9项工况；R2整体仍未完成。
- `milestones/N3R2_development.md`：后续动态归档复核、R/L绑定隔离、故障接口及串行长时测试进展；完整R2矩阵仍未通过。
- `milestones/N3R2_execution_followup.md`：新增边界工况、两项原生执行缺口、一次初始化入口与原日志时间格式适配；R2仍未通过。
- `milestones/N3R2_status.md`：14 项长工况的统一开发状态表，区分完整执行通过、仅归档指标复核通过和执行缺口。
- `milestones/N3R2_isolation.md`：纯函数、缩减 Simulink 核心、原生日志及无观测层主模型的分层隔离；诊断不改判整模型验收。
- `milestones/N3R2_formal.md`：冻结候选正式 14 项矩阵的逐项状态、来源与失败停止记录。
- `milestones/N3R2_generated_backend.md`：项目隔离编译依赖、实际进程边界验证及主模型生成路径在加载阶段的原生异常；未取得新短检通过。
- `milestones/N3R2_local_diagnosis.md`：本机诊断、持久化/兼容修复、20 ms 严格差异，以及独立观测子模型零仿真构建原生异常的复现包与指纹；R2 未通过。
- `milestones/N3R2_missing_recovery.md`与`N3R2_reset_recovery.md`：观测输入缺帧、观测器复位的完整轨迹及许可恢复；不代表整机故障保护已接入。
- `contracts/nonideal_r2_test_plan.json`：实施前冻结的长时精度、动态、原生误有效及故障标准。
- `robust/performance/INTERFACE.md`：R2仅评价信号、单位、原生计数/事件区间及执行器支持范围。
- `robust/integration/INTERFACE.md`：三相标定/对齐、滤波匹配、延后发布、47个作用域Goto及v2日志单位。
- `contracts/nonideal_r1_test_plan.json`与`nonideal_r1_window_addendum.json`：实施前标准及故障窗口补充刺激，历史计划均保留。
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

`verify_sensorless_n3_replay`要求完整16工况；旧N3缺项另用 `audit_sensorless_n3_archives` 出具不完整报告，整体 `all_passed=false`。后续由用户另行授权的v2非理想轨道单独验证，不以v2短时结果填补旧N3缺项，仍未批准接管。

R1正式入口为`run_sensorless_v2_r1.ps1`；要求冻结候选指纹一致，15个作业均使用独立MATLAB进程。新版本查看请在独立MATLAB会话中添加`sensorless/review`后执行`pmsm_sensorless_v2_review('open')`；`close_pmsm_sensorless_v2`恢复。此入口实际开启非理想工程配置，原先N2查看入口仍是其历史配置。62.5ns用于仿真事件核对；固件边沿分段计算和实测总耗时尚待上板阶段验证。
