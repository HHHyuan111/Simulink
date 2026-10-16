function validate_deadtime_stage4
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);addpath(fullfile(root,'teaching'));
work=fullfile(root,'.build','deadtime_stage');mdl='PMSM_FOC_R2026a';file=fullfile(work,[mdl '.slx']);
record=struct('all_passed',false,'source_sha256',teach_hash(fullfile(work,'PMSM_FOC_before_deadtime.slx')),'model_sha256',teach_hash(file));
record.components=test_deadtime_components;record.fine_components=test_deadtime_components(31.25e-9);
load_system(file);g=onCleanup(@()close_system(mdl,0));before=load(fullfile(work,'before.mat'));now=teach_snapshot(mdl);
assert(isequaln(before.before.regions,now.regions));
for b=before.before.blocks,n=now.blocks(strcmp({now.blocks.sid},b.sid));assert(isscalar(n)&&strcmp(b.path,n.path)&&strcmp(b.type,n.type)&&(isequal(b.position,n.position)||strcmp(b.path,[mdl '/功率观测/总览'])));end
record.preserved_blocks=numel(before.before.blocks);record.total_blocks=numel(now.blocks);record.root_blocks=numel(find_system(mdl,'SearchDepth',1,'Type','Block'));
mw=get_param(mdl,'ModelWorkspace');record.pi_gains=struct;
for key={'kp_w','ki_w','ks_w','kp_id','ki_id','ks_id','kp_iq','ki_iq','ks_iq'},record.pi_gains.(key{1})=getVariable(mw,key{1});end
prior=jsondecode(fileread(fullfile(root,'timing','timing_stage3_results.json')));assert(isequaln(record.pi_gains,prior.pi_gains));
fprintf('DEADTIME_OFF_REGRESSION\n');in=Simulink.SimulationInput(mdl);in=in.setModelParameter('StopTime','.02');o=sim(in);old=load(fullfile(work,'baseline_off.mat'),'o');
record.off=compare(old.o,o);finiteLogs(o);save(fullfile(work,'off.mat'),'o','-v7.3');clear old o;
fprintf('DEADTIME_REAL_REGRESSION\n');in=in.setBlockParameter([mdl '/时序设置'],'real_on','on');o=sim(in);old=load(fullfile(work,'baseline_real.mat'),'o');
record.real=compare(old.o,o);finiteLogs(o);save(fullfile(work,'real.mat'),'o','-v7.3');clear old o;
% Three runs differ only in programmed deadtime and compensation switch.
% Zero-deadtime ideal uses the same gate event grid and bridge as other cases.
names={'ideal','dead','comp'};
for k=1:3
 fprintf('DEADTIME_DEMO_%s\n',upper(names{k}));
 td=.5;if k==1,td=0;end;enable='off';if k==3,enable='on';end
 o=run_deadtime_case(mdl,td,enable,.08);finiteLogs(o);record.demo.(names{k})=deadtime_metrics(o);
 if k>1,gateCheck(o,.5e-6);end
 save(fullfile(work,[names{k} '.mat']),'o','-v7.3');clear o;
end
record.improvement=struct('THD_percent',100*(1-record.demo.comp.low_order_THD_percent/record.demo.dead.low_order_THD_percent), ...
 'id_rms_percent',100*(1-record.demo.comp.id_rms_A/record.demo.dead.id_rms_A), ...
 'torque_ac_rms_percent',100*(1-record.demo.comp.torque_period_average_ac_rms_Nm/record.demo.dead.torque_period_average_ac_rms_Nm));
assert(record.demo.comp.low_order_THD_percent<record.demo.dead.low_order_THD_percent,'Compensation must reduce measured low-order current distortion.');
assert(record.demo.comp.torque_period_average_ac_rms_Nm<record.demo.dead.torque_period_average_ac_rms_Nm,'Compensation did not reduce torque ripple.');
fprintf('DEADTIME_GRID_CONVERGENCE\n');fine=run_deadtime_case(mdl,.5,'on',.005,2);finiteLogs(fine);base=load(fullfile(work,'comp.mat'),'o');
a=teach_values(base.o.log_iq);b=teach_values(fine.log_iq);r=base.o.log_iq.Time<=fine.log_iq.Time(end)+1e-12;
record.grid_iq_max_difference_A=max(abs(a(r,:)-b),[],'all');assert(record.grid_iq_max_difference_A<.1);
save(fullfile(work,'fine.mat'),'fine','-v7.3');clear fine base;
% Test finite behavior with actual sequential sampling windows and deadtime.
fprintf('DEADTIME_WINDOW_COMBINATION\n');set_param([mdl '/时序设置'],'real_on','on','window_on','on');set_param([mdl '/功率设置'],'gate_on','on','comp_on','on');
in=Simulink.SimulationInput(mdl);in=in.setModelParameter('StopTime','.005');o=sim(in);finiteLogs(o);gateCheck(o,.5e-6);save(fullfile(work,'combined.mat'),'o','-v7.3');clear o;
close_system(mdl,0);load_system(file);
for row={'gate_on','on','dead_on','on';'comp_on','on','gate_on','off'}'
 in=Simulink.SimulationInput(mdl);in=in.setModelParameter('StopTime','.0001');in=in.setBlockParameter([mdl '/功率设置'],row{1},row{2});in=in.setBlockParameter([mdl '/功率设置'],row{3},row{4});
 failed=false;try,sim(in);catch,failed=true;end;assert(failed);
end
record.invalid_combinations_rejected=true;assert(isequaln(now,teach_snapshot(mdl)));record.saved_reload_preserved=true;
record.real_board_calibrated=false;record.pi_retuned=false;record.all_passed=true;teach_writejson(fullfile(folder,'deadtime_stage4_results.json'),record);
fprintf('DEADTIME_ALL_PASS %s\n',record.model_sha256);
end
function r=compare(old,o)
keys=old.who;r=struct('timeseries',0,'identical',0,'max_abs_difference',0);
for k=1:numel(keys)
 a=old.get(keys{k});if ~isa(a,'timeseries'),continue;end;b=o.get(keys{k});av=teach_values(a);bv=teach_values(b);
 assert(isequaln(a.Time,b.Time),'Changed log times %s',keys{k});difference=max(abs(av-bv),[],'all');
 assert(difference<1e-8,'Baseline changed %s: %.12g',keys{k},difference);
 r.timeseries=r.timeseries+1;r.identical=r.identical+double(isequaln(av,bv));r.max_abs_difference=max(r.max_abs_difference,difference);
end
end
function finiteLogs(o)
keys=o.who;
for k=1:numel(keys),a=o.get(keys{k});if isa(a,'timeseries'),assert(all(isfinite(a.Time),'all')&&all(isfinite(a.Data),'all'),'Nonfinite %s',keys{k});end,end
end
function gateCheck(o,td)
g=teach_values(o.obs_dead_gates);h=median(diff(o.obs_dead_gates.Time));n=round(td/h);
assert(all(g(:,1:2:5)+g(:,2:2:6)<=1,'all'));
for leg=1:3
 pair=g(:,2*leg-1:2*leg);assert(any(sum(pair,2)==0));
 for k=1:2
  rise=find(diff(pair(:,k))>0)+1;rise=rise(rise>n);
  for ix=rise',assert(all(pair(ix-n:ix-1,:)==0,'all'),'Deadtime shorter than configured.');end
 end
end
end
