function p=pmsm_current_frequency_plan
% Deliberately fixed first lesson: standstill d-axis, frozen reference gains.
state=pmsm_reference('read');vars=state.workspace_values;
% Read the checked-in reference, never the user's current working profile.
if isstruct(vars)&&isfield(vars,'name')
 Ts=vars(strcmp({vars.name},'dt')).value;
else
 error('pmsm:FrequencyReference','无法识别固定参考变量结构。');
end
p=struct('schema',1,'sample_time_s',Ts,'requested_frequency_Hz',[50 100 200 400 600 800 1000 1250 1600 2000 2500 3333 4000],...
 'amplitudes_A',[.2 .1],'settling_cycles',4,'measuring_cycles',8,'minimum_settling_s',.01,'warmup_s',.02,...
 'cases',struct('id',{'reference','delay'},'label',{'原反馈','增加1Ts延迟'},'delay_cycles',{0,1}),...
 'scope','固定参考+实验专用SVPWM周期平均电压适配器；零速、零负载、d轴小信号；q轴和速度环保留；原PI冻结；非实板标定',...
 'injection','原id_ref→d轴误差正端；反馈取同一误差负端；误差取原PI输入；真实id取原电机状态');
p.average_adapter=struct('formula','D=1-2*Tcm/Ts; Vabc=Vdc*(D-mean(D))','common_numerical_delay_s',vars(strcmp({vars.name},'T')).value,...
 'reason','1us switching grid cannot resolve small perturbations; common one-T state breaks algebraic voltage antiwindup feedback; not a hardware delay calibration');
p.samples_per_period=round(1./(Ts*p.requested_frequency_Hz));p.frequency_Hz=1./(Ts*p.samples_per_period);
assert(isscalar(Ts)&&Ts>0&&all(diff(p.frequency_Hz)>0)&&all(p.samples_per_period>=5));
cursor=round(p.warmup_s/Ts);p.segments=struct('start_tick',{},'measure_tick',{},'end_tick',{},'frequency_Hz',{});
for k=1:numel(p.frequency_Hz)
 n=p.samples_per_period(k);settle=max(p.settling_cycles,ceil(p.minimum_settling_s/(n*Ts)))*n;
 p.segments(k)=struct('start_tick',cursor,'measure_tick',cursor+settle,'end_tick',cursor+settle+p.measuring_cycles*n,'frequency_Hz',p.frequency_Hz(k));
 cursor=p.segments(k).end_tick;
end
p.duration_s=cursor*Ts;assert(p.duration_s<2);
end
