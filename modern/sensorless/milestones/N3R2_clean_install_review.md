# 已授权：同机、同版本官方独立安装对照

用户已明确同意项目内独立安装。已先登记[对照协议](../contracts/nonideal_r2_clean_install_control.json)，再下载签名有效的官方 MPM 2026.8，并完成项目内 R2026aU5 安装（退出 0）。**首次运行前启动因未找到许可证停止，未运行检查脚本或模型仿真**。本机当前 Normal 短检和独立子模型构建均原生异常；源码/参数指纹没有发现变化，根因尚未确定。用户暂无另一台机器或另一套 MATLAB。新增 MATLAB 安装已经取得单独确认。

建议在项目私有目录新建官方 R2026a Update 5 安装，保留现有 `D:/DevTools/MATLAB/R2026a`。明确指定更新版本，避免把版本升级混入对照。

|项目|预定范围|
|---|---|
|安装位置|`D:/simulink/dev/modern/sensorless/.build/matlab_clean/R2026a_U5`，必须是新目录|
|下载及工具位置|`.build/matlab_clean/`，不进入源码提交|
|版本|`R2026aU5`；安装后先核对实际 version 和更新号，若与现有 `26.1.0.3346908 (R2026a) Update 5` 不一致，先停止解释数值等价|
|产品|MATLAB、Simulink、Stateflow，依赖由官方 MPM 解析；不安装新编译器或额外硬件支持包|
|资源|可能为数 GB 下载/安装，确切大小以官方清单为准；当前 D 盘约 413 GB 可用，尚未预留或写入安装文件|
|现有环境|不覆盖原安装，不改其配置；新进程使用私有 MATLAB_PREFDIR、缓存和明确的新 exe 路径；安装及正常授权交互若提出额外操作，先记录具体要求|

官方 MPM 支持以 `R20XXyUn` 指定更新版本，并指定安装目录、产品及自动依赖。[官方安装参数](https://www.mathworks.com/help/install/ug/mpminstall.html)、[更新版本下载参数](https://www.mathworks.com/help/install/ug/mpmdownload.html)。拟执行产品安装命令的范围是：

```powershell
mpm.exe install --release=R2026aU5 --destination=D:\simulink\dev\modern\sensorless\.build\matlab_clean\R2026a_U5 --products=MATLAB Simulink Stateflow
```

批准后，先登记独立环境诊断协议，再安装和检查运行时、签名/核心 DLL 指纹及函数来源。模型、862 源码绑定、86 参数和求解器均固定。只允许一次明确标为诊断的同字节 Normal 20 ms 对照，先验收全部 96 路严格数据/原生终点/恢复；不重启原已失败的资格目录，不把诊断标签改成正式验收。

对照通过只能说明该新环境下本次未复现异常；若核心二进制相同或没有确定安装差异，仍须披露非确定性，不能直接宣布原环境/硬件原因已确认。对照再次原生异常则保留失败，转向更小的源代码触发条件或厂商运行时分析。任何结果均不自动放行 14 项长矩阵；正式新候选仍需满足已批准的两次独立严格短检及新冻结流程。

实际安装状态见[独立安装节点记录](N3R2_clean_install.md)。安装工具私有日志、下载数据及二进制不提交 Git。
