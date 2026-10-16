function report=validate_pmsm_deadtime_comparison
here=fileparts(mfilename('fullpath'));root=fileparts(here);addpath(root,fullfile(root,'layout','appearance'));m='PMSM_FOC_R2026a';assert(~bdIsLoaded(m));
load_system(fullfile(root,[m '.slx']));closer=onCleanup(@()close_system(m,0));set_param([m '/采样设置'],'noise_on','on');
mw=get_param(m,'ModelWorkspace');assignin(mw,'n',1234);cfg=pmsm_config('read');before=teach_snapshot(m);code=mw.MATLABCode;
[f,r]=open_pmsm_deadtime_comparison;assert(isequal(f.Position,[80 60 1120 800])&&isequal(f.Color,[1 1 1]));
folder=r.source_folder;hash=teach_hash(fullfile(folder,'record.json'));plan=jsondecode(fileread(fullfile(folder,'plan.json')));outputs=cell(1,3);
for k=1:3,s=load(fullfile(folder,[plan.cases(k).id '.mat']),'signals');outputs{k}=s.signals;end
[aligned,info]=pmsm_deadtime_pair_alignment(outputs,plan);assert(isequaln(info,r.alignment));traces=0;
layout=findobj(f,'Type','tiledlayout');assert(isequal(layout.GridSize,[2 3]));
for k=1:2
 s=outputs{k+1};a=pmsm_current_spectrum(s.obs_current_fast.Time,teach_values(s.obs_current_fast),teach_values(s.log_theta_true),[.12 .2],19);
 ix=a.display_frequency_Hz<=1000;ln=findobj(f,'Tag',sprintf('spectrum_case_%d',k));
 assert(isscalar(ln)&&isequal(ln.XData(:),a.display_frequency_Hz(ix))&&isequal(ln.YData(:),20*log10(max(a.display_fft_peak_A(ix,1),1e-8))));
 b=findobj(f,'Tag',sprintf('harmonics_case_%d',k));assert(isscalar(b)&&isequal(b.XData(:),(2:19)')&&isequal(b.YData(:),a.harmonic_percent(2:end,1)));
 assert(a.electrical_cycles>=3&&a.sample_count==80000&&abs(a.fs_Hz-1e6)<.01);
end
for phase=1:3
 for k=1:2
  ln=findobj(f,'Tag',sprintf('phase_%d_case_%d',phase,k));assert(isscalar(ln));
  assert(isequal(ln.XData(:),aligned(k+1).angle_deg)&&isequal(ln.YData(:),aligned(k+1).current_ABC_A(:,phase)));traces=traces+1;
 end
end
for k=1:2
 s=outputs{k+1};t=s.log_Te.Time;ix=t>=r.statistics_window_s(1)&t<=r.statistics_window_s(2);v=teach_values(s.log_Te);ln=findobj(f,'Tag',sprintf('torque_case_%d',k));
 assert(isequal(ln.XData(:),t(ix)*1000)&&isequal(ln.YData(:),v(ix)));traces=traces+1;
end
s=outputs{2};t=s.log_TL.Time;ix=t>=r.statistics_window_s(1)&t<=r.statistics_window_s(2);v=teach_values(s.log_TL);ln=findobj(f,'Tag','load_torque');
assert(isequal(ln.XData(:),t(ix)*1000)&&isequal(ln.YData(:),v(ix)));traces=traces+1;
line=findobj(f,'Tag','phase_1_case_1');line.Parent.XLim=[165 195];drawnow;
for phase=2:3,line=findobj(f,'Tag',sprintf('phase_%d_case_1',phase));assert(isequal(line.Parent.XLim,[165 195]));end
line.Parent.XLim=[0 360];
menu=findall(f,'Type','uimenu','Text','指标与工况');assert(isscalar(menu));menu.MenuSelectedFcn(menu,[]);
infoFig=findall(groot,'Type','figure','Name','对比指标 · 已保存实验');assert(isscalar(infoFig));table=findall(infoFig,'Type','uitable');assert(isequal(size(table.Data),[2 3]));delete(infoFig);
example=fullfile(here,'deadtime_lesson','example');if ~isfolder(example),mkdir(example);end
exportgraphics(f,fullfile(example,'comparison.png'),'Resolution',140);close(f);
panel=open_pmsm_deadtime_lesson;buttons=findall(panel,'Type','uibutton');button=buttons(strcmp({buttons.Text},'内置补偿示例'));assert(isscalar(button));button.ButtonPushedFcn(button,[]);
opened=findall(groot,'Type','figure','Tag','PMSMDeadtimeComparison');assert(isscalar(opened));delete(opened);
exportapp(panel,fullfile(root,'.build','deadtime_lesson_compare_ui.png'));delete(panel);
assert(isequaln(before,teach_snapshot(m))&&isequaln(cfg,pmsm_config('read'))&&strcmp(code,mw.MATLABCode)&&getVariable(mw,'n')==1234);
assert(strcmp(hash,teach_hash(fullfile(folder,'record.json'))));
report=struct('passed',true,'source_run',folder,'source_record_sha256',hash,'exact_plotted_traces',traces,...
 'metrics_recomputed_from_raw',true,'metrics',r.metrics,'current_angle_zoom_linked',true,'native_info_menu_checked',true,...
 'teaching_button_checked',true,'current_model_and_configuration_preserved',true,'archive_read_only',true,...
 'spectrum_curves_checked',2,'harmonic_series_checked',2,'spectrum_window_s',r.spectrum_window_s,'topic_layout',[2 3]);
for k=1:3,files={'open_pmsm_deadtime_comparison.m','pmsm_deadtime_pair_alignment.m','pmsm_current_spectrum.m'};report.sources(k)=struct('path',files{k},'sha256',teach_hash(fullfile(here,files{k})));end
teach_writejson(fullfile(here,'deadtime_lesson','comparison_validation.json'),report);fprintf('DEADTIME_COMPARISON_VALIDATED %d traces\n',traces);
end
