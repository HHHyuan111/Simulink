function preview_signal_chain_view
root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'teaching'),fullfile(root,'layout','appearance'));
m='PMSM_FOC_R2026a';assert(~bdIsLoaded(m));load_system(fullfile(root,[m '.slx']));guard=onCleanup(@()close_system(m,0));
raw=teach_snapshot(m);pmsm_presentation('apply');before=teach_snapshot(m);cfg=pmsm_config('read');pmsm_signal_chain_view('apply');
assert(isequaln(cfg,pmsm_config('read')));folder=fullfile(root,'.build','signal_chain');
for name={'采样设置','输出延迟'}
 path=[m '/' name{1}];open_system(path,'force');set_param(path,'ZoomFactor','FitSystem');
 print(['-s' path],'-dpng','-r120',fullfile(folder,[name{1} '.png']));
end
pmsm_signal_chain_view('remove');assert(isequaln(before,teach_snapshot(m)));pmsm_presentation('remove');assert(isequaln(raw,teach_snapshot(m)));disp('SIGNAL_CHAIN_VIEW_PREVIEWED');
end
