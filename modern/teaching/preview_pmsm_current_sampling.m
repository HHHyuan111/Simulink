function [out,provenance,metrics]=preview_pmsm_current_sampling
% Short native-Scope demonstration using current motor/control parameters.
teach=fileparts(mfilename('fullpath'));root=fileparts(teach);
addpath(root,teach,fullfile(root,'layout','appearance'));
open_pmsm_current_sampling_scope;mdl='PMSM_FOC_R2026a';before=pmsm_config('read');
overrides={'时序设置','real_on','on';'时序设置','pwm_on','off'; ...
 '采样设置','adc_on','on';'采样设置','delay_on','off'};
in=Simulink.SimulationInput(mdl);in=in.setModelParameter('StopTime','.02');
for k=1:size(overrides,1)
 in=in.setBlockParameter([mdl '/' overrides{k,1}],overrides{k,2},overrides{k,3});
end
out=sim(in);open_pmsm_current_sampling_scope;
assert(isequaln(before,pmsm_config('read')),'演示改变了用户参数');
provenance=struct('configuration',before,'block_overrides',{overrides},'stop_time_seconds',.02, ...
 'created_at',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), ...
 'model_sha256',teach_hash(get_param(mdl,'FileName')),'matlab_version',version, ...
 'preview_source_sha256',teach_hash([mfilename('fullpath') '.m']), ...
 'scope','Current-parameter startup demonstration, not a frozen steady-state comparison.');
metrics=pmsm_current_sampling_metrics(out);
cache=fullfile(root,'.build');if ~isfolder(cache),mkdir(cache);end
save(fullfile(cache,'current_sampling_metrics.mat'),'metrics','provenance');
teach_writejson(fullfile(cache,'current_sampling_metrics.json'),struct('metrics',metrics,'provenance',provenance));
end
