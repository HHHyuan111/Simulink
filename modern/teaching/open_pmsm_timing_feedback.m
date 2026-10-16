function [fig,report]=open_pmsm_timing_feedback
% Read-only connection between recorded event causality and closed-loop effects.
here=fileparts(mfilename('fullpath'));root=fileparts(here);
latest=jsondecode(fileread(fullfile(root,'signal_chain','timing_feedback_latest.json')));assert(latest.passed);
folder=latest.folder;assert(strcmp(latest.record_sha256,teach_hash(fullfile(folder,'record.json'))));record=pmsm_experiment_verify(folder);
assert(strcmp(record.model_sha256,teach_hash(fullfile(root,'PMSM_FOC_R2026a.slx'))));
assert(strcmp(record.scenario.id,'timing_deadline')&&record.duration_s==.2&&isequal(record.factor_value(:)',[5 10.5 15]));
plan=jsondecode(fileread(fullfile(folder,'plan.json')));outputs=cell(1,3);
base=plan.cases(1).configuration;computeRow=strcmp({base.rows.key},'compute_us');assert(sum(computeRow)==1);
for k=2:3,other=plan.cases(k).configuration;other.rows(computeRow).value=base.rows(computeRow).value;assert(isequaln(base,other),'三组之间存在额外配置变化。');end
for k=1:3,s=load(fullfile(folder,[record.cases(k).id '.mat']),'signals');outputs{k}=s.signals;end
[events,traces]=pmsm_timing_deadline_analysis(outputs,plan);
labels={'5 μs','10.5 μs','15 μs'};window=[.18 .2];metrics=zeros(3,3);
for k=1:3
 s=outputs{k};t=s.log_Te.Time;ix=t>=window(1)&t<=window(2);state=teach_values(s.obs_state);
 assert(isequal(t,s.obs_state.Time,s.obs_id_ref.Time,s.log_iq_ref.Time,s.log_speed.Time,s.log_nref.Time,s.log_TL.Time)&&isequal(t,outputs{1}.log_Te.Time));
 assert(isequal(s.log_nref.Data,outputs{1}.log_nref.Data)&&isequal(s.log_TL.Data,outputs{1}.log_TL.Data));
 e=state(:,2)-teach_values(s.log_iq_ref);te=teach_values(s.log_Te);se=teach_values(s.log_speed)-teach_values(s.log_nref);
 metrics(k,:)=[sqrt(mean(e(ix).^2)),std(te(ix)),sqrt(mean(se(ix).^2))];
 archived=record.cases(k).metrics;assert(max(abs(metrics(k,:)-[archived.iq_true_tracking_rms_A archived.torque_std_Nm archived.speed_tracking_rms_rpm]))<1e-12);
end
physical={'obs_state','log_iq_ref','log_Te','log_speed','log_iabc_true','log_iabc_meas','log_Tcm_applied'};equalCount=0;
for field=physical,a=outputs{2}.(field{1});b=outputs{3}.(field{1});assert(isequaln(a.Time,b.Time)&&isequaln(a.Data,b.Data));equalCount=equalCount+1;end
report=struct('source_folder',folder,'source_record_sha256',latest.record_sha256,'model_sha256',record.model_sha256,...
 'labels',{labels},'statistics_window_s',window,'metrics',metrics,'events',events,'boundary_late_equal_physical_signals',equalCount,...
 'scope','同事件架构、同62.5ns网格与原PI；仅计算耗时不同。边界同拍按UEV先处理的模型约定，不是实板边界裕量保证。');
fig=figure('Name','PWM更新与闭环 · 已保存实验','NumberTitle','off','Color','white','Position',[80 60 1120 800],...
 'Tag','PMSMTimingFeedback','UserData',report);
g=tiledlayout(fig,3,2,'Padding','compact','TileSpacing','compact');title(g,'PWM更新与闭环');colors=[.5 .5 .5;0 .447 .741;.84 .15 .16];
nexttile(g);hold on;
for k=1:3
 v=traces{k};ix=v.time_us>=0&v.time_us<=100;w=ix&v.pwm(:,4)>.5;u=ix&v.pwm(:,5)>.5;
 handleVisibility='off';if k==1,handleVisibility='on';end
 plot(v.time_us(w),k*ones(nnz(w),1),'o','Color',colors(k,:),'MarkerSize',6,'DisplayName','写入','HandleVisibility',handleVisibility,'Tag',sprintf('timing_write_%d',k));
 plot(v.time_us(u),k*ones(nnz(u),1),'s','Color',colors(k,:),'MarkerFaceColor',colors(k,:),'MarkerSize',6,'DisplayName','生效','HandleVisibility',handleVisibility,'Tag',sprintf('timing_apply_%d',k));
end
for phase=[25 50 75 100],xline(phase,':','Color',[.6 .6 .6],'HandleVisibility','off');end
yticks(1:3);yticklabels(labels);ylim([.5 3.5]);xlim([0 100]);xlabel('相对时间 [μs]');frame('CCR写入与生效','');
eventAxis=gca;nexttile(g);hold on;
for k=1:3
 v=traces{k};ix=v.time_us>=0&v.time_us<=100;
 ln=stairs(v.time_us(ix),v.pwm(ix,7),'Color',colors(k,:),'LineWidth',1.2,'DisplayName',labels{k},'Tag',sprintf('timing_sequence_%d',k));if k==1,ln.LineStyle='--';end
end
frame('生效指令序号','序号');xlabel('相对时间 [μs]');xlim([0 100]);linkaxes([eventAxis gca],'x');
axesTime=gobjects(1,4);titles={'d轴真实电流','q轴跟踪误差','转矩','转速'};units={'A','A','N·m','rpm'};
for panel=1:4
 axesTime(panel)=nexttile(g);hold on;
 for k=1:3
  s=outputs{k};t=s.log_Te.Time;ix=t>=window(1)&t<=window(2);state=teach_values(s.obs_state);
  switch panel
   case 1,y=state(:,1);
   case 2,y=state(:,2)-teach_values(s.log_iq_ref);
   case 3,y=teach_values(s.log_Te);
   case 4,y=teach_values(s.log_speed);
  end
  ln=plot(t(ix)*1000,y(ix),'Color',colors(k,:),'LineWidth',1.1,'DisplayName',labels{k},'Tag',sprintf('timing_response_%d_case_%d',panel,k));if k==1,ln.LineStyle='--';end
 end
 if panel~=2
  fields={'obs_id_ref','','log_TL','log_nref'};y=teach_values(outputs{1}.(fields{panel}));label='给定';if panel==3,label='负载';end
  plot(t(ix)*1000,y(ix),':','Color',[.35 .35 .35],'DisplayName',label,'Tag',sprintf('timing_reference_%d',panel));
 end
 frame(titles{panel},units{panel});xlabel('时间 [ms]');xlim(window*1000);
end
linkaxes(axesTime,'x');pmsm_sampling_comparison_menu(fig);uimenu(fig,'Text','指标与工况','MenuSelectedFcn',@(~,~)info(report));
uimenu(fig,'Text','滤波与时序','Tag','PMSMTimingFilterEntry','MenuSelectedFcn',@(~,~)combined);
 function frame(name,unit)
  title(name);ylabel(unit);grid on;ax=gca;ax.FontSize=11;legend('show','Location','best');
 end
end
function combined
try
 existing=findall(groot,'Type','figure','Tag','PMSMTimingFilter');
 if isempty(existing),open_pmsm_timing_filter;else,figure(existing(1));end
catch err,errordlg(err.message,'组合对比未打开');end
end
function info(r)
f=figure('Name','PWM更新指标 · 已保存实验','NumberTitle','off','Color','white','MenuBar','none','ToolBar','none','Position',[160 140 950 440]);
data=cell(6,4);names={'CCR写入相位 [μs]','CCR生效相位 [μs]','JEOS至生效 [μs]','真实iq跟踪RMS [A]','转矩标准差 [N·m]','转速跟踪RMS [rpm]'};
values=[[r.events.cases.write_phase_us];[r.events.cases.apply_phase_us];[r.events.cases.jeos_to_apply_us];r.metrics'];
for j=1:6,data(j,:)=[names(j) arrayfun(@(v)sprintf('%.6f',v),values(j,:),'UniformOutput',false)];end
uitable(f,'Data',data,'ColumnName',[{'指标'} r.labels],'RowName',[],'FontSize',14,'ColumnWidth',{290 190 190 190},'Units','normalized','Position',[.03 .47 .94 .5]);
uicontrol(f,'Style','text','BackgroundColor','white','FontSize',14,'HorizontalAlignment','left','Units','normalized','Position',[.03 .02 .94 .42],...
 'String',{'3000 rpm、24 V、0.207 N·m；原PI、零初态、理想桥。',...
 '三组同一事件架构：20 kHz PWM，峰谷双更新，10 μs触发。',...
 'JEOS为14.5 μs；仅计算耗时不同；旧整拍延迟等因素关闭。',...
 '10.5与15 μs在同一更新生效，所核对物理波形逐点一致。',...
 '事件为末两个PWM周期，响应和指标取180～200 ms、50 μs记录。',...
 '同拍UEV先于CCR写入是模型约定；末段指标不是全带宽纹波。'});
end
