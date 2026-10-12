function timing=observation_timing(values,settings)
% Resolve execution periods separately from logging periods.
index=find(strcmp({settings.block},'时序设置'));params=settings(index).parameters;
speed=values.Ts_speed;
if strcmp(params(strcmp({params.name},'speed_on')).value,'on')
 speed=values.dt*str2double(params(strcmp({params.name},'speed_divider')).value);
end
timing=struct('current_execution_period_s',values.dt,'speed_execution_period_s',speed, ...
 'pwm_period_s',values.Ts,'power_current_hold_period_s',values.Ts,'numerical_step_s',values.T);
timing.real_event_mode=false;
idx=find(strcmp({params.name},'real_on'));
if ~isempty(idx)&&strcmp(params(idx).value,'on')
 getp=@(name)params(strcmp({params.name},name)).value;
 jeos=(str2double(getp('trigger_us'))+str2double(getp('sync_us')))*1e-6+4.5e-6;
 timing.real_event_mode=true;
 timing.numerical_step_s=62.5e-9/str2double(getp('grid_divider'));
 timing.current_execution_offset_s=jeos;
 timing.speed_execution_offset_s=jeos+speed-values.dt;
 timing.ccr_write_offset_s=jeos+str2double(getp('compute_us'))*1e-6;
 timing.pwm_update_opportunity_period_s=values.Ts/2;
 if strcmp(getp('update_mode'),'仅谷底（对照）'),timing.pwm_update_opportunity_period_s=values.Ts;end
 timing.trigger_phase_measured=false;
end
end
