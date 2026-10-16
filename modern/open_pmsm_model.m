function open_pmsm_model
% Open the current model from this file's directory, independent of checkout path.
folder = fileparts(mfilename('fullpath'));
addpath(fullfile(folder,'layout','appearance'));
addpath(fullfile(folder,'teaching'));
open_system(fullfile(folder, 'PMSM_FOC_R2026a.slx'));
pmsm_presentation('apply');
pmsm_native_scope('install');
pmsm_electrical_scope('install');
pmsm_pwm_scope('install');
refresh_pmsm_observation_shortcuts;
pmsm_signal_chain_view('apply');
set_param('PMSM_FOC_R2026a', 'ZoomFactor', 'FitSystem');
end
