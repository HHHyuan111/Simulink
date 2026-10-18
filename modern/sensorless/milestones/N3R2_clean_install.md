# 同机同版本独立安装对照

2026-10-18，用户已授权项目内新增官方 MATLAB、Simulink、Stateflow。先提交协议 `17ccf66`，再进行工具下载/安装。原 R2 失败继续保留，当前节点仍未通过，未启动新长矩阵。

**当前结果：安装成功，启动因缺少许可证停止；模型/物理仿真启动 0。** 安装于本地 21:51:09 返回 0；版本 XML 为 `26.1.0.3346908 / R2026a / Update 5`，与原安装一致。新运行时的 MATLAB `version` 表达式尚未执行，不能把文件版本核对写作运行前检查通过。

11 个核对的核心 DLL 新副本签名均有效，且 SHA256 全部与原安装一致（包括 m_lxe.dll）。这未发现所核对文件的损坏，不代表整个安装或系统环境已证明一致，也没有确定原生异常根因。23:28:31 启动的运行前检查 PID 52840 在 MATLAB 许可启动阶段退出 1，私有 stderr 出现 `Unable to find a license`；没有运行前 report，没有加载/编译/仿真。此项保留停止，原目录不重试。

已核对官方激活客户端有效 MathWorks 签名并启动，等待用户完成正常激活；没有读取/复制许可内容，未发布原始日志。激活完成后须登记明确的后续运行目录，保留本次许可启动失败；物理对照仍最多一次、相同 862 源码/保存模型和原严格判据。

[脱敏状态与来源核对](N3R2/clean_install_20261018/summary.json)、[核心文件逐项比较](N3R2/clean_install_20261018/binary_comparison.json)、[仅含日志指纹及固定提示的观察](N3R2/clean_install_20261018/startup_observation.json)、[本次进程记录](N3R2/clean_install_20261018/campaign.json)。

- 官方 MPM 2026.8，MathWorks 有效签名，84762976 字节，SHA256 `10a7265efd1660d39ee27c24629fd7826aea6eeb7f6ad721f5e00ff7f0037939`。
- 目标 `D:/simulink/dev/modern/sensorless/.build/matlab_clean/R2026a_U5`，此前不存在；明确指定 `R2026aU5`、MATLAB/Simulink/Stateflow。
- 标准 UAC 已授权启动项目安装。第一 Windows PowerShell 宿主退出，未创建安装状态/未启动 MPM；该宿主策略均 Undefined（Windows 默认限制脚本），没有修改策略。随后使用本机已配置 RemoteSigned 的 PowerShell 7 宿主正常进入安装，包装 PID 36104，MPM 50420/58308。两次宿主启动均保留，不能称第一次产品安装失败或掩盖为零尝试。
- 安装已完成；运行时启动因缺少许可证停止，运行时版本/授权/函数来源检查尚未执行，物理仿真启动 0。没有复制原安装或许可文件。

[先登记的范围与判据](../contracts/nonideal_r2_clean_install_control.json)、[运行前四文件绑定](N3R2/clean_install_20261018/pre_execution_sources.json)。诊断明确复用前轮同字节 SLX/handoff 及原 862 文件，原 86 参数、连续桥、求解器/步长、节拍、96 路及原 81/52 路严格门槛保持。新运行时不符 `26.1.0.3346908 (R2026a) Update 5`，或授权/函数来源检查失败，则停止在运行前，不启动物理对照。运行至多一次；失败不重试，成功也不计作两次正式资格检查或 R2 通过。

Windows 管理员要求及安装参数依据：[官方获取 MPM 说明](https://www.mathworks.com/help/install/ug/get-mpm-os-command-line.html)、[官方 install 参数](https://www.mathworks.com/help/install/ug/mpminstall.html)。所有偏好、缓存设置仅用于私有进程；旧安装及其用户 GUI 未由脚本修改或终止。新安装共享同一台计算机，不能凭一次结果排除硬件、系统或非确定性因素。

正常激活入口依据：[MathWorks 手动激活说明](https://www.mathworks.com/help/install/ug/activate-matlab-installation-manually.html)。账号及许可信息只在官方客户端填写。
