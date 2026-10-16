function s=sensorless_state(c)
% Explicit state; no persistent/global variables or plant state modification.
s.smo=struct('i',zeros(2,1),'z',zeros(2,1));s.emf=zeros(2,1);
s.pll=struct('theta',0,'integral',0,'omega',0);
s.valid=false;s.lock_count=0;s.unlock_count=0;s.history_count=0;s.history_index=1;
s.residual_history=zeros(c.window_samples,1);s.phase_history=zeros(c.window_samples,1);
s.direction=0;
end
