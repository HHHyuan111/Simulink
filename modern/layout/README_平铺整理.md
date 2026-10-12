# 平铺模型布局整理

当前模型仍为 `D:\simulink\modern\PMSM_FOC_R2026a.slx`。按 2026-10-11 的要求，撤回子系统封装、总线替换和新增 Scope，恢复用户截图对应的平铺版本，然后仅修改图形布局。

- 164 个顶层小模块保持原名称、SID、层级、参数、遮罩和连接，内部实现保留。
- 九个色域均为 860 × 580，横纵间距均为 40。
- 第一行：速度环、电流环、坐标变换；第二行：SVPWM、逆变器与 PMSM、采样反馈；第三行：数据观测、调制观测、辅助观测。
- 原 17 个 Scope、XY Graph、Goto/From、Chirp 辅助支路和 `Validation logging` 保留。

`flat_tidy.png` 是实际模型导出图；`flat_tidy_verification.json` 记录所有块路径、SID、参数、连接、遮罩、工作区、求解配置和 MATLAB Function 源码的前后比较，以及默认 1 s 的 12 路仿真记录比较。这里只验证布局没有改变原行为，未进行控制算法调优或开发板适配。

`prepare_flat_tidy.py` 生成现有块的坐标；`tidy_flat_layout.m` 应用图形位置、色域与注释，重新走线并验证，验证通过后才保存。此脚本不会恢复旧备份或创建新的控制子系统。

备份：

- 截图对应平铺版：`../organization/backups/pre_structure_20261010/PMSM_FOC_R2026a.slx`。
- 已撤回层级版磁盘文件：`../organization/backups/rejected_structure_20261011.slx`。
- 已撤回层级版窗口未保存状态：`../organization/backups/rejected_gui_20261011/PMSM_FOC_R2026a.slx`。

原来的 `after.png` 留作旧布局对照，未覆盖。
