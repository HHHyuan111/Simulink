function [s,valid,state]=sensorless_validity_step(s,residual,phase_error,emf,saturated,sample_valid,direction,reset,c)
%#codegen
% Same frozen validity semantics as the N1 pure observer composition.
if reset||~sample_valid||direction==0
 s.valid=false;s.lock_count=0;s.unlock_count=0;s.history_count=0;s.history_index=1;
 s.residual_history(:)=0;s.phase_history(:)=0;
else
 index=s.history_index;s.residual_history(index)=sum(residual.^2)/2;s.phase_history(index)=phase_error^2;
 s.history_index=mod(index,c.window_samples)+1;s.history_count=min(c.window_samples,s.history_count+1);
 enough=s.history_count==c.window_samples;
 residual_ok=sqrt(mean(s.residual_history))<=c.validity.current_residual_vector_rms_max_A;
 phase_ok=sqrt(mean(s.phase_history))<=c.validity.pll_phase_error_rms_max;
 good=enough&&residual_ok&&phase_ok&&~saturated&&emf>=c.validity.emf_on_min_V;
 bad=~enough||~residual_ok||~phase_ok||saturated||emf<c.validity.emf_off_below_V;
 if ~s.valid
  if good,s.lock_count=s.lock_count+1;else,s.lock_count=0;end
  if s.lock_count>=c.lock_samples,s.valid=true;s.unlock_count=0;end
 else
  if bad,s.unlock_count=s.unlock_count+1;else,s.unlock_count=0;end
  if s.unlock_count>=c.unlock_samples,s.valid=false;s.lock_count=0;end
 end
end
valid=s.valid;state=1;
if reset,state=0;elseif valid,state=2;elseif ~sample_valid||direction==0,state=3;end
end
