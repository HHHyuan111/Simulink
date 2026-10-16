function path=open_pmsm_sensorless_v2
% Explicit review entry. Refuses to alter an already loaded user model.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);mdl='PMSM_FOC_R2026a';
assert(~bdIsLoaded(mdl),'sensorless:ExistingSession','请在独立MATLAB会话打开v2，避免修改当前查看中的模型。');
for d={'','sensorless','sensorless/robust','sensorless/robust/integration','teaching','control','timing','deadtime','framework','layout/appearance'},addpath(fullfile(modern,d{1}));end
load_system(fullfile(modern,[mdl '.slx']));pmsm_reference('restore');
t=struct('adc_span_A',20,'window_on',false,'interference_s',0);
backup=sensorless_v2_stimulus(mdl,t);set_param(mdl,'SimulationCommand','update');
path=pmsm_sensorless_v2_model('install',mdl,0);data=get_param(path,'UserData');data.v2_stimulus=backup;set_param(path,'UserData',data);
set_param(mdl,'StopTime','.8');open_system(mdl);open_system(path);
fprintf('非理想v2旁路：尚未接管反馈，3us/5us为工程预算；退出用close_pmsm_sensorless_v2。\n');
end
