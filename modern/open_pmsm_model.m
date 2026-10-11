function open_pmsm_model
% Open the current model from this file's directory, independent of checkout path.
folder = fileparts(mfilename('fullpath'));
open_system(fullfile(folder, 'PMSM_FOC_R2026a.slx'));
set_param('PMSM_FOC_R2026a', 'ZoomFactor', 'FitSystem');
end
