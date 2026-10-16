function [fig,report]=open_pmsm_deadtime_comparison
% A single native comparison figure from the existing verified experiment.
here=fileparts(mfilename('fullpath'));summary=jsondecode(fileread(fullfile(here,'experiments','examples','low_speed_compensation','summary.json')));
folder=fullfile(here,'experiments','runs',summary.source_run_id);record=pmsm_experiment_verify(folder);
assert(strcmp(summary.source_record_sha256,teach_hash(fullfile(folder,'record.json'))),'对比档案身份不符。');
assert(strcmp(record.scenario.id,'low_speed_compensation')&&numel(record.cases)==3);
assert(record.factor_value==2&&abs(record.duration_s-.2)<1e-12,'此入口只展示既有2μs固定实验。');
assert(strcmp(record.model_sha256,teach_hash(fullfile(fileparts(here),'PMSM_FOC_R2026a.slx'))),'归档结果与当前模型文件版本不一致。');
plan=jsondecode(fileread(fullfile(folder,'plan.json')));outputs=cell(1,3);
for k=1:3,s=load(fullfile(folder,[plan.cases(k).id '.mat']),'signals');outputs{k}=s.signals;end
for k=1:3,assert(all(teach_values(outputs{k}.log_nref)==600)&&all(abs(teach_values(outputs{k}.log_TL)-.207)<1e-12));end
ws=plan.baseline_state.workspace_values;assert(ws(strcmp({ws.name},'Vdc')).value==24);
[aligned,alignment]=pmsm_deadtime_pair_alignment(outputs,plan);
assert(isequal({plan.cases.id},{'reference','factor','compensated'}));
before=outputs{2};after=outputs{3};window=plan.statistics_window_s;
spectralWindow=[plan.duration_s-.08 plan.duration_s];spectra=cell(1,2);
for k=1:2
 s=outputs{k+1};assert(isequal(s.obs_current_fast.Time,s.log_theta_true.Time));
 spectra{k}=pmsm_current_spectrum(s.obs_current_fast.Time,teach_values(s.obs_current_fast),teach_values(s.log_theta_true),spectralWindow,19);
end
assert(abs(spectra{1}.fe_Hz-spectra{2}.fe_Hz)<.01,'对比电频率不一致。');
metrics=zeros(2,2);
for k=1:2
 s=outputs{k+1};t=s.log_Te.Time;state=teach_values(s.obs_state);iqref=teach_values(s.log_iq_ref);
 assert(isequal(t,s.obs_state.Time,s.log_iq_ref.Time));ix=t>=window(1)&t<=window(2);
 assert(sum(ix)>100);te=teach_values(s.log_Te);
 metrics(k,:)=[sqrt(mean((state(ix,2)-iqref(ix)).^2)),std(te(ix))];
 archived=record.cases(k+1).metrics;
 assert(abs(metrics(k,1)-archived.iq_true_tracking_rms_A)<1e-12&&abs(metrics(k,2)-archived.torque_std_Nm)<1e-12,'归档指标重算不一致。');
end
report=struct('source','已保存的固定实验，不是当前out','source_folder',folder,...
 'source_record_sha256',summary.source_record_sha256,'statistics_window_s',window,'metrics',metrics,...
 'metric_names',{{'真实iq跟踪RMS [A]','转矩标准差 [N·m]'}},'alignment',alignment,...
 'spectrum_window_s',spectralWindow,'spectrum_method',spectra{1}.definition);
fig=figure('Name','补偿前后对比 · 已保存实验','NumberTitle','off','Color','white','Position',[80 60 1120 800],...
 'UserData',report,'Tag','PMSMDeadtimeComparison');
g=tiledlayout(fig,2,3,'TileSpacing','compact','Padding','compact');title(g,'死区补偿效果');colors=[0 .447 .741;.84 .15 .16];labels={'补偿前','补偿后'};
for phase=1:3
 ax(phase)=nexttile(g);hold(ax(phase),'on');
 for k=1:2
  plot(ax(phase),aligned(k+1).angle_deg,aligned(k+1).current_ABC_A(:,phase),'Color',colors(k,:),...
   'LineWidth',1.1,'DisplayName',labels{k},'Tag',sprintf('phase_%d_case_%d',phase,k));
 end
 title(ax(phase),sprintf('%c相电流','A'+phase-1));xlabel(ax(phase),'电角度 [°]');ylabel(ax(phase),'A');
 xlim(ax(phase),[0 360]);xticks(ax(phase),0:60:360);grid(ax(phase),'on');legend(ax(phase),'show','Location','best');ax(phase).FontSize=12;
end
linkaxes(ax,'x');frequencyAxes=nexttile(g);hold(frequencyAxes,'on');
for k=1:2
 s=spectra{k};ix=s.display_frequency_Hz<=1000;
 plot(frequencyAxes,s.display_frequency_Hz(ix),20*log10(max(s.display_fft_peak_A(ix,1),1e-8)),...
  'Color',colors(k,:),'LineWidth',1.1,'DisplayName',labels{k},'Tag',sprintf('spectrum_case_%d',k));
end
title(frequencyAxes,'A相电流频谱');xlabel(frequencyAxes,'频率 [Hz]');ylabel(frequencyAxes,'dB re 1 A');
grid(frequencyAxes,'on');xlim(frequencyAxes,[0 1000]);legend(frequencyAxes,'show','Location','best');frequencyAxes.FontSize=12;
harmonicAxes=nexttile(g);bars=bar(harmonicAxes,(2:19)',[spectra{1}.harmonic_percent(2:end,1) spectra{2}.harmonic_percent(2:end,1)],'grouped');
for k=1:2,bars(k).FaceColor=colors(k,:);bars(k).EdgeColor='none';bars(k).DisplayName=labels{k};bars(k).Tag=sprintf('harmonics_case_%d',k);end
title(harmonicAxes,'A相低次谐波');xlabel(harmonicAxes,'谐波次数');ylabel(harmonicAxes,'相对基波 [%]');
grid(harmonicAxes,'on');xticks(harmonicAxes,[2 5 7 11 13 17 19]);legend(harmonicAxes,'show','Location','best');harmonicAxes.FontSize=12;
a=nexttile(g);hold(a,'on');
for k=1:2
 s=outputs{k+1};t=s.log_Te.Time;ix=t>=window(1)&t<=window(2);te=teach_values(s.log_Te);
 plot(a,t(ix)*1000,te(ix),'Color',colors(k,:),'LineWidth',1.1,'DisplayName',labels{k},'Tag',sprintf('torque_case_%d',k));
end
t=before.log_TL.Time;ix=t>=window(1)&t<=window(2);loadTorque=teach_values(before.log_TL);
assert(isequal(before.log_TL.Time,after.log_TL.Time)&&isequal(before.log_TL.Data,after.log_TL.Data));
plot(a,t(ix)*1000,loadTorque(ix),'--','Color',[.5 .5 .5],'DisplayName','负载','Tag','load_torque');
title(a,'转矩');xlabel(a,'时间 [ms]');ylabel(a,'N·m');grid(a,'on');legend(a,'show','Location','best');a.FontSize=12;xlim(a,window*1000);
pmsm_sampling_comparison_menu(fig);uimenu(fig,'Text','指标与工况','MenuSelectedFcn',@(~,~)showInfo(report));
end
function fig=showInfo(report)
fig=figure('Name','对比指标 · 已保存实验','NumberTitle','off','MenuBar','none','ToolBar','none','Color','white','Position',[180 160 760 330]);
data=cell(2,3);for k=1:2,data(k,:)={report.metric_names{k},sprintf('%.6f',report.metrics(1,k)),sprintf('%.6f',report.metrics(2,k))};end
uitable(fig,'Data',data,'ColumnName',{'指标','补偿前','补偿后'},'RowName',[],'FontSize',14,...
 'ColumnWidth',{260 180 180},'Units','normalized','Position',[.04 .59 .92 .36]);
uicontrol(fig,'Style','text','BackgroundColor','white','FontSize',14,'HorizontalAlignment','left','Units','normalized','Position',[.04 .03 .92 .52],...
 'String',{'已保存实验：600 rpm、24 V、负载0.207 N·m、死区2 μs。',...
 '电流按电角周期对齐；转矩与指标取180～200 ms。',...
 '指标按50 μs控制记录计算，仅代表此工况。',...
 '频谱取120～200 ms、1 μs原始记录；去直流、Hann窗。',...
 '低次谐波按真实电角度联合拟合2～19次，不是全带宽THD。'});
end
