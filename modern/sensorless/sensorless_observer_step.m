function [s,o]=sensorless_observer_step(s,imeas,vprevious,direction,sample_valid,reset,c)
% N1 pure composition. No model truth, feedback connection or voltage queue.
assert(ismember(direction,[-1 0 1]),'sensorless:Direction','方向仅可为-1/0/1。');
assert(all(isfinite(imeas))&&all(isfinite(vprevious)),'sensorless:Input','输入须有限。');
if reset,s=sensorless_state(c);end
direction_change=s.direction~=0&&direction~=s.direction;
if direction_change,s=sensorless_state(c);reset=true;end
s.direction=direction;
[s.smo,sd]=sensorless_smo_step(s.smo,imeas,vprevious,c,sample_valid,reset);
[s.emf,em]=sensorless_emf_step(s.emf,s.smo.z,s.pll.omega,direction,c,sample_valid,reset);
pll_enable=sample_valid&&direction~=0&&em.magnitude>=c.validity.emf_off_below_V;
[s.pll,pd]=sensorless_pll_step(s.pll,em.vector,c,pll_enable,reset);
if reset||~sample_valid||direction==0
 s.valid=false;s.lock_count=0;s.unlock_count=0;s.history_count=0;s.history_index=1;
 s.residual_history(:)=0;s.phase_history(:)=0;
else
 index=s.history_index;s.residual_history(index)=sum(sd.residual.^2)/2;
 s.phase_history(index)=pd.error^2;
 s.history_index=mod(index,c.window_samples)+1;s.history_count=min(c.window_samples,s.history_count+1);
 enough=s.history_count==c.window_samples;
 residual_ok=sqrt(mean(s.residual_history))<=c.validity.current_residual_vector_rms_max_A;
 phase_ok=sqrt(mean(s.phase_history))<=c.validity.pll_phase_error_rms_max;
 good=enough&&residual_ok&&phase_ok&&~pd.saturated&&em.magnitude>=c.validity.emf_on_min_V;
 bad=~enough||~residual_ok||~phase_ok||pd.saturated||em.magnitude<c.validity.emf_off_below_V;
 if ~s.valid
  if good,s.lock_count=s.lock_count+1;else,s.lock_count=0;end
  if s.lock_count>=c.lock_samples,s.valid=true;s.unlock_count=0;end
 else
  if bad,s.unlock_count=s.unlock_count+1;else,s.unlock_count=0;end
  if s.unlock_count>=c.unlock_samples,s.valid=false;s.lock_count=0;end
 end
end
state=1;if reset,state=0;elseif s.valid,state=2;elseif ~sample_valid||direction==0,state=3;end
o=struct('i_hat',s.smo.i,'residual',sd.residual,'injection',s.smo.z,'emf',s.emf,...
 'theta_raw',em.raw_theta,'phase_correction',em.phase_correction,'theta',pd.theta,...
 'omega_e',pd.omega,'speed_rpm',pd.omega/c.pole_pairs*60/(2*pi),...
 'pll_error',pd.error,'pll_integral',pd.integral,'pll_saturated',pd.saturated,...
 'emf_magnitude',em.magnitude,'valid',s.valid,'state',state);
end
