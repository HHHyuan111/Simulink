# 同机同版本独立安装对照

2026-10-18，用户已授权项目内新增官方 MATLAB、Simulink、Stateflow。先提交协议 `17ccf66`，再进行工具下载/安装。原 R2 失败继续保留，当前节点仍未通过，未启动新长矩阵。

- 官方 MPM 2026.8，MathWorks 有效签名，84762976 字节，SHA256 `10a7265efd1660d39ee27c24629fd7826aea6eeb7f6ad721f5e00ff7f0037939`。
- 目标 `D:/simulink/dev/modern/sensorless/.build/matlab_clean/R2026a_U5`，此前不存在；明确指定 `R2026aU5`、MATLAB/Simulink/Stateflow。
- 标准 UAC 已授权启动项目安装。第一 Windows PowerShell 宿主退出，未创建安装状态/未启动 MPM；该宿主策略均 Undefined（Windows 默认限制脚本），没有修改策略。随后使用本机已配置 RemoteSigned 的 PowerShell 7 宿主正常进入安装，包装 PID 36104，MPM 50420/58308。两次宿主启动均保留，不能称第一次产品安装失败或掩盖为零尝试。
- 安装仍在进行，运行时版本、授权及源码路径尚未通过检查，物理仿真启动 0。没有复制原安装或许可文件。

[先登记的范围与判据](../contracts/nonideal_r2_clean_install_control.json)、[运行前四文件绑定](N3R2/clean_install_20261018/pre_execution_sources.json)。诊断明确复用前轮同字节 SLX/handoff 及原 862 文件，原 86 参数、连续桥、求解器/步长、节拍、96 路及原 81/52 路严格门槛保持。新运行时不符 `26.1.0.3346908 (R2026a) Update 5`，或授权/函数来源检查失败，则停止在运行前，不启动物理对照。运行至多一次；失败不重试，成功也不计作两次正式资格检查或 R2 通过。

Windows 管理员要求及安装参数依据：[官方获取 MPM 说明](https://www.mathworks.com/help/install/ug/get-mpm-os-command-line.html)、[官方 install 参数](https://www.mathworks.com/help/install/ug/mpminstall.html)。所有偏好、缓存设置仅用于私有进程；旧安装及其用户 GUI 未由脚本修改或终止。新安装共享同一台计算机，不能凭一次结果排除硬件、系统或非确定性因素。
