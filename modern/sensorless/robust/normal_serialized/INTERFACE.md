# Normal 保存模型验收路径

实施前协议：`contracts/nonideal_r2_normal_serialized_acceptance.json`。原父模型与观测引用子模型均为 Normal，子模型声明 Single、实际一个实例、9 个 double 输入、零输出；原桥 CONTINUOUS/ode4/62.5ns 保留。

构建入口 `build_sensorless_r2_normal_serialized` 支持既有 15 项工况，保存拥有副本中的精确 86 值 Model File 工作区及真实恢复备份。实际恢复构建内存状态后退出。执行入口 `execute_sensorless_r2_normal_serialized` 独立重开，核对参数/图/备份，一次显式 Normal compile/term 读取连续桥采样，再一次 Normal sim；先保存完整原始数据，再检查终点、恢复和指标。没有显式生成目标或编译器配置。

同一个保存模型原拟供两次独立短检使用。`qualification_sources.py` 在构建前绑定 862 文件；`derivation.json` 记录从以前已归档源码进行的精确变换。`normalize_sensorless_r2_normal_serialized_archive` 只保留既有两条门极 Time 编码转换，验证器完整核对公共 81 路（含原 52）与完整 96 路 Time/Data/类型/维度，不补写虚假的 legacy 初始化字段。

**当前停止**：构建 PID 39504 通过；第一执行 PID 27864 重开/速率编译通过，在 sim 调用阶段原生退出 `0xc0000005`，没有完整原始归档。第二短检和跨进程比较未执行，新 14 项未启动。禁止重复此资格目录或替换结果；当前没有新冻结正式候选。旧正式 1/14 和全部生成路径失败继续保留。
