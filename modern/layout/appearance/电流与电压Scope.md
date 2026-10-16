# 电流与电压

入口：教学工作台“电流与电压”，或双击09区原“测量观测”。也可运行：

```matlab
addpath('D:/simulink/modern/teaching')
open_pmsm_electrical_scope
```

采用原生Scope、白底2×2、自动纵轴量程，同一次运行的四幅图共用时间范围。

| 位置 | 主题 | 来源 |
| --- | --- | --- |
| 左上 | 三相电流 | 电机真实ia、ib、ic |
| 右上 | 测量电流 | 采样链最终输出ia、ib、ic |
| 左下 | d轴电压 | 限压前请求vd_req、限压后vd_lim |
| 右下 | q轴电压 | 限压前请求vq_req、限压后vq_lim |

先看全程，再使用原生缩放观察稳态的几个电周期。上下游电流并排可观察采样误差、量化、噪声及延迟；分别开启这些因素才能判断来源。给定工况下两路重合是正常现象，不人为制造差别。

这里的电压是控制器坐标系中的指令，限压后值仍是指令，不是逆变器实际相电压或电机真实dq电压。请求与限压曲线重合说明当前未触及限压，不能据此判断死区补偿效果。死区、桥臂开关和实际输出电压留给下一页“PWM与采样”。

所有新增观测直接分支已有日志来源，不改动控制通路、PI、电机参数和固定SLX。原独立示波器保留。撤销顺序：

```matlab
pmsm_pwm_scope('remove')
pmsm_electrical_scope('remove')
pmsm_native_scope('remove')
pmsm_presentation('remove')
```

恢复时反向执行apply/install。固定实验入口自动完成这一步，包括异常退出后的恢复。显示层启用时不直接保存SLX；配置保存在脚本中。

验证记录：electrical_scope_validation.json。范围是理想及角度偏置两种10ms工况，核对原日志不变、新显示数据一致、完整撤销、固定参考和异常恢复；不代替全工况或实板标定。

后续顺序：控制响应 → 电流与电压 → PWM与采样 → 具体单因素实验的频域分析。每页先明确观测问题，再增加变量。

实际200ms预览：[电流与电压](native_electrical_scope_white.jpg)。来源与指纹见 native_electrical_scope_source.json。


