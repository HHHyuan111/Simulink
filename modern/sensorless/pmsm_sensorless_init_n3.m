function pmsm_sensorless_init_n3(mdl)
% Numerical initialization only. Read-only Mask display is updated beforehand.
% Avoid changing diagram/Mask parameters while Simulink is compiling it.
path=[mdl '/无感观测'];ws=get_param(mdl,'ModelWorkspace');
motor=struct('Rs',getVariable(ws,'Rs'),'Ld',getVariable(ws,'Ld'),'Lq',getVariable(ws,'Lq'),...
 'p',getVariable(ws,'p'),'phis',getVariable(ws,'phis'),'dt',getVariable(ws,'dt'));
keys={'R_hat','L_hat','Kslide_V','boundary_A','emf_filter_hz','pll_fn_hz','pll_zeta','omega_limit_rad_s'};
design=struct;for k=1:numel(keys),design.(keys{k})=str2double(get_param(path,keys{k}));end
c=sensorless_parameters(motor,design);v=c.validity;
assert(c.window_samples==200&&c.lock_samples==400&&c.unlock_samples==100);
numeric=[c.R_hat c.L_hat c.sample_s c.a c.b c.g c.Kslide_V c.boundary_A c.observer_pole...
 c.filter_r c.pll_Kp c.pll_Ki c.omega_limit_rad_s c.pole_pairs...
 v.emf_on_min_V v.emf_off_below_V v.current_residual_vector_rms_max_A v.pll_phase_error_rms_max];
direction=str2double(get_param(path,'direction'));assert(ismember(direction,[-1 0 1]));
period=getVariable(ws,'timing_control_sample');offset=0;if numel(period)>1,offset=period(2);end
h=getVariable(ws,'timing_h');assert(abs(c.sample_s/h-round(c.sample_s/h))<1e-8);
real=getVariable(ws,'timing_on');window=double(strcmp(get_param([mdl '/时序设置'],'window_on'),'on'));
values={numeric,[h c.sample_s offset c.R_hat c.L_hat real],direction,...
 double(strcmp(get_param(path,'enabled'),'on')),[real window]};
names={'sless_cfg','sless_voltage_cfg','sless_direction','sless_enabled','sless_adc_mode'};
for k=1:numel(names),assignin(ws,names{k},values{k});end
end
