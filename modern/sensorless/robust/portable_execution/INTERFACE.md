# R2 保存、重开与生成执行适配

该路径尚未取得严格 96 路短检通过，不能用于宣称 R2 验收。原 Normal 正式候选保持 1/14、失败停止。

`build_sensorless_r2_staged(case_id, output_folder)` 在独立构建进程中，从原 SLX 的拥有副本安装旁路层。支持冻结计划中的 15 项工况，保存父/子 Model File 工作区和实际恢复备份。构建后的 `handoff.mat`、`record.json`、两份 SLX 和源码快照绑定 SHA256。模型参数由构建入口计算；导出模型清空 InitFcn 后是该工况的精确快照，修改电机/掩码参数需要重新构建与核对，不应在导出副本中直接修改后冒充同一候选。

`execute_sensorless_r2_staged(build_folder, output_folder)` 仅重开已保存模型；编译前核对父/子各 86 个变量的值、类型、维度，核对回调、9 输入零反馈输出、原主图及持久化备份。每项只允许一次编译和一次全时长仿真。先归档所有原始 timeseries，再检查原生终点、移除旁路层并恢复、计算指标。最终格式适配使用既有 `normalize_sensorless_r2_v8_archive`；不修改 Data。

本轮构建 PID 58472 已通过。原执行入口的复制子目录错误保持失败；前瞻修正只改变加载前资料分发及来源绑定。修正后 PID 13724 已通过保存值和图核对，但 Coder 拒绝 `Universal Bridge/续流` 的连续更新，退出 1，仿真启动次数 0。**不重启这两个输出目录或同版执行器。** `robust/diagnostics/staged_preload_repair.json` 保存原/修正执行器散列及文本推导范围。

构建与执行副本只位于 `runs/`，原模型和用户 GUI 不保存、不修改。隔离 MinGW 通过当前子进程环境和独立 MATLAB_PREFDIR 配置；没有安装系统编译器或改变默认 MATLAB 编译器偏好。没有切换 SMO 反馈。

后续连续继承组件检查及适用边界见 `contracts/nonideal_r2_freewheel_inheritance_probe.json`。组件通过后也必须另行登记主模型适配与完整短检，不能直接放行长矩阵。
