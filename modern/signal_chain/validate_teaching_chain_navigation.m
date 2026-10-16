function report=validate_teaching_chain_navigation
% Exercise real native callbacks and window reuse without running simulation.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'teaching'),fullfile(root,'layout','appearance'));
m='PMSM_FOC_R2026a';assert(~bdIsLoaded(m));load_system(fullfile(root,[m '.slx']));guard=onCleanup(@()close_system(m,0));
mw=get_param(m,'ModelWorkspace');assignin(mw,'n',1234);set_param([m '/采样设置'],'bias_on','on');before=teach_snapshot(m);cfg=pmsm_config('read');
hash=teach_hash(fullfile(root,[m '.slx']));
tags={'PMSMSamplingComparison','PMSMFeedbackEffects_delay','PMSMFeedbackEffects_filter','PMSMTimingFeedback','PMSMDeadtimeComparison'};
labels={'噪声与滤波','采样延迟','数字滤波','PWM更新','死区补偿'};
f=open_pmsm_sampling_comparison;menu=findall(f,'Tag','PMSMTeachingComparisonMenu');items=menu.Children;
assert(isequal(sort({items.Text}),sort(labels)));
for item=items',item.MenuSelectedFcn(item,[]);end
handles=gobjects(1,5);sources=cell(1,5);
for k=1:5
 fig=findall(groot,'Type','figure','Tag',tags{k});assert(isscalar(fig));handles(k)=fig;
 assert(isequal(fig.Position,[80 60 1120 800])&&isequal(fig.Color,[1 1 1]));
 r=fig.UserData;assert(contains(fig.Name,'已保存实验'));
 if isfield(r,'source_folder'),sources{k}={r.source_folder};else,sources{k}=r.source_folders;end
end
fingerprints=cell(1,5);for k=1:5,fingerprints{k}=cellfun(@(p)teach_hash(fullfile(p,'record.json')),sources{k},'UniformOutput',false);end
callbacks=0;
for k=1:5
 menu=findall(handles(k),'Tag','PMSMTeachingComparisonMenu');assert(isscalar(menu));items=menu.Children;
 assert(isequal(sort({items.Text}),sort(labels)));
 for item=items'
  item.MenuSelectedFcn(item,[]);callbacks=callbacks+1;
  for j=1:5,fig=findall(groot,'Type','figure','Tag',tags{j});assert(isscalar(fig)&&fig==handles(j),'主题切换新建了重复图窗。');end
 end
end
assert(isempty(findall(groot,'Type','figure','Name','对比未打开')));
for k=1:5
 current=cellfun(@(p)teach_hash(fullfile(p,'record.json')),sources{k},'UniformOutput',false);assert(isequal(current,fingerprints{k}));
end
panel=open_pmsm_sampling_lesson;b=findall(panel,'Tag','sampling_lesson_compare');assert(isscalar(b)&&strcmp(b.Text,'内置示例'));delete(panel);
assert(isequaln(before,teach_snapshot(m))&&isequaln(cfg,pmsm_config('read'))&&getVariable(mw,'n')==1234);
assert(strcmp(hash,teach_hash(fullfile(root,[m '.slx']))));delete(handles);
report=struct('passed',true,'topics',{labels},'cross_topic_callbacks',callbacks,'one_window_per_topic',true,'configuration_preserved',true,'archives_read_only',true,'model_sha256',hash,'source_folders',{sources});
target=fullfile(root,'signal_chain','teaching_chain');if ~isfolder(target),mkdir(target);end
teach_writejson(fullfile(target,'navigation_validation.json'),report);disp('TEACHING_CHAIN_NAVIGATION_VALIDATED');
end
