function refresh_timing_gui
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);addpath(fullfile(root,'teaching'));
mdl='PMSM_FOC_R2026a';file=fullfile(root,[mdl '.slx']);record=jsondecode(fileread(fullfile(folder,'timing_stage3_results.json')));
assert(record.all_passed&&strcmp(teach_hash(file),record.model_sha256));
assert(~bdIsLoaded(mdl),'Release/backup the old desktop model first.');
open_system(file);set_param(mdl,'ZoomFactor','FitSystem');fprintf('TIMING_GUI_READY %s\n',record.model_sha256);
end
