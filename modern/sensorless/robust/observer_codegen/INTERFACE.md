# 仅观测器生成的执行边界

该路径未资格通过：实际父模型 Normal、子模型 Accelerator 的短检在首次子目标构建时原生异常，退出 `0xc0000005`，仿真启动 0。不得重启原输出目录或据组件结果放行长矩阵。

`build_sensorless_r2_observer_codegen` 在拥有副本上配置既有工况，父模型原桥始终为 CONTINUOUS，原 ode4/62.5ns 不变。子模型保存为精确 86 值 Model File，实际单实例、Single 声明和 Accelerator 模式；9 输入、零反馈输出。源码和数据由 `sensorless_r2_observer_codegen_snapshot` 绑定，保存后实际恢复原图、工作区、回调与固定参考，并核对桥元数据未变。

`execute_sensorless_r2_observer_codegen` 只重开保存模型，核对参数、结构和备份，然后只构建子模型 `ModelReferenceSimTarget`。原登记的后续步骤是父模型连续速率 compile/term、一次 Normal sim、先保存全部原始日志再恢复/计算；本次未执行到这些步骤。不能用旧 Rapid 父模型的物理数据替代本次结果。

格式适配器 `normalize_sensorless_r2_observer_codegen_archive` 保留冻结 v8 的两条门极 Time 编码转换。新验证器直接核对相同 81 路公共日志及完整 96 路数组和实际单次 sim/恢复证明，不伪造旧版 `initialized_once` 字段，不放宽 Data/类型/维度。

`derivation.json` 记录从此前归档源的精确变换；以前执行过的源文件和失败记录均保留。当前独立子模型复查也原生异常，证明无需加载父模型或运行物理过程即可触发生成构建问题；这仍不等于确认 MATLAB 软件缺陷或硬件根因。独立包和来源见本节点记录。
