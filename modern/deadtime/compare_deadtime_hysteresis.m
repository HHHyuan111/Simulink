function compare_deadtime_hysteresis
% One-factor experiment with existing knobs, on the current canonical model.
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);addpath(fullfile(root,'teaching'));
mdl='PMSM_FOC_R2026a';file=fullfile(root,[mdl '.slx']);load_system(file);guard=onCleanup(@()close_system(mdl,0));
hash=teach_hash(file);before=teach_snapshot(mdl);mw=get_param(mdl,'ModelWorkspace');code=mw.MATLABCode;settings=teach_settings(mdl);
work=fullfile(root,'.build','deadtime_hysteresis');if ~isfolder(work),mkdir(work);end
report=fullfile(folder,'report_hysteresis');if ~isfolder(report),mkdir(report);end
record=struct('model_sha256',hash,'model_changed',false,'pi_retuned',false,'dead_us',2,'comp_us',2,'cases',struct);
record.reference=check_low_deadtime_reference;
cases={'low_h005',300,.08,.14,.005;'low_h0',300,.08,.14,0;'normal_h005',600,.207,.08,.005};
for k=1:size(cases,1)
 key=cases{k,1};options=struct('rpm',cases{k,2},'load_Nm',cases{k,3},'hysteresis_A',cases{k,5},'aligned_current_logs',true);
 fprintf('HYSTERESIS_BEGIN %s h=%g\n',key,options.hysteresis_A);tic;o=run_deadtime_case(mdl,2,'on',cases{k,4},1,options);elapsed=toc;
 for v=o.who',a=o.get(v{1});if isa(a,'timeseries'),assert(all(isfinite(a.Data),'all'),'Nonfinite %s',v{1});end,end
 [r,w]=deadtime_metrics(o);tc=o.obs_dead_comp.Time;c=teach_values(o.obs_dead_comp);keep=tc>=r.analysis_start_s & tc<=r.analysis_end_s;r.polarity_reversals_ABC=sum(abs(diff(c(keep,6:8)))>1,1);
 r.hysteresis_A=options.hysteresis_A;r.rpm=options.rpm;r.load_Nm=options.load_Nm;r.elapsed_s=elapsed;
 assert(isequal(tc,o.log_iabc_meas.Time),'Measured log must use actual compensation task timestamps');
 mi=teach_values(o.log_iabc_meas);pk=c(:,6:8);last=zeros(1,3);for j=1:numel(tc),last(mi(j,:)>options.hysteresis_A)=1;last(mi(j,:)<-options.hysteresis_A)=-1;assert(isequal(last,pk(j,:)),'Measured current log does not reproduce compensation polarity at t=%g',tc(j));end
 r.measured_input_replays_polarity=true;record.cases.(key)=r;save(fullfile(work,[key '.mat']),'o','w','r','options','hash','-v7.3');clear o;
 reload(mw);assert(strcmp(code,mw.MATLABCode)&&isequaln(before,teach_snapshot(mdl))&&isequaln(settings,teach_settings(mdl)));
 teach_writejson(fullfile(report,'results.json'),record);fprintf('HYSTERESIS_RESULT %s THD=%g flips=%s runtime=%g\n',key,r.low_order_THD_percent,mat2str(r.polarity_reversals_ABC),elapsed);
end
assert(strcmp(hash,teach_hash(file)));record.all_passed=true;teach_writejson(fullfile(report,'results.json'),record);
plotCompare(work,folder,report);fprintf('HYSTERESIS_ALL_PASS\n');
end
function plotCompare(work,folder,report)
s=load(fullfile(fileparts(folder),'.build','deadtime_demo','comp.mat'),'o');[r0,w0]=deadtime_metrics(s.o);
names={'low_h005','low_h0'};r={r0};w={w0};for k=1:2,s=load(fullfile(work,[names{k} '.mat']),'r','w');r{k+1}=s.r;w{k+1}=s.w;end
f=figure('Visible','off','Color','white','Position',[30 30 1550 880]);tiledlayout(2,3,'TileSpacing','compact');
labels={'原滞环 ±0.05A','滞环 ±0.005A','滞环 0A（噪声关闭的对照）'};
lim=1.12*max(cellfun(@(x)max(abs(x.current_ABC_A),[],'all'),w));
cross=find(w0.current_ABC_A(1:end-1,1)<=0 & w0.current_ABC_A(2:end,1)>0)+1;span=w0.time_s(cross(end))+[-.002 .002];
for k=1:3
 nexttile(k);plot(w{k}.time_s*1e3,w{k}.current_ABC_A,'LineWidth',1.1);grid on;xlim([w0.time_s(1) w0.time_s(end)]*1e3);ylim([-lim lim]);ylabel('三相电流 [A]');xlabel('时间 [ms]');title(sprintf('%s · THD %.3f%%',labels{k},r{k}.low_order_THD_percent));legend('A','B','C','Location','best');
 nexttile(k+3);plot(w{k}.time_s*1e3,w{k}.current_ABC_A(:,1),'b','LineWidth',1.5);grid on;xlim(span*1e3);ylim([-lim lim]);ylabel('A相过零 [A]');xlabel('时间 [ms]');title('相同坐标，PWM周期平均电流');
end
sgtitle('只改变补偿电流滞环 · 2μs死区/2μs补偿 · 300rpm/0.08N·m · 同一PI，噪声关闭');exportgraphics(f,fullfile(report,'hysteresis_comparison.png'),'Resolution',140);close(f);
end
