function report=validate_signal_chain_ui
root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'teaching'),fullfile(root,'layout','appearance'));
m='PMSM_FOC_R2026a';assert(~bdIsLoaded(m));load_system(fullfile(root,[m '.slx']));guard=onCleanup(@()close_system(m,0));
mw=get_param(m,'ModelWorkspace');assignin(mw,'n',1234);set_param([m '/采样设置'],'adc_span','3','adc_bits','9');
cfg=pmsm_config('read');code=mw.MATLABCode;before=teach_snapshot(m);hash=teach_hash(fullfile(root,[m '.slx']));
open_pmsm_model;assert(pmsm_signal_chain_view('installed'));
f=open_pmsm_controls('采样设置');table=findall(f,'Type','uitable');assert(isscalar(table));
ix=find(strcmp(table.Data(:,1),'ADC双极量程 ± [A]'));assert(isscalar(ix)&&strcmp(table.Data{ix,2},'3')&&strcmp(table.Data{ix,3},'A，单侧幅值'));
button=findall(f,'Type','uibutton','Text','展开模块');button.ButtonPushedFcn(button,[]);
assert(pmsm_signal_chain_view('installed')&&isequaln(cfg,pmsm_config('read'))&&strcmp(code,mw.MATLABCode));
exportapp(f,fullfile(root,'.build','signal_chain','settings.png'));delete(f);
open_pmsm_current_sampling_scope;pmsm_deadtime_scope('install',m,'effects');
r=rebuild_pmsm_observations;assert(r.user_configuration_preserved&&pmsm_signal_chain_view('installed'));
assert(pmsm_current_sampling_scope('installed')&&strcmp(pmsm_deadtime_scope('mode'),'effects'));
pmsm_presented_call(@checkRemoved);assert(pmsm_signal_chain_view('installed'));
try,pmsm_presented_call(@()error('pmsm:ChainUI','intentional'));catch err,assert(strcmp(err.identifier,'pmsm:ChainUI'));end
assert(pmsm_signal_chain_view('installed')&&isequaln(cfg,pmsm_config('read'))&&strcmp(code,mw.MATLABCode));
for name={'采样设置','输出延迟'}
 path=[m '/' name{1}];open_system(path,'force');set_param(path,'ZoomFactor','FitSystem');
 print(['-s' path],'-dpng','-r120',fullfile(root,'signal_chain',[name{1} '.png']));
end
pmsm_signal_chain_view('remove');pmsm_deadtime_scope('remove');pmsm_observation_view('remove');
pmsm_current_sampling_scope('remove');pmsm_pwm_scope('remove');pmsm_electrical_scope('remove');pmsm_native_scope('remove');pmsm_presentation('remove');
assert(isequaln(before,teach_snapshot(m))&&isequaln(cfg,pmsm_config('read'))&&strcmp(code,mw.MATLABCode)&&getVariable(mw,'n')==1234);
assert(strcmp(hash,teach_hash(fullfile(root,[m '.slx']))));
report=struct('passed',true,'custom_parameter_preserved',true,'adc_range_label_correct',true,...
 'open_expand_current_scope',true,'rebuild_preserves_all_layers',true,'wrapper_normal_exception_restore',true,...
 'original_graph_restored',true,'model_sha256',hash);
teach_writejson(fullfile(root,'signal_chain','ui_validation.json'),report);disp('SIGNAL_CHAIN_UI_VALIDATED');
 function checkRemoved
  assert(~pmsm_signal_chain_view('installed')&&~pmsm_current_sampling_scope('installed')&&~pmsm_deadtime_scope('installed'));
 end
end
