function report=validate_timing_feedback
root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'teaching'));
m='PMSM_FOC_R2026a';assert(~bdIsLoaded(m));load_system(fullfile(root,[m '.slx']));guard=onCleanup(@()close_system(m,0));
mw=get_param(m,'ModelWorkspace');assignin(mw,'n',1234);set_param([m '/采样设置'],'bias_on','on');before=teach_snapshot(m);cfg=pmsm_config('read');
[f,r]=open_pmsm_timing_feedback;assert(isequal(f.Position,[80 60 1120 800])&&isequal(f.Color,[1 1 1]));
p=jsondecode(fileread(fullfile(r.source_folder,'plan.json')));out=cell(1,3);
for k=1:3,s=load(fullfile(r.source_folder,[p.cases(k).id '.mat']),'signals');out{k}=s.signals;end
h=62.5e-9;N=800;origin=(round(p.duration_s/h)-2*N)*h;checks=0;
for k=1:3
 s=out{k};t=s.obs_pwm_timing.Time;tick=round(t/h);v=teach_values(s.obs_pwm_timing);a=teach_values(s.obs_adc_timing);
 C=round([5 10.5 15]*1e-6/h);write=232+C(k);apply=(floor(write/(N/2))+1)*(N/2);
 w=v(:,4)>.5;u=v(:,5)>.5;assert(all(mod(tick(w),N)==write)&&all(mod(tick(u),N)==mod(apply,N)));
 assert(all(mod(tick(a(:,6)>.5),N)==232));assert(max(abs(v(u,9)-(apply-232)*h))<1e-12);
 x=(t-origin)*1e6;ix=x>=0&x<=100;
 check(sprintf('timing_write_%d',k),x(ix&w),k*ones(nnz(ix&w),1));check(sprintf('timing_apply_%d',k),x(ix&u),k*ones(nnz(ix&u),1));
 check(sprintf('timing_sequence_%d',k),x(ix),v(ix,7));
 for panel=1:4
  t=s.log_Te.Time;ix=t>=.18&t<=.2;state=teach_values(s.obs_state);
  switch panel
   case 1,y=state(:,1);
   case 2,y=state(:,2)-teach_values(s.log_iq_ref);
   case 3,y=teach_values(s.log_Te);
   case 4,y=teach_values(s.log_speed);
  end
  check(sprintf('timing_response_%d_case_%d',panel,k),t(ix)*1000,y(ix));
 end
end
fields={'obs_id_ref','','log_TL','log_nref'};for panel=[1 3 4],y=teach_values(out{1}.(fields{panel}));check(sprintf('timing_reference_%d',panel),t(ix)*1000,y(ix));end
assert(checks==24);assert(r.boundary_late_equal_physical_signals==7);
ln=findobj(f,'Tag','timing_response_1_case_1');ln.Parent.XLim=[185 190];drawnow;
for panel=2:4,ln=findobj(f,'Tag',sprintf('timing_response_%d_case_1',panel));assert(isequal(ln.Parent.XLim,[185 190]));end
ln=findobj(f,'Tag','timing_sequence_1');assert(isequal(ln.Parent.XLim,[0 100]));ln.Parent.XLim=[10 60];drawnow;
ln=findobj(f,'Tag','timing_write_1');assert(isequal(ln.Parent.XLim,[10 60]));ln.Parent.XLim=[0 100];
ln=findobj(f,'Tag','timing_response_1_case_1');assert(isequal(ln.Parent.XLim,[185 190]));ln.Parent.XLim=[180 200];
menu=findall(f,'Type','uimenu','Text','指标与工况');menu.MenuSelectedFcn(menu,[]);info=findall(groot,'Type','figure','Name','PWM更新指标 · 已保存实验');assert(isscalar(info));tab=findall(info,'Type','uitable');assert(isequal(size(tab.Data),[6 4]));delete(info);
target=fullfile(root,'signal_chain','timing_feedback');if ~isfolder(target),mkdir(target);end
exportgraphics(f,fullfile(target,'comparison.png'),'Resolution',140);savefig(f,fullfile(target,'comparison.fig'));delete(f);
assert(isequaln(before,teach_snapshot(m))&&isequaln(cfg,pmsm_config('read'))&&getVariable(mw,'n')==1234);
assert(strcmp(r.model_sha256,teach_hash(fullfile(root,[m '.slx'])))&&strcmp(r.source_record_sha256,teach_hash(fullfile(r.source_folder,'record.json'))));
report=struct('passed',true,'raw_exact_curves',checks,'events_independently_checked',true,'two_time_scales_linked_separately',true,'metrics_table_checked',true,'configuration_preserved',true,'source',r);
teach_writejson(fullfile(target,'validation.json'),report);disp(r.metrics);disp('TIMING_FEEDBACK_VIEW_VALIDATED');
 function check(tag,x,y)
  ln=findall(f,'Tag',tag);assert(isscalar(ln)&&isequaln(ln.XData(:),x(:))&&isequaln(ln.YData(:),y(:)),'曲线不符：%s',tag);checks=checks+1;
 end
end
