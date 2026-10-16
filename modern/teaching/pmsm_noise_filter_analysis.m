function [a,trace]=pmsm_noise_filter_analysis(outputs,plan)
% Decompose the existing linear filter using each case's own true current.
% This is post-processing only; no control or physical signal is replaced.
assert(strcmp(plan.scenario.id,'noise_filter')&&numel(outputs)==3);
t=outputs{1}.log_iabc_true.Time;dt=median(diff(t));fc=plan.value(2);alpha=exp(-2*pi*fc*dt);
assert(abs(dt-plan.comparison_contract.control_period_s)<1e-12);
window=plan.statistics_window_s;tail=t>=window(1)&t<=window(2);assert(any(tail));
trace=struct('time_s',t,'injected',{{}},'noise_component',{{}},'deterministic_error',{{}},'measurement_error',{{}});
a=struct('schema',1,'statistics_window_s',window,'control_period_s',dt,'filter_hz',fc,'alpha',alpha, ...
 'definition','各组测量总误差=本组滤波确定性误差+本组噪声分量；滤波分解使用同一组真实电流和实际注入序列，不是另一次仿真。', ...
 'cases',struct('id',{},'noise_injected_rms_ABC_A',{},'noise_component_rms_ABC_A',{}, ...
 'deterministic_error_rms_ABC_A',{},'measurement_error_rms_ABC_A',{},'decomposition_max_abs_error_A',{}));
for k=1:3
 s=outputs{k};
 for name={'log_iabc_true','log_iabc_noise','log_iabc_adc','log_iabc_filter','log_iabc_meas'}
  assert(isequal(t,s.(name{1}).Time),'测量分析时间轴不一致：%s',name{1});
 end
 truth=teach_values(s.log_iabc_true);noise=teach_values(s.log_iabc_noise);input=teach_values(s.log_iabc_adc);
 measured=teach_values(s.log_iabc_meas);actual=teach_values(s.log_iabc_filter);
 assert(max(abs(input-truth-noise),[],'all')<1e-10,'当前场景仅允许噪声与数字滤波。');
 if k==3
  deterministic=filter(1-alpha,[1 -alpha],truth);component=filter(1-alpha,[1 -alpha],noise);
  assert(max(abs(filter(1-alpha,[1 -alpha],input)-actual),[],'all')<1e-10,'已有滤波递推不匹配。');
 else
  deterministic=truth;component=noise;assert(isequal(input,actual),'滤波关闭时必须旁路。');
 end
 assert(isequal(actual,measured),'本场景的反馈应直接使用滤波选择输出。');
 error=measured-truth;deterministicError=deterministic-truth;
 residual=max(abs(error-deterministicError-component),[],'all');assert(residual<1e-10);
 trace.injected{k}=noise;trace.noise_component{k}=component;trace.deterministic_error{k}=deterministicError;trace.measurement_error{k}=error;
 a.cases(k)=struct('id',plan.cases(k).id,'noise_injected_rms_ABC_A',rmsTail(noise,tail), ...
  'noise_component_rms_ABC_A',rmsTail(component,tail),'deterministic_error_rms_ABC_A',rmsTail(deterministicError,tail), ...
  'measurement_error_rms_ABC_A',rmsTail(error,tail),'decomposition_max_abs_error_A',residual);
end
assert(all(trace.injected{1}==0,'all')&&isequal(trace.injected{2},trace.injected{3}),'噪声组与滤波组必须注入同一序列。');
a.same_injected_sequence=true;a.seed_ABC=plan.comparison_contract.noise_seed+[0 1 2];
n=workspaceValue(plan,'n');polePairs=workspaceValue(plan,'p');hz=n*polePairs/60;
H=(1-alpha)/(1-alpha*exp(-1i*2*pi*hz*dt));
a.nominal_electrical_frequency_Hz=hz;a.nominal_gain_dB=20*log10(abs(H));a.nominal_phase_deg=angle(H)*180/pi;
a.nominal_phase_delay_us=-angle(H)/(2*pi*hz)*1e6;
a.white_noise_rms_ratio_theoretical=sqrt((1-alpha)/(1+alpha));
a.frequency_response_source='由当前离散一阶系数解析计算；不是实测相位或闭环辨识。';
end
function x=rmsTail(values,tail)
x=sqrt(mean(values(tail,:).^2,1));
end
function value=workspaceValue(plan,name)
ix=strcmp({plan.baseline_state.workspace_values.name},name);assert(sum(ix)==1);value=plan.baseline_state.workspace_values(ix).value;
end
