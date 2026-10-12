function validate_timing_stage3
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);addpath(fullfile(root,'teaching'));
work=fullfile(root,'.build','timing_stage');mdl='PMSM_FOC_R2026a';file=fullfile(work,[mdl '.slx']);
record=struct('all_passed',false,'source_sha256',teach_hash(fullfile(work,'PMSM_FOC_before_timing.slx')),'model_sha256',teach_hash(file));
record.components=components;fprintf('TIMING_COMPONENTS_PASS\n');
load_system(file);g=onCleanup(@()close_system(mdl,0));before=load(fullfile(work,'before.mat'));now=teach_snapshot(mdl);
assert(isequaln(before.before.regions,now.regions));
for b=before.before.blocks,n=now.blocks(strcmp({now.blocks.sid},b.sid));assert(isscalar(n)&&strcmp(b.path,n.path)&&strcmp(b.type,n.type)&&isequal(b.position,n.position));end
record.preserved_blocks=numel(before.before.blocks);record.total_blocks=numel(now.blocks);record.root_blocks=numel(find_system(mdl,'SearchDepth',1,'Type','Block'));
mw=get_param(mdl,'ModelWorkspace');record.pi_gains=struct;
for key={'kp_w','ki_w','ks_w','kp_id','ki_id','ks_id','kp_iq','ki_iq','ks_iq'},record.pi_gains.(key{1})=getVariable(mw,key{1});end
prior=jsondecode(fileread(fullfile(root,'control','algorithm_stage2_results.json')));assert(isequaln(record.pi_gains,prior.pi_gains));
fprintf('TIMING_OFF_REGRESSION\n');in=Simulink.SimulationInput(mdl);in=in.setModelParameter('StopTime','.02');o=sim(in);old=load(fullfile(work,'baseline.mat'));count=0;
keys=old.baseline.who;save(fullfile(work,'off_probe.mat'),'o','-v7.3');
for ki=1:numel(keys)
 key=keys{ki};a=old.baseline.get(key);if ~isa(a,'timeseries'),continue;end
 b=o.get(key);assert(isequaln(a.Time,b.Time)&&isequaln(teach_values(a),teach_values(b)),'OFF regression changed %s',key);count=count+1;
end
record.off_identical_timeseries=count;save(fullfile(work,'off.mat'),'o','-v7.3');clear old o;
fprintf('TIMING_REAL_COMPILE\n');set_param([mdl '/时序设置'],'real_on','on');set_param(mdl,'SimulationCommand','update');
feval(mdl,[],[],[],'compile');record.compiled=struct;
try
 for row={'442','current',50e-6,28.875e-6;'438','speed',100e-6,78.875e-6;'240','svm',50e-6,28.875e-6}'
  st=get_param(Simulink.ID.getHandle([mdl ':' row{1}]),'CompiledSampleTime');if iscell(st),st=vertcat(st{:});end
  assert(all(abs(st(:,1)-row{3})<1e-12)&&all(abs(st(:,2)-row{4})<1e-12),'Unexpected execution rate/phase %s: %s',row{2},mat2str(st));record.compiled.(row{2})=st;
 end
catch e,feval(mdl,[],[],[],'term');rethrow(e);end
feval(mdl,[],[],[],'term');
% Check every recorded signal below. Forcing the native Inf/NaN diagnostic
% to error crashed R2026a Update 5 in a repeated variant simulation.
fprintf('TIMING_REAL_SHORT\n');in=Simulink.SimulationInput(mdl);in=in.setModelParameter('StopTime','.02');o=sim(in);record.real=checkRun(o);checkEvents(o);save(fullfile(work,'real.mat'),'o','-v7.3');clear o;
fprintf('TIMING_WINDOW_SHORT\n');set_param([mdl '/时序设置'],'window_on','on');o=sim(in);record.window=checkRun(o);checkEvents(o);save(fullfile(work,'window.mat'),'o','-v7.3');clear o;
fprintf('TIMING_WINDOW_HOLD_SHORT\n');set_param([mdl '/时序设置'],'invalid_hold_on','on');o=sim(in);record.window_hold=checkRun(o);save(fullfile(work,'window_hold.mat'),'o','-v7.3');clear o;
% A finer grid checks event times exactly and bounds trajectory sensitivity.
fprintf('TIMING_GRID_CONVERGENCE\n');set_param([mdl '/时序设置'],'window_on','off','invalid_hold_on','off','grid_divider','2');
in=Simulink.SimulationInput(mdl);in=in.setModelParameter('StopTime','.005');fine=sim(in);checkEvents(fine);
base=load(fullfile(work,'real.mat'),'o');a=base.o.log_speed;b=fine.log_speed;keep=a.Time<=b.Time(end)+1e-12;
av=teach_values(a);bv=teach_values(b);record.grid_speed_difference_rpm=max(abs(av(keep,:)-bv));assert(record.grid_speed_difference_rpm<1,'Grid sensitivity requires investigation.');
save(fullfile(work,'fine.mat'),'fine','-v7.3');clear fine base;
% Purposefully move the trigger later to expose low-side observation loss.
% All three stress comparisons use the same phase; it is not a firmware preset.
fprintf('TIMING_WINDOW_STRESS\n');set_param([mdl '/时序设置'],'grid_divider','1','trigger_us','31.25');
in=Simulink.SimulationInput(mdl);in=in.setModelParameter('StopTime','.01');o=sim(in);record.stress_reference=checkRun(o);save(fullfile(work,'stress_reference.mat'),'o','-v7.3');clear o;
set_param([mdl '/时序设置'],'window_on','on');o=sim(in);record.stress_window=checkRun(o);save(fullfile(work,'stress_window.mat'),'o','-v7.3');clear o;assert(any(record.stress_window.valid_fraction_ABC<.99));
set_param([mdl '/时序设置'],'invalid_hold_on','on');o=sim(in);record.stress_hold=checkRun(o);save(fullfile(work,'stress_hold.mat'),'o','-v7.3');clear o;
close_system(mdl,0);load_system(file);
% Contradictory switches must fail explicitly, rather than double-count delays.
for field={'pwm_on','window_on'}
 in=Simulink.SimulationInput(mdl);in=in.setModelParameter('StopTime','.0001');in=in.setBlockParameter([mdl '/时序设置'],field{1},'on');
 if strcmp(field{1},'pwm_on'),in=in.setBlockParameter([mdl '/时序设置'],'real_on','on');end
 failed=false;try,sim(in);catch,failed=true;end;assert(failed);record.(['reject_' field{1}])=true;
end
record.reloaded_preservation=isequaln(now,teach_snapshot(mdl));assert(record.reloaded_preservation);
record.complete_board_emulation=false;record.pi_retuned=false;record.trigger_phase_measured=false;record.compute_time_measured=false;
record.nonfinite_verification='Every logged timeseries checked; model diagnostic left at saved default after native diagnostic crash.';
record.all_passed=true;teach_writejson(fullfile(folder,'timing_stage3_results.json'),record);
fprintf('TIMING_ALL_PASS %s\n',record.model_sha256);
end

function r=components
clear timing_adc timing_pwm;
h=62.5e-9;Ts=50e-6;t=(0:round(200e-6/h))'*h;adc=[1 0 0 h Ts 24.375e-6 1.1875e-6 1.5e-6 0 0 2];
y=zeros(numel(t),3);d=zeros(numel(t),15);
for k=1:numel(t),[y(k,:),d(k,:)]=timing_adc(t(k),[1 2 -3]*1e6*max(t(k)-h,0),[0 1 0 1 0 1],adc);end
jeos=find(d(:,6)>0);expected=[28.5625 54.125 -76.6875];assert(max(abs(y(jeos(1),:)-expected))<1e-9);assert(all(y(1:jeos(1)-1,:)==0,'all'));
r.first_samples_ABC_A=y(jeos(1),:);r.first_sample_sum_A=sum(expected);r.jeos_times_s=t(jeos)';
clear timing_adc;adc(11)=4;
for k=1:numel(t),[~,d(k,:)]=timing_adc(t(k),[1 2 -3],[0 1 0 1 0 1],adc);end
assert(isequal(find(d(:,14)>0),jeos(4)));r.speed_event_respects_divider=true;adc(11)=2;
% An OFF interval inside C's aperture must invalidate C even if low-side is ON at hold.
clear timing_adc;adc(2)=1;
for k=1:numel(t)
 gates=[0 1 0 1 0 1];if t(k)>24.75e-6 && t(k)<25.125e-6,gates(6)=0;end
 [y(k,:),d(k,:)]=timing_adc(t(k),[1 2 -3],gates,adc);
end
assert(isequal(d(jeos(1),7:9),[1 1 0])&&isequal(y(jeos(1),:),[1 2 0]));r.whole_aperture_window_checked=true;
% Known-current first frame, unobservable C in the second: optional hold uses
% previous valid measurement, never motor truth or a future value.
clear timing_adc;adc(3)=1;
for k=1:numel(t)
 gates=[0 1 0 1 0 1];if t(k)>=50e-6 && t(k)<90e-6,gates(6)=0;end
 [y(k,:),d(k,:)]=timing_adc(t(k),[1 2 -3]*(1+floor(t(k)/Ts)),gates,adc);
end
assert(y(jeos(2),3)==-3&&d(jeos(2),9)==0);r.hold_uses_last_valid=true;
r.ccr_cases=struct('trigger_us',{},'compute_us',{},'mode',{},'first_write_us',{},'first_latch_us',{});
for row=[24.375 5 0;10 5 0;10 5 1;10 10.5 0;10 11 0]'
 clear timing_pwm;cfg=[1 h Ts row(1)*1e-6 1.1875e-6 1.5e-6 0 row(2)*1e-6 row(3) 4000];
 p=zeros(numel(t),12);z=zeros(numel(t),3);req=Ts/2*(1-[.2 .4 .6]);
 for k=1:numel(t),[z(k,:),p(k,:)]=timing_pwm(t(k),req,cfg);end
 w=t(find(p(:,4),1));u=t(find(p(:,5),1));expectedUEV=[50 25 50 50 50]*1e-6;idx=numel(r.ccr_cases)+1;
 assert(abs(u-expectedUEV(idx))<1e-12);assert(max(abs(z(find(p(:,5),1),:)-req))<1e-12);
 r.ccr_cases(end+1)=struct('trigger_us',row(1),'compute_us',row(2),'mode',row(3),'first_write_us',w*1e6,'first_latch_us',u*1e6);
end
r.write_at_boundary_waits_until_next_update=true;
end
function r=checkRun(o)
keys=o.who;
for k=1:numel(keys)
 signal=o.get(keys{k});if ~isa(signal,'timeseries'),continue;end
 assert(all(isfinite(signal.Time),'all')&&all(isfinite(signal.Data),'all'),'Nonfinite logged signal: %s',keys{k});
end
s=teach_values(o.log_speed);iq=teach_values(o.log_iq);a=teach_values(o.obs_adc_timing);p=teach_values(o.obs_pwm_timing);j=a(:,6)>0;
assert(all(isfinite(s))&&all(isfinite(iq))&&max(abs(iq))<50);assert(nnz(j)>10);
assert(all(ismember(a(:,7:9),[0 1]),'all'));codes=teach_values(o.obs_adc_codes);assert(all(codes>=0&codes<=4095&codes==round(codes),'all'));
r=struct('stop_time_s',o.log_speed.Time(end),'speed_end_rpm',s(end),'iq_peak_A',max(abs(iq)), ...
 'true_phase_current_peak_A',max(abs(teach_values(o.obs_current_fast)),[],'all'), ...
 'valid_fraction_ABC',mean(a(j,7:9),1),'sample_sum_rms_A',sqrt(mean(a(j,13).^2)), ...
 'max_sample_to_actuation_us',max(p(:,9))*1e6);
end
function checkEvents(o)
a=teach_values(o.obs_adc_timing);t=o.obs_adc_timing.Time;p=teach_values(o.obs_pwm_timing);tp=o.obs_pwm_timing.Time;
for row=[2 24.375;3 25.5625;4 27.0625;5 28.5625;6 28.875]'
 times=t(a(:,row(1))>0);assert(~isempty(times));ph=mod(times,50e-6);assert(max(abs(ph-row(2)*1e-6))<1e-11);
end
times=tp(p(:,4)>0);assert(max(abs(mod(times,50e-6)-33.875e-6))<1e-11);
times=tp(p(:,5)>0);assert(all(abs(times/25e-6-round(times/25e-6))<1e-7));
end
