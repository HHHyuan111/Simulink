% Open the existing migrated model after licensing recovery and layout review.
cd('D:/simulink/modern');
open_system('D:/simulink/modern/PMSM_FOC_R2026a.slx');
set_param('PMSM_FOC_R2026a','ZoomFactor','FitSystem');
fprintf('GUI_MODEL_OPEN_OK\n');
