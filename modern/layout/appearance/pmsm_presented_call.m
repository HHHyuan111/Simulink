function varargout=pmsm_presented_call(fun,varargin)
% GUI experiments use the archived graph, then restore its presentation.
active=pmsm_presentation('installed');
chainActive=pmsm_signal_chain_view('installed');
if chainActive,pmsm_signal_chain_view('remove');end
scopeActive=pmsm_native_scope('installed');
electricalActive=pmsm_electrical_scope('installed');
pwmActive=pmsm_pwm_scope('installed');
samplingActive=pmsm_current_sampling_scope('installed');
observationActive=pmsm_observation_view('installed');
deadtimeActive=pmsm_deadtime_scope('installed');
deadtimeMode=pmsm_deadtime_scope('mode');
if deadtimeActive,pmsm_deadtime_scope('remove');end
if observationActive,pmsm_observation_view('remove');end
if samplingActive,pmsm_current_sampling_scope('remove');end
if pwmActive,pmsm_pwm_scope('remove');end
if electricalActive,pmsm_electrical_scope('remove');end
if scopeActive,pmsm_native_scope('remove');end
if active,pmsm_presentation('remove');end
cleanup=onCleanup(@()finish(active,scopeActive,electricalActive,pwmActive,samplingActive,observationActive,deadtimeActive,deadtimeMode,chainActive));
[varargout{1:nargout}]=fun(varargin{:});
end
function finish(active,scopeActive,electricalActive,pwmActive,samplingActive,observationActive,deadtimeActive,deadtimeMode,chainActive)
if active&&bdIsLoaded('PMSM_FOC_R2026a'),pmsm_presentation('apply');end
if scopeActive&&bdIsLoaded('PMSM_FOC_R2026a'),pmsm_native_scope('install');end
if electricalActive&&bdIsLoaded('PMSM_FOC_R2026a'),pmsm_electrical_scope('install');end
if pwmActive&&bdIsLoaded('PMSM_FOC_R2026a'),pmsm_pwm_scope('install');end
if samplingActive&&bdIsLoaded('PMSM_FOC_R2026a'),pmsm_current_sampling_scope('install');end
if observationActive&&bdIsLoaded('PMSM_FOC_R2026a'),pmsm_observation_view('install');end
if deadtimeActive&&bdIsLoaded('PMSM_FOC_R2026a'),pmsm_deadtime_scope('install','PMSM_FOC_R2026a',deadtimeMode);end
if chainActive&&bdIsLoaded('PMSM_FOC_R2026a'),pmsm_signal_chain_view('apply');end
end
