# 单因素执行诊断

实施前合同：`contracts/nonideal_r2_block_reduction_diagnostic.json`，提交 `b4fcec3`。

仅在独立进程的私有模型中将原本为 `on` 的 `BlockReduction` 改为 `off`。沿用 v8r1 的一次初始化、短缓存及全部数学核心；完成后显式恢复原值，原 SLX 不保存。标准仍来自冻结的 R2 计划。

入口：`run_sensorless_r2_v9.ps1 -CaseIds r1_short_logging_check`。完整 96 路严格回归及恢复通过后，才允许 `missing_five`、`reset_one`，已有完整物理归档的长工况被禁止重跑。每工况每版本最多两次启动，第二次只限明确 0xc0000005/0xc000001d。0x80000003 等其他异常停止，不重试。所有历史失败保留。

运行成功只提供该执行配置下的证据；不能证明原生异常根因，也不能替代最终冻结候选的完整矩阵。日志归一化仅复用事先登记的两路门极时间格式适配，原始归档不改写。
