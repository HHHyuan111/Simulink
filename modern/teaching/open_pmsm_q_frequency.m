function fig=open_pmsm_q_frequency(folder)
if nargin<1,folder=[];end
folder=pmsm_q_frequency_folder(folder);r=verify_pmsm_q_frequency(folder);
fig=openfig(fullfile(folder,'response.fig'),'new','visible');set(fig,'Units','pixels','Position',[80 60 1120 800],...
 'UserData',struct('source_folder',folder,'scope',r.scope,'cases',r.cases));
uimenu(fig,'Text','时域对照','MenuSelectedFcn',@(~,~)open_pmsm_q_frequency_time(folder));
uimenu(fig,'Text','锁轴观测','MenuSelectedFcn',@(~,~)open_pmsm_q_frequency_time(folder,1250,'mechanics'));
menu=uimenu(fig,'Text','实验');uimenu(menu,'Text','重新运行q轴锁轴实验','MenuSelectedFcn',@(~,~)repeat_pmsm_q_frequency);
end
