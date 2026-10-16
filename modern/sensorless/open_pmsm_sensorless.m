function open_pmsm_sensorless
% Open the dev model with the temporary sensorless observer layer.
here=fileparts(mfilename('fullpath'));root=fileparts(here);mdl='PMSM_FOC_R2026a';
for section={'','sensorless','teaching','control','timing','deadtime','framework','layout/appearance'}
 addpath(fullfile(root,section{1}));
end
source=fullfile(root,[mdl '.slx']);
if bdIsLoaded(mdl)
 assert(strcmpi(strrep(get_param(mdl,'FileName'),'\','/'),strrep(source,'\','/')), ...
  '当前已打开同名模型的其他副本。请先自行保存并关闭，再打开dev副本。');
end
if ~bdIsLoaded(mdl),load_system(source);pmsm_reference('restore');end
if ~pmsm_sensorless_model('installed',mdl)
 assert(isequaln(pmsm_reference('capture'),pmsm_reference('read')),'请先保留当前设置，并恢复固定参考。');
 pmsm_sensorless_model('install',mdl);
end
open_system(mdl);open_system([mdl '/无感观测'],'force');
end
