function diagnose_deadtime_zero
% Read existing closed-loop recordings. No model is loaded or changed.
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);addpath(fullfile(root,'teaching'));
report=fullfile(folder,'report_zero_diagnosis');if ~isfolder(report),mkdir(report);end
cases={'.build/deadtime_stage','reference_05us',.5,600,.207;'.build/deadtime_demo','low_speed_2us',2,300,.08};
record=struct('model_changed',false,'pi_retuned',false,'cases',struct);
for k=1:size(cases,1)
 work=fullfile(root,cases{k,1});s=load(fullfile(work,'comp.mat'),'o');o=s.o;[m,w]=deadtime_metrics(o);
 tc=o.obs_dead_comp.Time;c=teach_values(o.obs_dead_comp);tf=o.obs_current_fast.Time;i=teach_values(o.obs_current_fast);
 p=c(:,6:8);keep=tc>=m.analysis_start_s & tc<=m.analysis_end_s;
 instantaneous=interp1(tf,i,tc,'linear');averaged=interp1(w.time_s,w.current_ABC_A,tc,'linear',NaN);
 flip=sum(abs(diff(p(keep,:)))>1,1);
 valid=keep & all(isfinite(averaged),2);far=abs(averaged)>.1;
 mismatch=mean((p(valid,:)~=sign(averaged(valid,:))) & far(valid,:),1);
 pt=o.obs_pwm_timing.Time;pv=teach_values(o.obs_pwm_timing);latch=pv(:,5)>0;delays=unique(round(pv(latch,9)*1e9)/1e3);
 % Find a clean rising crossing of the period-averaged reference trace.
 cross=find(w.current_ABC_A(1:end-1,1)<=0 & w.current_ABC_A(2:end,1)>0)+1;assert(~isempty(cross));center=w.time_s(cross(end));span=center+[-.0015 .0015];
 f=figure('Visible','off','Color','white','Position',[30 30 1350 1050]);tiledlayout(4,1,'TileSpacing','compact');
 nexttile;plot(tf*1e3,i(:,1),'Color',[.72 .77 .84]);hold on;plot(w.time_s*1e3,w.current_ABC_A(:,1),'b','LineWidth',1.6);yline(0,'k:');grid on;ylabel('A');title('A相：瞬时真电流与PWM周期平均电流');legend('瞬时电流（含开关纹波）','周期平均电流','Location','best');xlim(span*1e3);
 nexttile;stairs(tc*1e3,p(:,1),'r','LineWidth',1.4);hold on;stairs(tc*1e3,sign(averaged(:,1)),'k--');grid on;ylim([-1.3 1.3]);yticks([-1 0 1]);ylabel('极性');title('控制器实际采用的极性；黑线仅为离线诊断参考，不接入控制器');legend('实际补偿极性','周期平均电流方向','Location','best');xlim(span*1e3);
 nexttile;stairs(tc*1e3,c(:,1:3),'LineWidth',1.1);grid on;ylabel('V');title('实际abc补偿电压：去共模后');legend('A','B','C','Location','best');xlim(span*1e3);
 nexttile;stairs(tc*1e3,c(:,4:5),'LineWidth',1.1);grid on;ylabel('V');xlabel('时间 [ms]');title('实际dq补偿电压：进入最终限压前');legend('d','q','Location','best');xlim(span*1e3);
 sgtitle(sprintf('过零诊断 · %gμs / %grpm / %.3gN·m · 原记录重分析，未改算法',cases{k,3},cases{k,4},cases{k,5}));exportgraphics(f,fullfile(report,[cases{k,2} '.png']),'Resolution',140);close(f);
 r=struct('dead_us',cases{k,3},'rpm',cases{k,4},'load_Nm',cases{k,5},'low_order_THD_percent',m.low_order_THD_percent,'analysis_window_s',[m.analysis_start_s m.analysis_end_s],'polarity_reversals_ABC',flip,'expected_for_two_clean_cycles',4,'mismatch_fraction_excluding_abs_mean_current_below_01A',mismatch,'JEOS_to_latch_us_tail',delays,'source_mat_sha256',teach_hash(fullfile(work,'comp.mat')),'note','Period mean is an offline diagnostic only; mismatch fraction denominator is all valid control samples, with near-zero numerator excluded. Existing measured-current logs are not assumed synchronous with the compensation task.');
 record.cases.(cases{k,2})=r;fprintf('ZERO_DIAG %s flips=%s THD=%g latch_us=%s\n',cases{k,2},mat2str(flip),m.low_order_THD_percent,mat2str(delays));
end
teach_writejson(fullfile(report,'results.json'),record);
end
