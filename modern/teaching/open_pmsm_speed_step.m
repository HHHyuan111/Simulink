function fig=open_pmsm_speed_step(folder,index)
if nargin<1,folder=[];end;if nargin<2,index=1;end
folder=pmsm_speed_step_folder(folder);verify_pmsm_speed_step(folder);
a=load(fullfile(folder,'analysis.mat'),'p');assert(ismember(index,1:numel(a.p.amplitudes_rpm)));
s=load(fullfile(folder,sprintf('step_%d_raw.mat',index)));fig=plot_pmsm_speed_step(s.raw,a.p,a.p.amplitudes_rpm(index));
menu=uimenu(fig,'Text','给定幅值');
uimenu(fig,'Text','频响试测','MenuSelectedFcn',@(~,~)open_pmsm_speed_probe);
for k=1:numel(a.p.amplitudes_rpm),uimenu(menu,'Text',sprintf('%g rpm',a.p.amplitudes_rpm(k)),'MenuSelectedFcn',@(~,~)open_pmsm_speed_step(folder,k));end
end
