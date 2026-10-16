function c=sensorless_parameters(motor,design)
% Pure parameter calculation. Does not change the plant or load a model.
here=fileparts(mfilename('fullpath'));
if nargin<1||isempty(motor)
 inventory=jsondecode(fileread(fullfile(here,'baseline','n0_inventory.json')));
 motor=inventory.motor_and_tasks;
end
plan=jsondecode(fileread(fullfile(here,'contracts','test_plan_v1.json')));
contract=jsondecode(fileread(fullfile(here,'contracts','acceptance_v1.json')));
c=plan.smo_nominal_seed;c.R_hat=motor.Rs;c.L_hat=motor.Ld;
c.pole_pairs=motor.p;c.flux_hat=motor.phis;c.sample_s=motor.dt;
c.omega_limit_rad_s=2000;
% Physical voltage input is RL-weighted over the preceding interval.
c.interval_convention='rl_weighted_rotating';
if nargin>=2
 allowed={'R_hat','L_hat','pole_pairs','flux_hat','sample_s','Kslide_V','boundary_A',...
  'emf_filter_hz','pll_fn_hz','pll_zeta','omega_limit_rad_s','interval_convention'};
 for key=fieldnames(design)'
  assert(ismember(key{1},allowed),'sensorless:UnknownParameter','未知参数：%s',key{1});
  c.(key{1})=design.(key{1});
 end
end
assert(isfield(motor,'Lq')&&isfinite(motor.Lq)&&motor.Lq>0&&motor.Ld==motor.Lq,...
 'sensorless:Saliency','首版仅接受正电感且Ld=Lq的SPMSM。');
for key={'R_hat','L_hat','pole_pairs','flux_hat','sample_s','Kslide_V','boundary_A',...
 'emf_filter_hz','pll_fn_hz','pll_zeta','omega_limit_rad_s'}
 validateattributes(c.(key{1}),{'double'},{'scalar','real','finite','positive'},mfilename,key{1});
end
assert(c.pole_pairs==floor(c.pole_pairs),'sensorless:PolePairs','极对数须为正整数。');
assert(c.sample_s==contract.invariants.observer_period_s,'sensorless:Period','首版观测器执行周期固定50us。');
assert(c.emf_filter_hz<.5/c.sample_s&&c.pll_fn_hz<.5/c.sample_s,'sensorless:Frequency','频率须低于奈奎斯特频率。');
assert(ismember(c.interval_convention,{'left_zoh','rl_weighted_rotating'}),'sensorless:Interval','未知区间定义。');
c.a=exp(-c.R_hat*c.sample_s/c.L_hat);
c.b=-expm1(-c.R_hat*c.sample_s/c.L_hat)/c.R_hat;
c.g=c.Kslide_V/c.boundary_A;c.observer_pole=c.a/(1+c.b*c.g);
c.filter_r=exp(-2*pi*c.emf_filter_hz*c.sample_s);
c.pll_Kp=2*c.pll_zeta*2*pi*c.pll_fn_hz;c.pll_Ki=(2*pi*c.pll_fn_hz)^2;
% Error-state matrix for integrate-I, calculate-omega, then predict-theta.
c.pll_error_matrix=[1-c.sample_s*c.pll_Kp-c.sample_s^2*c.pll_Ki,-c.sample_s;...
 c.sample_s*c.pll_Ki,1];
poles=eig(c.pll_error_matrix);c.pll_poles_real_imag=[real(poles),imag(poles)];c.pll_spectral_radius=max(abs(poles));
assert(c.observer_pole<1&&c.filter_r<1&&c.pll_spectral_radius<1,...
 'sensorless:DiscreteStability','局部离散极点不在单位圆内。');
c.validity=contract.validity;c.window_samples=round(c.validity.window_s/c.sample_s);
c.lock_samples=round(c.validity.lock_continuous_s/c.sample_s);
c.unlock_samples=round(c.validity.unlock_continuous_s/c.sample_s);
assert(c.window_samples*c.sample_s==c.validity.window_s&&c.lock_samples*c.sample_s==c.validity.lock_continuous_s);
c.emf_at_3000rpm_V=c.flux_hat*c.pole_pairs*3000*2*pi/60;
end
