% Embedded in InitFcn after the pre-existing teaching initialization.
tim_m=bdroot;tim_ws=get_param(tim_m,'ModelWorkspace');tim_path=[tim_m '/时序设置'];
tim_on=double(strcmp(get_param(tim_path,'real_on'),'on'));
tim_period=getVariable(tim_ws,'dt');tim_speed=getVariable(tim_ws,'teaching_Ts_speed');
tim_trigger=str2double(get_param(tim_path,'trigger_us'))*1e-6;
tim_sync=str2double(get_param(tim_path,'sync_us'))*1e-6;
tim_compute=str2double(get_param(tim_path,'compute_us'))*1e-6;
tim_guard=str2double(get_param(tim_path,'settle_us'))*1e-6;
tim_window=double(strcmp(get_param(tim_path,'window_on'),'on'));
tim_hold=double(strcmp(get_param(tim_path,'invalid_hold_on'),'on'));
tim_mode=double(strcmp(get_param(tim_path,'update_mode'),'仅谷底（对照）'));
tim_h=1e-6;tim_control=tim_period;tim_speed_sample=tim_speed;
tim_static=-1;
tim_carrier=[0 tim_period/2 0];
validateattributes([tim_trigger tim_sync tim_compute tim_guard],{'double'},{'real','finite','nonnegative'});
if tim_on
 assert(strcmp(get_param(tim_path,'pwm_on'),'off'),'真实时序与旧整周期输出延迟不可同时启用。');
 assert(strcmp(get_param([tim_m '/采样设置'],'delay_on'),'off'),'真实时序与旧整周期采样延迟不可同时启用。');
 tim_h=62.5e-9;
 tim_grid_divider=str2double(get_param(tim_path,'grid_divider'));
 validateattributes(tim_grid_divider,{'double'},{'scalar','integer','>=',1,'<=',2});
 % Optional finer grid for convergence checks, still configured explicitly.
 tim_h=tim_h/tim_grid_divider;
 validateattributes(tim_h,{'double'},{'scalar','finite','positive'});
 tim_jeos=tim_trigger+tim_sync+4.5e-6;
 assert(tim_compute>=tim_h,'计算耗时至少为一个事件网格，避免写入读取同拍未完成指令。');
 assert(tim_jeos+tim_compute<tim_period,'本版要求整组转换及计算在同一PWM周期内完成。');
 assert(tim_jeos>0 && tim_jeos<tim_period);
 timing_grid_values=[tim_trigger tim_sync tim_compute tim_guard 1.1875e-6 1.5e-6 tim_period tim_speed];
 assert(all(abs(timing_grid_values/tim_h-round(timing_grid_values/tim_h))<1e-7),'事件时间必须落在62.5ns（或更细）网格上。');
 tim_control=[tim_period tim_jeos];
 tim_static=0;
 tim_speed_sample=[tim_speed tim_jeos+tim_speed-tim_period];
 % Existing comparator is carrier>=threshold; inverted carrier implements PWM1.
 tim_carrier=[tim_period/2 0 tim_period/2];
else
 assert(~tim_window && ~tim_hold,'有效窗口及无效值保持需要先开启真实时序。');
end
assert(~tim_hold || tim_window,'无效值保持需要同时开启低侧采样窗口。');
tim_adc_cfg=[tim_on tim_window tim_hold tim_h tim_period tim_trigger 1.1875e-6 1.5e-6 tim_sync tim_guard tim_speed/tim_period];
tim_pwm_cfg=[tim_on tim_h tim_period tim_trigger 1.1875e-6 1.5e-6 tim_sync tim_compute tim_mode 4000];
tim_names={'timing_on','timing_h','timing_control_sample','timing_speed_sample','timing_carrier_y','timing_adc_cfg','timing_pwm_cfg','timing_static_math'};
tim_vals={tim_on,tim_h,tim_control,tim_speed_sample,tim_carrier,tim_adc_cfg,tim_pwm_cfg,tim_static};
for tim_k=1:numel(tim_names),assignin(tim_ws,tim_names{tim_k},tim_vals{tim_k});end
set_param(tim_m,'FixedStep','timing_h');
