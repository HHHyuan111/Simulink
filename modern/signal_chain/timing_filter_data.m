function [outputs,report]=timing_filter_data
root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'teaching'));
latest=jsondecode(fileread(fullfile(root,'signal_chain','timing_filter','latest.json')));folder=latest.folder;
assert(latest.passed&&strcmp(latest.record_sha256,teach_hash(fullfile(folder,'record.json'))));r=jsondecode(fileread(fullfile(folder,'record.json')));assert(r.passed&&r.duration_s==.2&&r.filter_hz==1500);
assert(strcmp(r.numerical_source_sha256,teach_hash(fullfile(folder,r.numerical_source_file))));
assert(strcmp(r.model_sha256,teach_hash(fullfile(root,'PMSM_FOC_R2026a.slx')))&&strcmp(r.reference_manifest_sha256,teach_hash(fullfile(root,'teaching','reference_v1','manifest.json'))));
for item=r.files(:)',assert(strcmp(item.sha256,teach_hash(fullfile(folder,item.path))));end
assert(strcmp(r.unfiltered_record_sha256,teach_hash(fullfile(r.unfiltered_folder,'record.json'))));old=pmsm_experiment_verify(r.unfiltered_folder);assert(strcmp(old.model_sha256,r.model_sha256)&&strcmp(old.baseline_manifest_sha256,r.reference_manifest_sha256));
outputs=cell(1,4);configs=cell(1,4);sourceIndex=[1 3];
for k=1:2
 s=load(fullfile(r.unfiltered_folder,[old.cases(sourceIndex(k)).id '.mat']),'signals');outputs{k}=s.signals;configs{k}=old.cases(sourceIndex(k)).configuration;
 s=load(fullfile(folder,r.cases(k).file),'signals');outputs{k+2}=s.signals;configs{k+2}=r.cases(k).configuration;
end
normalized=cell(1,4);for k=1:4
 normalized{k}=configs{k};
 normalized{k}=setcfg(normalized{k},'时序设置','compute_us','5');normalized{k}=setcfg(normalized{k},'采样设置','filter_on','off');normalized{k}=setcfg(normalized{k},'采样设置','filter_hz','1500');
 assert(isequaln(normalized{1},normalized{k}),'四组含其他配置差异。');pmsm_check_switches(configs{k});
end
compute=[5 15 5 15];filtered=[false false true true];h=62.5e-9;window=[.18 .2];metrics=zeros(4,3);equations=zeros(4,2);events=zeros(4,3);matched=zeros(1,4);captureErrors=zeros(4,3);
for k=1:4
 s=outputs{k};t=s.log_Te.Time;assert(isequal(t,outputs{1}.log_Te.Time,s.obs_state.Time,s.log_iq_ref.Time,s.log_iabc_true.Time,s.log_iabc_meas.Time,s.log_iabc_adc.Time,s.log_iabc_filter.Time,s.log_speed.Time,s.log_nref.Time,s.log_TL.Time));
 assert(isequal(s.log_nref.Data,outputs{1}.log_nref.Data)&&isequal(s.log_TL.Data,outputs{1}.log_TL.Data));
 assert(all(teach_values(s.log_nref)==3000)&&all(abs(teach_values(s.log_TL)-.207)<1e-12));
 adc=teach_values(s.log_iabc_adc);v=teach_values(s.log_iabc_filter);meas=teach_values(s.log_iabc_meas);expected=adc;
 if filtered(k),a=exp(-2*pi*1500*50e-6);expected=filter(1-a,[1 -a],adc);end
 equations(k,:)=[max(abs(v-expected),[],'all') max(abs(meas-v),[],'all')];assert(max(equations(k,:))<1e-9);
 tt=s.obs_pwm_timing.Time;ticks=round(tt/h);p=teach_values(s.obs_pwm_timing);d=teach_values(s.obs_adc_timing);assert(isequal(tt,s.obs_adc_timing.Time));
 write=232+round(compute(k)*1e-6/h);latch=(floor(write/400)+1)*400;w=find(p(:,4)>.5);u=find(p(:,5)>.5);j=find(d(:,6)>.5);
 assert(numel(w)>=3&&numel(u)>=3&&numel(j)>=3&&all(mod(ticks(w),800)==write)&&all(mod(ticks(u),800)==mod(latch,800))&&all(mod(ticks(j),800)==232));
 assert(max(abs(p(u,9)-(latch-232)*h))<1e-12);
 [found,where]=ismember(ticks(j),round(s.log_iabc_adc.Time/h));assert(all(found)&&max(abs(adc(where,:)-d(j,10:12)),[],'all')<1e-10);
 fastTicks=round(s.obs_current_fast.Time/h);truth=teach_values(s.obs_current_fast);
 for phase=1:3
  sampleTicks=floor(ticks(j)/800)*800+160+(3-phase)*24+19;[found,where]=ismember(sampleTicks,fastTicks);assert(all(found));
  captureErrors(k,phase)=max(abs(d(j,phase+9)-truth(where,phase)));assert(captureErrors(k,phase)<1e-8);
 end
 [found,where]=ismember(ticks,round(s.log_Tcm_applied.Time/h));assert(all(found));actual=teach_values(s.log_Tcm_applied);actual=actual(where,:);
 for iw=w(:)'
  sequence=p(iw,6);active=p(:,7)==sequence;if ~any(active),continue;end
  assert(max(abs(actual(active,:)-p(iw,10:12)),[],'all')<1e-14);matched(k)=matched(k)+1;
 end
 assert(matched(k)>=2);events(k,:)=[write latch latch-232]*h*1e6;
 ix=t>=window(1)&t<=window(2);state=teach_values(s.obs_state);e=state(:,2)-teach_values(s.log_iq_ref);te=teach_values(s.log_Te);se=teach_values(s.log_speed)-teach_values(s.log_nref);
 metrics(k,:)=[sqrt(mean(e(ix).^2)),std(te(ix)),sqrt(mean(se(ix).^2))];
end
for k=1:2,archived=old.cases(sourceIndex(k)).metrics;assert(max(abs(metrics(k,:)-[archived.iq_true_tracking_rms_A archived.torque_std_Nm archived.speed_tracking_rms_rpm]))<1e-12);end
report=r;report.record_sha256=latest.record_sha256;report.configurations=configs;report.metrics=metrics;report.filter_equation_errors=equations;report.events_us=events;report.matched_command_counts=matched;report.adc_capture_errors_ABC_A=captureErrors;
report.labels={'计算5 μs·滤波关','计算15 μs·滤波关','计算5 μs·滤波开','计算15 μs·滤波开'};
report.scope='四组同真实事件架构、原PI、同网格；比较计算5/15μs与1500Hz abc数字低通开关。差值含各自闭环轨迹变化，不是纯测量延迟或独立噪声分量。';
end
function c=setcfg(c,section,key,value)
i=find(strcmp({c.rows.section},section)&strcmp({c.rows.key},key));assert(isscalar(i));c.rows(i).value=value;
end
