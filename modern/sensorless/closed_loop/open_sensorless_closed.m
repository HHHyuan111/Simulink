function open_sensorless_closed
% Open the saved local adaptation. Simulation starts only on the Run button.
here=fileparts(mfilename('fullpath'));addpath(fullfile(fileparts(here),'direct'));base=sensorless_direct_setup;addpath(here);
mdl='PMSM_SMO_ClosedLoop';open_system(fullfile(base,'models','closed_loop',[mdl '.slx']));
open_sensorless_closed_scopes(mdl);
end
