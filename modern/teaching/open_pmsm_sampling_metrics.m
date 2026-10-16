function fig=open_pmsm_sampling_metrics(metrics,provenance)
% Native MATLAB tables, explicitly tied to one preview and one time window.
teach=fileparts(mfilename('fullpath'));root=fileparts(teach);
if nargin==0
 path=fullfile(root,'.build','current_sampling_metrics.mat');
 assert(isfile(path),'请先运行 preview_pmsm_current_sampling 生成本次演示统计');
 data=load(path,'metrics','provenance');metrics=data.metrics;provenance=data.provenance;
end
assert(strcmp(metrics.analysis_source_sha256,teach_hash(fullfile(teach,'pmsm_current_sampling_metrics.m'))),'统计方法已更新，请重新运行演示');
assert(isfield(metrics,'feedback_minus_hold_A'),'统计格式已更新，请重新运行演示');
fig=uifigure('Name','采样统计','Position',[100 70 1050 720]);g=uigridlayout(fig,[5 1]);
g.RowHeight={65,220,220,70,'1x'};g.Padding=[20 15 20 15];g.RowSpacing=10;
window=metrics.actual_window_s*1e3;
uilabel(g,'Text',sprintf('最近演示｜%.3f–%.3f ms｜%d 点｜网格 %.4g µs',window(1),window(2),metrics.sample_count,metrics.grid_step_s*1e6),'FontSize',19,'FontWeight','bold');
e=metrics.feedback_minus_truth;h=metrics.hold_minus_truth_A;p=metrics.feedback_minus_hold_A;
rows={'反馈−真实：A';'反馈−真实：B';'反馈−真实：C';'保持−真实：A';'反馈−保持：A'};
values=[[e.rms_A(:) e.mean_A(:) e.max_abs_A(:)];h.rms_A h.mean_A h.max_abs_A;p.rms_A p.mean_A p.max_abs_A];
table1=uitable(g,'Data',[rows num2cell(values)],'ColumnName',{'比较项','RMS [A]','均值 [A]','最大绝对值 [A]'}, ...
 'ColumnWidth',{300,190,190,240},'RowName',{},'FontSize',16,'ColumnEditable',false(1,4));table1.Tag='sampling_error_metrics';
keys={'trigger_to_JEOS','A_end_to_JEOS','B_end_to_JEOS','C_end_to_JEOS'};
labels={'触发 → JEOS';'A相采样结束 → JEOS';'B相采样结束 → JEOS';'C相采样结束 → JEOS'};data=cell(4,6);
for k=1:4
 s=metrics.adc.intervals.(keys{k});data(k,:)={labels{k},'—','—','—',s.paired_count,s.missing_count+s.ambiguous_count};
 if s.available,data(k,2:4)={s.min_us,s.mean_us,s.max_us};end
end
table2=uitable(g,'Data',data,'ColumnName',{'ADC事件间隔','最小 [µs]','平均 [µs]','最大 [µs]','配对数','未配对'}, ...
 'ColumnWidth',{300,140,140,140,110,110},'RowName',{},'FontSize',16,'ColumnEditable',false(1,6));table2.Tag='sampling_timing_metrics';
uilabel(g,'Text',{'统计当前演示记录，Scope缩放和后续模型运行不会自动更新本表。'; ...
 '电流误差包含已开启因素；事件间隔不等于整个反馈链的统一延迟。'; ...
 '“—”表示没有可配对事件，不代表零延迟。20ms演示是启动过程。'},'FontSize',15);
stamp='';if isfield(provenance,'created_at'),stamp=[provenance.created_at '｜'];end
uilabel(g,'Text',sprintf('%s模型 %s…｜触发 %d / JEOS %d',stamp,provenance.model_sha256(1:12),metrics.adc.trigger_count,metrics.adc.JEOS_count),'FontSize',14);
end
