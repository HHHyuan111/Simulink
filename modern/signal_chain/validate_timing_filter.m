function report=validate_timing_filter
root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'teaching'));
[outputs,r]=timing_filter_data;m='PMSM_FOC_R2026a';assert(~bdIsLoaded(m));load_system(fullfile(root,[m '.slx']));guard=onCleanup(@()close_system(m,0));pmsm_reference('restore');base=pmsm_config('read');referenceState=pmsm_reference('capture');
skip={'obs_current_fast','obs_dead_requested','obs_dead_gates','obs_adc_timing','obs_pwm_timing','log_Tcm_applied'};prefixChecks=0;
for k=1:4
 fprintf('FACTORIAL_PREFIX %d\n',k);in=Simulink.SimulationInput(m);in=in.setModelParameter('StopTime','.002');c=r.configurations{k};
 for j=1:numel(c.rows)
  assert(strcmp(c.rows(j).key,base.rows(j).key)&&strcmp(c.rows(j).section,base.rows(j).section));
  if ~strcmp(c.rows(j).value,base.rows(j).value)
   assert(~ismember(c.rows(j).section,{'电机与工况','负载'}));in=in.setBlockParameter([m '/' c.rows(j).section],c.rows(j).key,c.rows(j).value);
  end
 end
 short=sim(in);
 for field=setdiff(fieldnames(outputs{k}),skip)'
  s=outputs{k}.(field{1});q=short.get(field{1});keep=s.Time>=q.Time(1)&s.Time<=q.Time(end);v=teach_values(s);w=teach_values(q);
  assert(isequaln(s.Time(keep),q.Time)&&isequaln(v(keep,:),w),'短时复现失败：%d/%s',k,field{1});prefixChecks=prefixChecks+1;
 end
end
assert(prefixChecks==72);
pmsm_reference('restore');assert(isequaln(referenceState,pmsm_reference('capture')),'派生工作区未完整恢复。');
mw=get_param(m,'ModelWorkspace');assignin(mw,'n',1234);set_param([m '/采样设置'],'bias_on','on');before=teach_snapshot(m);cfg=pmsm_config('read');
[f,r2]=open_pmsm_timing_filter;assert(isequaln(r,r2));assert(isequal(f.Color,[1 1 1])&&isequal(f.Position,[80 60 1120 800]));checks=0;errors=cell(1,4);
for k=1:4
 s=outputs{k};t=s.log_Te.Time;ix=t>=.18&t<=.2;state=teach_values(s.obs_state);errors{k}=state(:,2)-teach_values(s.log_iq_ref);
 for panel=1:5
  switch panel
   case 1,y=teach_values(s.log_iabc_meas)-teach_values(s.log_iabc_true);y=y(:,1);
   case 2,y=state(:,1);
   case 3,y=errors{k};
   case 4,y=teach_values(s.log_Te);
   case 5,y=teach_values(s.log_speed);
  end
  check_curve(f,sprintf('factorial_panel_%d_case_%d',panel,k),t(ix)*1000,y(ix));checks=checks+1;
 end
end
for panel=[2 4 5],fields={'obs_id_ref','log_TL','log_nref'};slot=find([2 4 5]==panel);y=teach_values(outputs{1}.(fields{slot}));check_curve(f,sprintf('factorial_reference_%d',panel),t(ix)*1000,y(ix));checks=checks+1;end
for k=1:2,y=errors{k+2}-errors{k};check_curve(f,sprintf('factorial_increment_%d',k),t(ix)*1000,y(ix));checks=checks+1;end
assert(checks==25);
ln=findobj(f,'Tag','factorial_panel_1_case_1');ln.Parent.XLim=[185 190];drawnow;
for panel=2:5,ln=findobj(f,'Tag',sprintf('factorial_panel_%d_case_1',panel));assert(isequal(ln.Parent.XLim,[185 190]));end
ln=findobj(f,'Tag','factorial_increment_1');assert(isequal(ln.Parent.XLim,[185 190]));ln.Parent.XLim=[180 200];
menu=findall(f,'Type','uimenu','Text','指标与工况');menu.MenuSelectedFcn(menu,[]);info=findall(groot,'Type','figure','Name','滤波与时序指标 · 已保存实验');assert(isscalar(info));table=findall(info,'Type','uitable');assert(isequal(size(table.Data),[6 5]));delete(info);
target=fullfile(root,'signal_chain','timing_filter');exportgraphics(f,fullfile(target,'comparison.png'),'Resolution',140);savefig(f,fullfile(target,'comparison.fig'));delete(f);
% Reach the combination figure from the existing PWM topic; repeated clicks reuse it.
parent=open_pmsm_timing_feedback;menu=findall(parent,'Tag','PMSMTimingFilterEntry');assert(isscalar(menu));menu.MenuSelectedFcn(menu,[]);first=findall(groot,'Tag','PMSMTimingFilter');assert(isscalar(first));menu.MenuSelectedFcn(menu,[]);second=findall(groot,'Tag','PMSMTimingFilter');assert(isscalar(second)&&second==first);delete(first);delete(parent);
assert(isequaln(before,teach_snapshot(m))&&isequaln(cfg,pmsm_config('read'))&&getVariable(mw,'n')==1234);timing_filter_data;
report=struct('passed',true,'source',r,'exact_prefix_signal_records',prefixChecks,'raw_checked_curves',checks,'time_axes_linked',true,'metrics_table_checked',true,'existing_topic_entry_checked',true,'window_reuse_checked',true,'current_parameters_preserved',true,'derived_workspace_restored',true,'scope','Two new full 200ms filtered runs; two sealed unfiltered runs reused; all four independently reproduced for first2ms only, not full200ms replays.');
teach_writejson(fullfile(target,'validation.json'),report);disp(r.metrics);disp('TIMING_FILTER_VALIDATED');
end
function check_curve(f,tag,x,y)
ln=findall(f,'Tag',tag);assert(isscalar(ln)&&isequaln(ln.XData(:),x(:))&&isequaln(ln.YData(:),y(:)),'曲线来源不符：%s',tag);
end
