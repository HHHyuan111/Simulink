function report=validate_feedback_effects_view
root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'teaching'));
m='PMSM_FOC_R2026a';assert(~bdIsLoaded(m));load_system(fullfile(root,[m '.slx']));guard=onCleanup(@()close_system(m,0));
mw=get_param(m,'ModelWorkspace');assignin(mw,'n',1234);set_param([m '/采样设置'],'bias_on','on');
before=teach_snapshot(m);cfg=pmsm_config('read');hash=teach_hash(fullfile(root,[m '.slx']));
target=fullfile(root,'signal_chain','feedback_effects');if ~isfolder(target),mkdir(target);end
checks=0;reports=cell(1,2);kinds={'delay','filter'};
for topic=1:2
 [f,r]=open_pmsm_feedback_effects(kinds{topic});reports{topic}=r;
 assert(isequal(f.Color,[1 1 1])&&isequal(f.Position,[80 60 1120 800]));
 a=load(fullfile(r.source_folders{2},'reference.mat'),'signals');b=load(fullfile(r.source_folders{1},'factor.mat'),'signals');c=load(fullfile(r.source_folders{2},'factor.mat'),'signals');outputs={a.signals,b.signals,c.signals};
 s=outputs{3};t=s.obs_current_fast.Time;ix=t>=.18&t<=.2;v=teach_values(s.obs_current_fast);check('effect_A_true',t(ix)*1000,v(ix,1));
 t=s.log_iabc_meas.Time;ix=t>=.18&t<=.2;v=teach_values(s.log_iabc_meas);check('effect_A_measured',t(ix)*1000,v(ix,1));
 for panel=2:6
  for group=1:3
   s=outputs{group};t=s.log_Te.Time;ix=t>=.18&t<=.2;state=teach_values(s.obs_state);
   switch panel
    case 2,y=state(:,1);
    case 3,y=state(:,2)-teach_values(s.log_iq_ref);
    case 4,y=teach_values(s.log_iabc_meas)-teach_values(s.log_iabc_true);y=y(:,1);
    case 5,y=teach_values(s.log_Te);
    case 6,y=teach_values(s.log_speed);
   end
   check(sprintf('effect_display_%d_case_%d',panel,group),t(ix)*1000,y(ix));
  end
 end
 for panel=[2 5 6]
  fields={'obs_id_ref','log_TL','log_nref'};slot=find([2 5 6]==panel);y=teach_values(outputs{1}.(fields{slot}));check(sprintf('effect_reference_%d',panel),t(ix)*1000,y(ix));
 end
 ln=findobj(f,'Tag','effect_A_true');ln.Parent.XLim=[185 190];drawnow;
 for panel=2:6,ln=findobj(f,'Tag',sprintf('effect_display_%d_case_1',panel));assert(isequal(ln.Parent.XLim,[185 190]));end
 ln.Parent.XLim=[180 200];
 menu=findall(f,'Type','uimenu','Text','指标与工况');menu.MenuSelectedFcn(menu,[]);
 info=findall(groot,'Type','figure','Name','采样因素指标 · 已保存实验');assert(isscalar(info));tab=findall(info,'Type','uitable');assert(isequal(size(tab.Data),[3 4]));delete(info);
 exportgraphics(f,fullfile(target,[kinds{topic} '.png']),'Resolution',140);
 savefig(f,fullfile(target,[kinds{topic} '.fig']));delete(f);
end
assert(checks==40);
f=open_pmsm_sampling_comparison;menu=findall(f,'Tag','PMSMTeachingComparisonMenu');assert(isscalar(menu));items=menu.Children;assert(numel(items)==5);
for item=items'
 item.MenuSelectedFcn(item,[]);
end
assert(~isempty(findall(groot,'Tag','PMSMFeedbackEffects_delay'))&&~isempty(findall(groot,'Tag','PMSMFeedbackEffects_filter')));
assert(~isempty(findall(groot,'Tag','PMSMTimingFeedback')));
assert(~isempty(findall(groot,'Tag','PMSMDeadtimeComparison')));
assert(isempty(findall(groot,'Type','figure','Name','对比未打开')));close all force;
assert(isequaln(before,teach_snapshot(m))&&isequaln(cfg,pmsm_config('read'))&&getVariable(mw,'n')==1234);
assert(strcmp(hash,teach_hash(fullfile(root,[m '.slx']))));
for topic=1:2
 r=reports{topic};for source=1:2,assert(strcmp(r.source_record_sha256{source},teach_hash(fullfile(r.source_folders{source},'record.json'))));end
end
report=struct('passed',true,'raw_exact_curves',checks,'time_axes_linked',true,'metrics_table_checked',true,'native_menu_callbacks',5,'configuration_preserved',true,'model_sha256',hash,'topics',{reports});
teach_writejson(fullfile(target,'validation.json'),report);disp('FEEDBACK_EFFECTS_VIEW_VALIDATED');
 function check(tag,x,y)
  ln=findobj(f,'Tag',tag);assert(isscalar(ln)&&isequaln(ln.XData(:),x(:))&&isequaln(ln.YData(:),y(:)),'曲线不符：%s',tag);checks=checks+1;
 end
end
