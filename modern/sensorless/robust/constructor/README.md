# 按端口实测记录接入的构造器

此目录只改变本地主模型的接入生命周期：装入观测层之前不编译原图。算法方程、采样节拍、日志和验收阈值沿用原登记版本。

- `pmsm_sensorless_geometry_model.m`、`pmsm_sensorless_v2_geometry_model.m`、`pmsm_reference_geometry.m` 是从冻结源码生成的适配器。不要手工编辑；`../diagnostics/generate_geometry_constructors.py` 检查每一处允许的替换以及原文件指纹。
- `sensorless_r2_constructor_geometry.m` 验证原 SLX、源 SID、端口身份和实测尺寸记录。该记录来自独立的一次编译审计，不在接入时触发编译。
- `validate_sensorless_r2_constructor_case.m` 在全部模块接入后初始化一次，再推进同一个仿真对象。每次执行保存源码、配置、恢复证据和完整原始轨迹。
- `../../run_sensorless_r2_constructor.ps1` 限制同版本每工况最多两次启动，仅明确的 `0xc0000005` / `0xc000001d` 可进行第二次；已完成的物理轨迹禁止重跑选优。

先通过完整 96 路短检，再执行此前尚无完整轨迹的缺 5 帧和复位 1 帧。短检通过不能证明长仿真稳定，也不能确认底层异常的根因。

依据：`../../contracts/nonideal_r2_constructor_geometry_design.json`、`../../contracts/nonideal_r2_constructor_reference_addendum.json`。完整 R2 候选仍须单独冻结，并按同一配置完成全部 14 项长工况后提交用户验收。
