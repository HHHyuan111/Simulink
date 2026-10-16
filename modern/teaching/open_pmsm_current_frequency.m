function fig=open_pmsm_current_frequency(folder)
if nargin<1,folder=[];end
folder=pmsm_current_frequency_folder(folder);
r=verify_pmsm_current_frequency(folder);
fig=openfig(fullfile(folder,'response.fig'),'new','visible');set(fig,'Units','pixels','Position',[80 60 1120 800],...
 'UserData',struct('source_folder',folder,'scope',r.scope,'cases',r.cases));
uimenu(fig,'Text','时域对照','MenuSelectedFcn',@(~,~)open_pmsm_current_frequency_time(folder));
menu=uimenu(fig,'Text','实验');uimenu(menu,'Text','重新运行固定参考实验','MenuSelectedFcn',@(~,~)repeat_pmsm_current_frequency);
end
