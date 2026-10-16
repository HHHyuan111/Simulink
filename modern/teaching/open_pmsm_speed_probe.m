function fig=open_pmsm_speed_probe(folder)
if nargin<1,folder=[];end
folder=pmsm_speed_probe_folder(folder);verify_pmsm_speed_probe(folder);a=load(fullfile(folder,'analysis.mat'));
fig=plot_pmsm_speed_probe(a.p,a.responses);menu=uimenu(fig,'Text','时域对照');
for k=1:numel(a.p.frequency_Hz)
 uimenu(menu,'Text',sprintf('%g Hz',a.p.frequency_Hz(k)),'MenuSelectedFcn',@(~,~)open_pmsm_speed_probe_time(folder,k));
end
end
