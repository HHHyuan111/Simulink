function [fig,report]=open_pmsm_sampling_comparison
% Raw archived currents and paired noise PSD, without new simulation.
here=fileparts(mfilename('fullpath'));
summary=jsondecode(fileread(fullfile(here,'experiments','examples','noise_filter','summary.json')));
folder=fullfile(here,'experiments','runs',summary.source_run_id);record=pmsm_experiment_verify(folder);
assert(strcmp(summary.source_record_sha256,teach_hash(fullfile(folder,'record.json'))),'实验档案身份不符。');
assert(strcmp(record.model_sha256,teach_hash(fullfile(fileparts(here),'PMSM_FOC_R2026a.slx'))),'归档模型版本不一致。');
plan=jsondecode(fileread(fullfile(folder,'plan.json')));
assert(strcmp(plan.scenario.id,'noise_filter')&&numel(plan.cases)==3&&isequal(plan.value(:),[.02;1500]));
ws=plan.baseline_state.workspace_values;
assert(ws(strcmp({ws.name},'n')).value==3000&&ws(strcmp({ws.name},'Vdc')).value==24);
assert(abs(plan.duration_s-.2)<1e-12&&max(abs(plan.statistics_window_s(:)-[.18;.2]))<1e-12);
outputs=cell(1,3);for k=1:3,s=load(fullfile(folder,[plan.cases(k).id '.mat']),'signals');outputs{k}=s.signals;end
for k=1:3,assert(all(abs(teach_values(outputs{k}.log_TL)-.207)<1e-12));end
[decomposition,trace]=pmsm_noise_filter_analysis(outputs,plan);
spectralWindow=[plan.duration_s-.08 plan.duration_s];
psd=pmsm_noise_psd(trace.time_s,trace.noise_component{2},trace.noise_component{3},spectralWindow,256);
report=struct('source','已保存的噪声与滤波实验，不是当前out','source_folder',folder,...
 'source_record_sha256',summary.source_record_sha256,'time_window_s',plan.statistics_window_s,...
 'psd_window_s',spectralWindow,'psd_definition',psd.definition,'filter_hz',decomposition.filter_hz,...
 'control_period_s',decomposition.control_period_s,'same_injected_sequence',decomposition.same_injected_sequence,...
 'decomposition_max_error_A',max([decomposition.cases.decomposition_max_abs_error_A]));
fig=figure('Name','采样与滤波对比 · 已保存实验','NumberTitle','off','Color','white','Position',[80 60 1120 800],...
 'Tag','PMSMSamplingComparison','UserData',report);
g=tiledlayout(fig,2,3,'Padding','compact','TileSpacing','compact');title(g,'采样与滤波');
blue=[0 .447 .741];red=[.84 .15 .16];gray=[.5 .5 .5];colors=[gray;blue;red];labels={'参考','噪声','滤波'};
s=outputs{3};t=trace.time_s;ix=t>=plan.statistics_window_s(1)&t<=plan.statistics_window_s(2);
assert(isequal(t,s.obs_state.Time,s.log_id.Time,s.obs_id_ref.Time,s.log_Te.Time,s.log_TL.Time,s.log_iq_ref.Time));
fast=s.obs_current_fast.Time;fastIx=fast>=plan.statistics_window_s(1)&fast<=plan.statistics_window_s(2);
truth=teach_values(s.obs_current_fast);fb=teach_values(s.log_iabc_meas);
axesTime=gobjects(1,5);axesTime(1)=nexttile(g);hold on;
traceLine(fast(fastIx)*1000,truth(fastIx,1),blue,'真实','sampling_true_A','-');
traceLine(t(ix)*1000,fb(ix,1),red,'反馈','sampling_feedback_A','-');frame('A相电流','A',true);
axesTime(2)=nexttile(g);hold on;
traceLine(t(ix)*1000,trace.noise_component{2}(ix,1),blue,'滤波前','noise_before','-');
traceLine(t(ix)*1000,trace.noise_component{3}(ix,1),red,'滤波后','noise_after','-');frame('A相噪声分量','A',true);
nexttile(g);hold on;
traceLine(psd.display_frequency_Hz,10*log10(max(psd.display_input_psd_A2_per_Hz(:,1),realmin)),blue,'滤波前','noise_psd_before','-');
traceLine(psd.display_frequency_Hz,10*log10(max(psd.display_output_psd_A2_per_Hz(:,1),realmin)),red,'滤波后','noise_psd_after','-');
frame('A相噪声功率谱','dB re 1 A²/Hz',false);xlabel('频率 [Hz]');xlim([0 psd.fs_Hz/2]);
state=teach_values(s.obs_state);idFeedback=teach_values(s.log_id);idRef=teach_values(s.obs_id_ref);
axesTime(3)=nexttile(g);hold on;
traceLine(t(ix)*1000,state(ix,1),blue,'真实','sampling_id_true','-');
traceLine(t(ix)*1000,idFeedback(ix),red,'反馈','sampling_id_feedback','-');
traceLine(t(ix)*1000,idRef(ix),gray,'给定','sampling_id_ref','--');frame('d轴电流','A',true);
axesTime(4)=nexttile(g);hold on;
for k=1:3
 q=outputs{k};assert(isequal(t,q.obs_state.Time,q.log_iq_ref.Time,q.log_Te.Time));
 v=teach_values(q.obs_state);ref=teach_values(q.log_iq_ref);error=v(:,2)-ref;
 traceLine(t(ix)*1000,error(ix),colors(k,:),labels{k},sprintf('sampling_iq_error_%d',k),caseStyle(k));
end
frame('q轴跟踪误差','A',true);
axesTime(5)=nexttile(g);hold on;
for k=1:3
 q=outputs{k};v=teach_values(q.log_Te);assert(isequal(q.log_TL.Time,s.log_TL.Time)&&isequal(q.log_TL.Data,s.log_TL.Data));
 traceLine(t(ix)*1000,v(ix),colors(k,:),labels{k},sprintf('sampling_torque_%d',k),caseStyle(k));
end
loadTorque=teach_values(s.log_TL);traceLine(t(ix)*1000,loadTorque(ix),gray,'负载','sampling_load','--');frame('转矩','N·m',true);
linkaxes(axesTime,'x');pmsm_sampling_comparison_menu(fig);uimenu(fig,'Text','工况与说明','MenuSelectedFcn',@(~,~)showInfo(report));
 function traceLine(x,y,color,label,tag,style)
  plot(x,y,'Color',color,'LineWidth',1.1,'DisplayName',label,'Tag',tag,'LineStyle',style);
 end
 function frame(name,unit,isTime)
  title(name);ylabel(unit);grid on;legend('show','Location','best');ax=gca;ax.FontSize=12;
  if isTime,xlabel('时间 [ms]');xlim(plan.statistics_window_s*1000);end
 end
end
function s=caseStyle(k)
if k==1,s='--';else,s='-';end
end
function showInfo(r)
f=figure('Name','采样对比说明 · 已保存实验','NumberTitle','off','Color','white','MenuBar','none','ToolBar','none','Position',[180 160 850 330]);
uicontrol(f,'Style','text','BackgroundColor','white','FontSize',14,'HorizontalAlignment','left',...
 'Units','normalized','Position',[.04 .04 .92 .92],'String',{
 '固定实验：3000 rpm、24 V、0.207 N·m；原PI、理想桥。',...
 '参考 / 噪声 / 同一噪声加低通：0.02 A RMS，截止1500 Hz。',...
 '时域180～200 ms；物理电流1 μs，控制记录50 μs。',...
 'PSD取120～200 ms：Hann窗256点、50%重叠、20 kHz采样。',...
 '4倍零填充只加密显示；原频率间隔78.125 Hz。',...
 '噪声分量由同组实际注入序列和原滤波递推分解，不是总误差。',...
 'd轴真值/反馈采用滤波组各自坐标；q轴误差=各组真实iq−自身给定。',...
 '滤波不保证所有跟踪与转矩指标改善；当前模型参数未被更改。'});
assert(r.same_injected_sequence);
end
