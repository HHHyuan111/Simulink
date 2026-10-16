function plot_pmsm_measurement_lesson
% Rebuild the measurement overview from verified gallery source records.
here=fileparts(mfilename('fullpath'));ids={'current_bias','current_noise','sample_delay'};
s=cell(1,3);r=cell(1,3);provenance=struct;
for k=1:3
 summary=jsondecode(fileread(fullfile(here,'experiments','examples',ids{k},'summary.json')));folder=summary.source_run_folder;
 record=pmsm_experiment_verify(folder);a=load(fullfile(folder,'factor.mat'),'signals');s{k}=a.signals;
 a=load(fullfile(folder,'reference.mat'),'signals');r{k}=a.signals;
 provenance.(ids{k})=struct('source_run_id',record.id,'record_sha256',teach_hash(fullfile(folder,'record.json')), ...
  'factor_value',record.factor_value,'factor_unit',record.factor_unit);
end
f=figure('Visible','off','Color','white','Position',[30 30 1280 850]);g=onCleanup(@()close(f));
set(f,'DefaultTextInterpreter','none','DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei');
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');c=[.10 .40 .72;.91 .35 .12;.14 .57 .37];
for k=1:2
 nexttile;hold on;t=s{k}.log_iabc_meas.Time;err=teach_values(s{k}.log_iabc_meas)-teach_values(s{k}.log_iabc_true);ix=t>=t(end)-.004;
 for phase=1:3,stairs(t(ix)*1000,err(ix,phase),'Color',c(phase,:),'LineWidth',1.1);end
 grid on;xlim([t(end)-.004 t(end)]*1000);xlabel('时间 [ms]');ylabel('电流误差 [A]');legend('A','B','C');
 names={'电流零偏','采样噪声'};title(names{k});
 if k==1,lo=min(err(ix,:),[],'all');hi=max(err(ix,:),[],'all');pad=max(.01,(hi-lo)*.15);ylim([lo-pad hi+pad]);end
 tail=t>=t(end)-.02;provenance.(ids{k}).tail_measurement_mean_error_A=mean(err(tail,:),1);
 provenance.(ids{k}).tail_measurement_rms_error_A=sqrt(mean(err(tail,:).^2,1));
end
nexttile;hold on;tf=s{3}.obs_current_fast.Time;fast=teach_values(s{3}.obs_current_fast);ix=tf>=tf(end)-.004;
plot(tf(ix)*1000,fast(ix,1),'Color',[.2 .24 .29],'LineWidth',1);
t=s{3}.log_iabc_meas.Time;m=teach_values(s{3}.log_iabc_meas);ix=t>=t(end)-.004;
stairs(t(ix)*1000,m(ix,1),'Color',c(2,:),'LineWidth',1.2);grid on;xlim([t(end)-.004 t(end)]*1000);
title('A相电流');xlabel('时间 [ms]');ylabel('电流 [A]');legend('真实','测量');
nexttile;hold on;states=teach_values(s{3}.obs_state);ref=teach_values(r{3}.obs_state);measured=teach_values(s{3}.log_id);ix=t>=t(end)-.02;
plot(t(ix)*1000,ref(ix,1),'Color',c(1,:));plot(t(ix)*1000,states(ix,1),'Color',c(2,:));plot(t(ix)*1000,measured(ix),'Color',[.48 .22 .64]);
yline(0,'k--');grid on;xlim([t(end)-.02 t(end)]*1000);title('d轴电流');xlabel('时间 [ms]');ylabel('电流 [A]');
legend('参考真值','实验真值','实验反馈','给定');
provenance.sample_delay.tail_true_id_mean_A=mean(states(ix,1));provenance.sample_delay.tail_measured_id_mean_A=mean(measured(ix));
provenance.sample_delay.tail_reference_id_mean_A=mean(ref(ix,1));provenance.statistics_window_s=[t(end)-.02 t(end)];
sgtitle('电流测量','FontSize',14);pmsm_plot_style(f);out=fullfile(here,'experiments','examples','measurement_lesson');
if ~isfolder(out),mkdir(out);end
exportgraphics(f,fullfile(out,'measurement_chain.png'),'Resolution',140);
provenance.renderer_sha256=teach_hash(mfilename('fullpath')+".m");provenance.style_sha256=teach_hash(fullfile(here,'pmsm_plot_style.m'));
provenance.figure_sha256=teach_hash(fullfile(out,'measurement_chain.png'));teach_writejson(fullfile(out,'provenance.json'),provenance);
fprintf('MEASUREMENT_LESSON_RENDERED\n');
end
