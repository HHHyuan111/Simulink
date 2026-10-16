function c=sensorless_robust_config(overrides)
% Engineering assumptions only. Kept separate from plant injection values.
here=fileparts(mfilename('fullpath'));
contract=jsondecode(fileread(fullfile(fileparts(here),'contracts','nonideal_v2.json')));p=contract.engineering_profile;
c=p.clock;
c.observer_exec_s=p.execution.observer_s;c.foc_exec_s=p.execution.foc_s;c.guard_s=p.execution.guard_s;
c.maximum_state_age_s=p.execution.maximum_state_age_s;
c.maximum_apply_prediction_s=p.execution.maximum_apply_prediction_s;
c.deadtime_hat_s=p.observer_estimates.deadtime_s;c.Ron_hat_ohm=p.observer_estimates.Ron_ohm;
c.Vf_hat_V=p.observer_estimates.Vf_V;c.zero_current_A=p.observer_estimates.zero_current_band_A;
c.zero_sequence_max_A=p.observer_estimates.zero_sequence_max_A;
c.pole_pairs=p.observer_estimates.pole_pairs;c.omega_limit_rad_s=p.observer_estimates.omega_limit_rad_s;
if nargin>0
 for key=fieldnames(overrides)'
  assert(isfield(c,key{1}),'sensorless:RobustParameter','Unknown robust parameter.');c.(key{1})=overrides.(key{1});
 end
end
for key=fieldnames(c)'
 value=c.(key{1});assert(isa(value,'double')&&isscalar(value)&&isreal(value)&&isfinite(value)&&value>=0,...
  'sensorless:RobustParameter','Parameters must be finite nonnegative scalar doubles.');
end
assert(c.h_s>0&&c.period_s>0&&c.speed_period_s>0&&c.adc_aperture_s>0&&c.adc_rank_s>=c.adc_aperture_s);
assert(c.observer_exec_s>0&&c.foc_exec_s>0&&c.maximum_state_age_s>0&&c.maximum_apply_prediction_s>0);
assert(c.zero_current_A>0&&c.zero_sequence_max_A>0&&c.omega_limit_rad_s>0);
assert(c.pole_pairs>=1&&c.pole_pairs==floor(c.pole_pairs)&&ismember(c.update_mode,[0 1]));
for value=[c.period_s c.speed_period_s c.adc_trigger_s c.adc_aperture_s c.adc_rank_s c.adc_sync_s]
 assert(abs(value/c.h_s-round(value/c.h_s))<1e-7,'sensorless:RobustGrid','Physical events must lie on the native grid.');
end
N=round(c.period_s/c.h_s);assert(mod(N,2)==0&&mod(round(c.speed_period_s/c.h_s),N)==0);
assert(c.adc_trigger_s+c.adc_sync_s+3*c.adc_rank_s<c.period_s);
end
