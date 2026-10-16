function close_pmsm_startup
% Restore the fixed reference after a manually opened startup demonstration.
here=fileparts(mfilename('fullpath'));root=fileparts(here);addpath(here,fullfile(root,'teaching'),fullfile(root,'framework'),fullfile(root,'layout','appearance'));
pmsm_presented_call(@restore);
end
function restore
mdl='PMSM_FOC_R2026a';assert(strcmp(get_param(mdl,'SimulationStatus'),'stopped'),'先停止仿真。');
scope=[mdl '/启停/启停观测'];if getSimulinkBlockHandle(scope)>0,close_system(scope);drawnow;end
if pmsm_startup_model('installed'),pmsm_startup_model('remove');end
if pmsm_system_inputs('installed',mdl),pmsm_system_inputs('remove',mdl);end
if pmsm_encoder_model('installed'),pmsm_encoder_model('remove');end
pmsm_reference('restore');
end
