function p=pmsm_system_plan(value)
% Compose implemented functions without changing any legacy experiment.
here=fileparts(mfilename('fullpath'));addpath(fullfile(fileparts(here),'teaching'));
if nargin<1,value=[];end
p=pmsm_experiment_plan('speed_filter',value,.1);
p.kind='integrated_system_baseline_v1';p.duration_s=.4;
p.statistics_window_s=[.38 .4];p.plot_window_s=[.39 .4];
p.input_schedule=struct('speed_before_rpm',3000,'speed_after_rpm',2000,'speed_step_s',.2,...
 'load_before_Nm',.207,'load_after_Nm',.25,'load_step_s',.3);
p.stage_windows_s=[.16 .2;.28 .3;.38 .4];
p.stage_names={'初始平台','变速后平台','增载后平台'};
p.encoder_configurations(1).encoder_on='off';p.encoder_configurations(2).encoder_on='on';
p.feedback_configurations(1).feedback_on='off';p.feedback_configurations(2).feedback_on='on';
p.filter_configurations(1).filter_on='off';p.filter_configurations(2).filter_on='on';
p.cases(1).label='理想反馈';p.cases(2).label='编码器反馈';
for k=1:2,assert(isequal(pmsm_check_switches(p.cases(k).configuration),{'时序设置.real_on'}));end
p.comparison_contract.kind=p.kind;
p.comparison_contract.feedback_on=[false true];p.comparison_contract.filter_on=[false true];
p.comparison_contract.angle_on=[false true];p.comparison_contract.angle_feedback='参考为原角度；组合为同次机械计数恢复的电角度';
p.comparison_contract.scope='两组同一真实时序、原理想桥、PI、电机、初态和给定；同时改变角度与速度反馈，不作单因素归因。';
p.comparison_contract.power='原理想桥；门极死区、压降及补偿关闭。当前无功率关断场景，续流及死区通过原单项实验和后续组合另验。';
p.comparison_contract.startup='已知正确电角零位，控制环直接执行；历史不足测速零，无启动门控、自动定位或主动保护';
p.numerical.note='两组均62.5ns事件网格，20kHz电流/编码器/测速/滤波，10kHz速度任务；400ms含变速与增载，高频诊断尾4000点，其他保留信号全程。';
p.acceptance=struct('iq_command_max_A',8,'speed_error_mean_abs_max_rpm',30,...
 'speed_span_max_rpm',60,'platform_abs_slope_max_rpm_per_s',100,...
 'note','平台指标逐窗口判定，不能仅凭末端值称为稳态；不以两组指标谁更优作为正确性条件。');
end
