function report=validate_pmsm_sampling_lesson
here=fileparts(mfilename('fullpath'));root=fileparts(here);addpath(root,fullfile(root,'layout','appearance'));
m='PMSM_FOC_R2026a';assert(~bdIsLoaded(m));load_system(fullfile(root,[m '.slx']));closer=onCleanup(@()close_system(m,0));
mw=get_param(m,'ModelWorkspace');assignin(mw,'n',1234);set_param([m '/采样设置'],'bias_on','on');
before=teach_snapshot(m);cfg=pmsm_config('read');hash=teach_hash(fullfile(root,[m '.slx']));
panel=open_pmsm_sampling_lesson;b=findall(panel,'Tag','sampling_lesson_current');b.ButtonPushedFcn(b,[]);
assert(pmsm_current_sampling_scope('installed'));d=pmsm_current_sampling_scope('install');c=get_param(d.path,'ScopeConfiguration');
assert(isequal(c.Position,[80 60 1120 800])&&~c.DataLoggingDecimateData);
pmsm_current_sampling_scope('remove');pmsm_pwm_scope('remove');pmsm_electrical_scope('remove');pmsm_native_scope('remove');
assert(isequaln(before,teach_snapshot(m))&&isequaln(cfg,pmsm_config('read')));
b=findall(panel,'Tag','sampling_lesson_compare');b.ButtonPushedFcn(b,[]);
f=findall(groot,'Type','figure','Tag','PMSMSamplingComparison');assert(isscalar(f));r=f.UserData;
assert(isequal(f.Position,[80 60 1120 800])&&isequal(f.Color,[1 1 1]));
folder=r.source_folder;archiveHash=teach_hash(fullfile(folder,'record.json'));p=jsondecode(fileread(fullfile(folder,'plan.json')));
outputs=cell(1,3);for k=1:3,s=load(fullfile(folder,[p.cases(k).id '.mat']),'signals');outputs{k}=s.signals;end
s=outputs{3};t=s.log_Te.Time;ix=t>=p.statistics_window_s(1)&t<=p.statistics_window_s(2);
alpha=exp(-2*pi*1500*50e-6);noise=teach_values(s.log_iabc_noise);filtered=filter(1-alpha,[1 -alpha],noise);
assert(isequal(noise,teach_values(outputs{2}.log_iabc_noise)));
psd=pmsm_noise_psd(t,noise,filtered,[.12 .2],256);checks=0;
fast=s.obs_current_fast.Time;keep=fast>=p.statistics_window_s(1)&fast<=p.statistics_window_s(2);truth=teach_values(s.obs_current_fast);
check('sampling_true_A',fast(keep)*1000,truth(keep,1));
v=teach_values(s.log_iabc_meas);check('sampling_feedback_A',t(ix)*1000,v(ix,1));
check('noise_before',t(ix)*1000,noise(ix,1));check('noise_after',t(ix)*1000,filtered(ix,1));
check('noise_psd_before',psd.display_frequency_Hz,10*log10(max(psd.display_input_psd_A2_per_Hz(:,1),realmin)));
check('noise_psd_after',psd.display_frequency_Hz,10*log10(max(psd.display_output_psd_A2_per_Hz(:,1),realmin)));
v=teach_values(s.obs_state);check('sampling_id_true',t(ix)*1000,v(ix,1));
v=teach_values(s.log_id);check('sampling_id_feedback',t(ix)*1000,v(ix));v=teach_values(s.obs_id_ref);check('sampling_id_ref',t(ix)*1000,v(ix));
for k=1:3
 q=outputs{k};v=teach_values(q.obs_state);ref=teach_values(q.log_iq_ref);err=v(:,2)-ref;
 check(sprintf('sampling_iq_error_%d',k),t(ix)*1000,err(ix));v=teach_values(q.log_Te);check(sprintf('sampling_torque_%d',k),t(ix)*1000,v(ix));
end
v=teach_values(s.log_TL);check('sampling_load',t(ix)*1000,v(ix));assert(checks==16);
ln=findobj(f,'Tag','sampling_feedback_A');ln.Parent.XLim=[185 190];drawnow;
for tag={'noise_before','sampling_id_true','sampling_iq_error_1','sampling_torque_1'}
 ln=findobj(f,'Tag',tag{1});assert(isequal(ln.Parent.XLim,[185 190]));
end
ln=findobj(f,'Tag','noise_psd_before');assert(isequal(ln.Parent.XLim,[0 psd.fs_Hz/2]));
ln=findobj(f,'Tag','sampling_feedback_A');ln.Parent.XLim=p.statistics_window_s*1000;
menu=findall(f,'Type','uimenu','Text','工况与说明');menu.MenuSelectedFcn(menu,[]);
info=findall(groot,'Type','figure','Name','采样对比说明 · 已保存实验');assert(isscalar(info));delete(info);
target=fullfile(here,'sampling_lesson');if ~isfolder(target),mkdir(target);end
exportgraphics(f,fullfile(target,'comparison.png'),'Resolution',140);delete(f);
exportapp(panel,fullfile(root,'.build','sampling_lesson_ui.png'));delete(panel);
assert(isequaln(before,teach_snapshot(m))&&isequaln(cfg,pmsm_config('read'))&&getVariable(mw,'n')==1234);
assert(strcmp(hash,teach_hash(fullfile(root,[m '.slx'])))&&strcmp(archiveHash,teach_hash(fullfile(folder,'record.json'))));
report=struct('passed',true,'exact_or_tolerance_checked_curves',checks,'noise_sequence_paired',true,...
 'independent_noise_decomposition_checked',true,'time_axes_linked',true,'psd_axis_independent',true,...
 'observer_removed_and_configuration_preserved',true,'menu_checked',true,'callbacks_checked',2,...
 'archive_read_only',true,'source_run',folder,'source_record_sha256',archiveHash,'model_sha256',hash);
teach_writejson(fullfile(target,'validation.json'),report);disp('SAMPLING_LESSON_VALIDATED');
 function check(tag,x,y)
  ln=findobj(f,'Tag',tag);assert(isscalar(ln)&&isequal(ln.XData(:),x(:)));
  assert(max(abs(ln.YData(:)-y(:)))<1e-10,'曲线不符：%s',tag);checks=checks+1;
 end
end
