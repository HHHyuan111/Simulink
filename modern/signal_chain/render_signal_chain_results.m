function report=render_signal_chain_results
% Concise result figures from the actual, validated 20-case simulation audit.
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'teaching'));
rawPath=fullfile(root,'.build','signal_chain','audit_runs.mat');a=load(rawPath,'out','cases','report');
assert(a.report.passed&&numel(a.cases)==20);
assert(strcmp(a.report.model_sha256,teach_hash(fullfile(root,'PMSM_FOC_R2026a.slx'))));
target=fullfile(root,'signal_chain','results');if ~isfolder(target),mkdir(target);end
blue=[0 .447 .741];red=[.84 .15 .16];
f=figure('Color','white','Name','采样参数对比','NumberTitle','off','Position',[80 60 1120 800]);
g=tiledlayout(f,2,2,'TileSpacing','compact','Padding','compact');title(g,'采样参数对比');axesTime=gobjects(1,4);
axesTime(1)=nexttile(g);hold on;
for k=1:2
 s=caseOutput({'noise_small','noise_large'},k);v=teach_values(s.log_iabc_noise);
 plot(s.log_iabc_noise.Time*1000,v(:,1),'Color',color(k),'LineWidth',1.1,'DisplayName',sprintf('%.2f A RMS',.02*k));
end
frame('噪声幅值');
axesTime(2)=nexttile(g);hold on;
for k=1:2
 s=caseOutput({'filter500','filter2000'},k);x=teach_values(s.log_iabc_adc);y=teach_values(s.log_iabc_filter);
 labels={'500 Hz','2000 Hz'};plot(s.log_iabc_filter.Time*1000,y(:,1)-x(:,1),'Color',color(k),'LineWidth',1.1,'DisplayName',labels{k});
end
frame('滤波输出−输入');
for k=1:2
 s=caseOutput({'delay1','delay2'},k);x=teach_values(s.log_iabc_filter);y=teach_values(s.log_iabc_meas);
 axesTime(k+2)=nexttile(g);hold on;
 stairs(s.log_iabc_filter.Time*1000,x(:,1),'Color',blue,'LineWidth',1.1,'DisplayName','延迟前');
 stairs(s.log_iabc_meas.Time*1000,y(:,1),'Color',red,'LineWidth',1.1,'DisplayName','延迟后');
 frame(sprintf('%d拍采样延迟',k));
end
linkaxes(axesTime,'x');exportgraphics(f,fullfile(target,'sampling.png'),'Resolution',160);savefig(f,fullfile(target,'sampling.fig'));close(f);
f=figure('Color','white','Name','PWM写入与生效','NumberTitle','off','Position',[80 60 1120 500]);
g=tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');title(g,'PWM写入与生效');
eventMetrics=zeros(2,3);
for k=1:2
 s=caseOutput({'early_fast','early_slow'},k);t=s.obs_pwm_timing.Time;d=teach_values(s.obs_pwm_timing);keep=t<=.0004;
 ax=nexttile(g);hold(ax,'on');
 stairs(ax,t(keep)*1e6,d(keep,6),'Color',blue,'LineWidth',1.2,'DisplayName','已写入');
 stairs(ax,t(keep)*1e6,d(keep,7),'Color',red,'LineWidth',1.2,'DisplayName','已生效');
 compute=[5 15];title(ax,sprintf('计算 %d μs',compute(k)));xlabel(ax,'时间 [μs]');ylabel(ax,'指令序号');
 grid(ax,'on');legend(ax,'show','Location','northwest');ax.FontSize=12;xlim(ax,[0 400]);
 writes=t(d(:,4)>.5);latches=t(d(:,5)>.5);delay=d(d(:,5)>.5,9);
 eventMetrics(k,:)=[writes(1),latches(1),delay(1)]*1e6;
end
assert(max(abs(eventMetrics-[19.5 25 10.5;29.5 50 35.5]),[],'all')<1e-8);
exportgraphics(f,fullfile(target,'timing.png'),'Resolution',160);savefig(f,fullfile(target,'timing.fig'));close(f);
report=struct('source','已完成的20组各2ms仿真，本次只整理显示','raw_mat_sha256',teach_hash(rawPath),...
 'model_sha256',a.report.model_sha256,'sampling_cases',{{'noise_small','noise_large','filter500','filter2000','delay1','delay2'}},...
 'timing_cases',{{'early_fast','early_slow'}},'first_write_latch_jeos_delay_us',eventMetrics,...
 'definition','A相；每组自己的实际记录。滤波输出减自身输入；延迟前后来自同组。噪声固定同种子。时序两组触发10us、JEOS14.5us、峰谷双更新。无插值或平滑。');
teach_writejson(fullfile(target,'source.json'),report);disp('SIGNAL_CHAIN_RESULTS_READY');
 function s=caseOutput(ids,k)
  ix=find(cellfun(@(c)strcmp(c.id,ids{k}),a.cases));assert(isscalar(ix));s=a.out{ix};
 end
 function c=color(k)
  if k==1,c=blue;else,c=red;end
 end
 function frame(name)
  title(name);xlabel('时间 [ms]');ylabel('A');grid on;legend('show','Location','best');ax=gca;ax.FontSize=12;xlim([0 2]);
 end
end
