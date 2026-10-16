function [fig,report]=open_pmsm_feedback_effects(kind)
% Same-baseline archived comparisons at two existing parameter magnitudes.
assert(ismember(kind,{'delay','filter'}));here=fileparts(mfilename('fullpath'));root=fileparts(here);
latest=jsondecode(fileread(fullfile(root,'signal_chain','feedback_effects_latest.json')));assert(latest.passed);
if strcmp(kind,'delay')
 scenario='sample_delay';folder=latest.delay2_folder;expectedHash=latest.delay2_record_sha256;labels={'参考','1拍','2拍'};theme='采样延迟';
else
 scenario='digital_filter';folder=latest.filter500_folder;expectedHash=latest.filter500_record_sha256;labels={'参考','1500 Hz','500 Hz'};theme='数字滤波';
end
assert(strcmp(expectedHash,teach_hash(fullfile(folder,'record.json'))));new=pmsm_experiment_verify(folder);
oldSummary=jsondecode(fileread(fullfile(here,'experiments','examples',scenario,'summary.json')));
oldFolder=fullfile(here,'experiments','runs',oldSummary.source_run_id);old=pmsm_experiment_verify(oldFolder);
assert(strcmp(oldSummary.source_record_sha256,teach_hash(fullfile(oldFolder,'record.json'))));
modelHash=teach_hash(fullfile(root,'PMSM_FOC_R2026a.slx'));
assert(strcmp(new.model_sha256,modelHash)&&strcmp(old.model_sha256,modelHash));
assert(strcmp(old.scenario.id,scenario)&&strcmp(new.scenario.id,scenario)&&old.duration_s==.2&&new.duration_s==.2);
if strcmp(kind,'delay'),assert(old.factor_value==1&&new.factor_value==2);else,assert(old.factor_value==1500&&new.factor_value==500);end
assert(strcmp(old.baseline_state_sha256,new.baseline_state_sha256)&&strcmp(old.baseline_manifest_sha256,new.baseline_manifest_sha256));
nr=load(fullfile(folder,'reference.mat'),'signals');or=load(fullfile(oldFolder,'reference.mat'),'signals');
baselineChecks=0;for key=fieldnames(nr.signals)'
 a=nr.signals.(key{1});b=or.signals.(key{1});assert(isequaln(a.Time,b.Time)&&isequaln(a.Data,b.Data),'新旧参考未严格复现：%s',key{1});baselineChecks=baselineChecks+1;
end
o=load(fullfile(oldFolder,'factor.mat'),'signals');n=load(fullfile(folder,'factor.mat'),'signals');outputs={nr.signals,o.signals,n.signals};
window=[.18 .2];metrics=zeros(3,3);records={new,old,new};indices=[1 2 2];
for k=1:3
 s=outputs{k};t=s.log_Te.Time;assert(isequal(t,s.obs_state.Time,s.log_iq_ref.Time,s.log_speed.Time,s.log_nref.Time,s.log_iabc_meas.Time,s.log_iabc_true.Time));
 assert(isequal(t,outputs{1}.log_Te.Time)&&isequal(s.log_nref.Data,outputs{1}.log_nref.Data)&&isequal(s.log_TL.Data,outputs{1}.log_TL.Data));
 ix=t>=window(1)&t<=window(2);v=teach_values(s.obs_state);ref=teach_values(s.log_iq_ref);te=teach_values(s.log_Te);speedError=teach_values(s.log_nref)-teach_values(s.log_speed);
 metrics(k,:)=[sqrt(mean((v(ix,2)-ref(ix)).^2)),std(te(ix)),sqrt(mean(speedError(ix).^2))];
 archived=records{k}.cases(indices(k)).metrics;
 assert(max(abs(metrics(k,:)-[archived.iq_true_tracking_rms_A archived.torque_std_Nm archived.speed_tracking_rms_rpm]))<1e-12);
end
report=struct('kind',kind,'source_folders',{{oldFolder,folder}},'source_record_sha256',{{teach_hash(fullfile(oldFolder,'record.json')),expectedHash}},...
 'labels',{labels},'window_s',window,'metrics',metrics,'metric_names',{{'真实iq跟踪RMS [A]','转矩标准差 [N·m]','转速跟踪RMS [rpm]'}},...
 'baseline_exact_signal_count',baselineChecks,'model_sha256',modelHash,'definition','各组自身真值、反馈、给定；末20ms控制任务瞬时记录，不宣称稳态或PWM周期平均纹波。');
fig=figure('Name',[theme ' · 已保存实验'],'NumberTitle','off','Color','white','Position',[80 60 1120 800],...
 'Tag',['PMSMFeedbackEffects_' kind],'UserData',report);
g=tiledlayout(fig,2,3,'Padding','compact','TileSpacing','compact');title(g,theme);
colors=[.5 .5 .5;0 .447 .741;.84 .15 .16];axesTime=gobjects(1,6);
s=outputs{3};t=s.obs_current_fast.Time;keep=t>=window(1)&t<=window(2);v=teach_values(s.obs_current_fast);
axesTime(1)=nexttile(g);hold on;plot(t(keep)*1000,v(keep,1),'Color',colors(2,:),'DisplayName','真实','Tag','effect_A_true');
t=s.log_iabc_meas.Time;ix=t>=window(1)&t<=window(2);v=teach_values(s.log_iabc_meas);
stairs(t(ix)*1000,v(ix,1),'Color',colors(3,:),'DisplayName','反馈','Tag','effect_A_measured');frame(['A相电流 · ' labels{3}],'A');
titles={'d轴真实电流','q轴跟踪误差','A相测量误差','转矩','转速'};units={'A','A','A','N·m','rpm'};
for display=2:6
 axesTime(display)=nexttile(g);hold on;
 for k=1:3
  s=outputs{k};t=s.log_Te.Time;ix=t>=window(1)&t<=window(2);state=teach_values(s.obs_state);
  switch display
   case 2,y=state(:,1);
   case 3,y=state(:,2)-teach_values(s.log_iq_ref);
   case 4,y=teach_values(s.log_iabc_meas)-teach_values(s.log_iabc_true);y=y(:,1);
   case 5,y=teach_values(s.log_Te);
   case 6,y=teach_values(s.log_speed);
  end
  ln=plot(t(ix)*1000,y(ix),'Color',colors(k,:),'LineWidth',1.1,'DisplayName',labels{k},'Tag',sprintf('effect_display_%d_case_%d',display,k));
  if k==1,ln.LineStyle='--';end
 end
 if display==2,ref=teach_values(outputs{1}.obs_id_ref);reference('给定',ref);
 elseif display==5,ref=teach_values(outputs{1}.log_TL);reference('负载',ref);
 elseif display==6,ref=teach_values(outputs{1}.log_nref);reference('给定',ref);end
 frame(titles{display-1},units{display-1});
end
linkaxes(axesTime,'x');pmsm_sampling_comparison_menu(fig);uimenu(fig,'Text','指标与工况','MenuSelectedFcn',@(~,~)info(report));
 function frame(name,unit)
  title(name);ylabel(unit);xlabel('时间 [ms]');grid on;legend('show','Location','best');ax=gca;ax.FontSize=12;xlim(window*1000);
 end
 function reference(label,y)
  plot(t(ix)*1000,y(ix),':','Color',[.4 .4 .4],'DisplayName',label,'Tag',sprintf('effect_reference_%d',display));
 end
end
function info(r)
f=figure('Name','采样因素指标 · 已保存实验','NumberTitle','off','Color','white','MenuBar','none','ToolBar','none','Position',[180 140 900 320]);
data=cell(3,4);for k=1:3,data(k,:)=[r.metric_names(k) arrayfun(@(v)sprintf('%.6f',v),r.metrics(:,k)','UniformOutput',false)];end
uitable(f,'Data',data,'ColumnName',[{'指标'} r.labels],'RowName',[],'FontSize',14,'ColumnWidth',{260 170 170 170},'Units','normalized','Position',[.03 .46 .94 .5]);
uicontrol(f,'Style','text','BackgroundColor','white','FontSize',14,'HorizontalAlignment','left','Units','normalized','Position',[.03 .03 .94 .38],...
 'String',{'3000 rpm、24 V、0.207 N·m；同一原PI、理想桥、零初态。',...
 '仅改变所选采样因素；真实事件时序及其他非理想因素关闭。',...
 '电流真值1 μs；其他曲线及指标50 μs，取180～200 ms。',...
 '末段指标不代表全带宽纹波、稳定性或参数优化结论。'});
end
