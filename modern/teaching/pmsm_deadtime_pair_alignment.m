function [aligned,info]=pmsm_deadtime_pair_alignment(outputs,plan)
% Select the same completed rotor electrical cycle; keep original samples.
assert(ismember(plan.scenario.id,{'gate_deadtime_pair','low_speed_compensation'}));
n=numel(outputs);theta=cell(1,n);current=cell(1,n);time=cell(1,n);
for k=1:n
 s=outputs{k};assert(isequal(s.log_theta_true.Time,s.obs_current_fast.Time),'真实角度与电流必须同拍记录。');
 time{k}=s.obs_current_fast.Time;theta{k}=unwrap(teach_values(s.log_theta_true));current{k}=teach_values(s.obs_current_fast);
 assert(size(theta{k},2)==1&&size(current{k},2)==3);
end
cycle=min(cellfun(@(x)floor(x(end)/(2*pi)),theta))-1;
assert(cycle>=0,'尚无共同的完整电角周期，请延长仿真。');
aligned=struct('angle_deg',{},'current_ABC_A',{},'time_s',{});
info=struct('schema',1,'cycle_index',cycle,'absolute_angle_start_rad',2*pi*cycle,'absolute_angle_end_rad',2*pi*(cycle+1), ...
 'method','按真实转子电角度选择同一完整周期；未按电流峰值平移、未平滑、未插值重采样。', ...
 'cases',struct('id',{},'time_window_s',{},'sample_count',{},'angle_window_deg',{},'current_sample_rms_ABC_A',{}));
for k=1:n
 ix=theta{k}>=2*pi*cycle & theta{k}<2*pi*(cycle+1);angle=(theta{k}(ix)-2*pi*cycle)*180/pi;
 assert(numel(angle)>=80&&all(diff(angle)>0),'选定电角周期必须单向完整通过。');
 dt=median(diff(time{k}));assert(angle(1)<rad2deg(2*pi*1000*dt)&&angle(end)>359,'角周期边界不完整。');
 aligned(k)=struct('angle_deg',angle,'current_ABC_A',current{k}(ix,:),'time_s',time{k}(ix));
 info.cases(k)=struct('id',plan.cases(k).id,'time_window_s',[aligned(k).time_s(1) aligned(k).time_s(end)], ...
  'sample_count',sum(ix),'angle_window_deg',[angle(1) angle(end)],'current_sample_rms_ABC_A',sqrt(mean(current{k}(ix,:).^2,1)));
end
end
