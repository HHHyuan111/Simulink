function p=pmsm_speed_probe_plan
p=struct('amplitudes_rpm',[10 5],'sample_time_s',50e-6,'speed_task_s',100e-6,'analysis_sample_time_s',100e-6,...
 'requested_frequency_Hz',[20 80 250],'settling_cycles',2,'minimum_settling_s',.1,'measuring_cycles',4,...
 'scope','零负载、零速附近自由转子；原速度PI与电流内环；SVPWM周期平均电压，共同1us数值保持；三点试测，非完整带宽/裕度验收');
p.samples_per_period=2*round(1./(p.speed_task_s*p.requested_frequency_Hz));
p.frequency_Hz=1./(p.sample_time_s*p.samples_per_period);cursor=round(.02/p.sample_time_s);
p.segments=struct('start_tick',{},'measure_tick',{},'end_tick',{},'frequency_Hz',{});
for k=1:numel(p.frequency_Hz)
 n=p.samples_per_period(k);wait=max(p.settling_cycles,ceil(p.minimum_settling_s/(n*p.sample_time_s)))*n;
 p.segments(k)=struct('start_tick',cursor,'measure_tick',cursor+wait,'end_tick',cursor+wait+p.measuring_cycles*n,'frequency_Hz',p.frequency_Hz(k));
 cursor=p.segments(k).end_tick;
end
p.duration_s=cursor*p.sample_time_s;
end
