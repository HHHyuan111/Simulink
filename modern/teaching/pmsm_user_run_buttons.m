function note=pmsm_user_run_buttons(grid,topic)
% Append two simple manual actions to an existing teaching panel.
uibutton(grid,'Text','保留本次运行','FontSize',18,'Tag',['user_keep_' topic],'Tooltip','保留工作区最近一次out到本主题的原生数据检查器记录；重复点击不重复保留。','ButtonPushedFcn',@(~,~)act('keep',topic,grid));
uibutton(grid,'Text','对比我的运行','FontSize',18,'Tag',['user_compare_' topic],'Tooltip','原生数据检查器同轴显示本主题最近两次已保留记录；只有一次时显示一次。','ButtonPushedFcn',@(~,~)act('compare',topic,grid));
note=uilabel(grid,'Text','先运行并保留，再改参数重跑；对比最近两次保留结果。','FontSize',15,'Tag',['user_run_note_' topic]);
end
function act(action,topic,grid)
try
 result=pmsm_user_runs(action,topic);note=findall(grid,'Tag',['user_run_note_' topic]);
 if strcmp(action,'keep'),note.Text=['已保留：' result.name];
 elseif numel(result)==1,note.Text=['已显示：' result.name '；再保留一次可对比。'];
 else,note.Text=['对比：' result(1).name '（蓝） / ' result(2).name '（红）'];end
catch err,uialert(ancestor(grid,'figure'),err.message,'运行记录');end
end
