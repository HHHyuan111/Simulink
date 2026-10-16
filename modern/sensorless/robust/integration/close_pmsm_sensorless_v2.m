function close_pmsm_sensorless_v2
mdl='PMSM_FOC_R2026a';path=[mdl '/无感观测'];
assert(bdIsLoaded(mdl)&&strcmp(get_param(mdl,'SimulationStatus'),'stopped'));
data=get_param(path,'UserData');assert(isfield(data,'v2_stimulus'));
pmsm_sensorless_v2_model('remove',mdl);sensorless_n3_restore(mdl,data.v2_stimulus);
fprintf('已撤下v2观测层并恢复配置，未保存原SLX。\n');
end
