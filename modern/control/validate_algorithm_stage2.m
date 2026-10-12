function validate_algorithm_stage2
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);addpath(fullfile(root,'teaching'));
work=fullfile(root,'.build','algorithm_stage');mdl='PMSM_FOC_R2026a';candidate=fullfile(work,[mdl '.slx']);
load_system(candidate);guard=onCleanup(@()close_system(mdl,0));
mw=get_param(mdl,'ModelWorkspace');record=struct('source_sha256',teach_hash(fullfile(work,'PMSM_FOC_before_algorithm.slx')),'model_sha256',teach_hash(candidate),'all_passed',false);
record.components=components(mdl,mw);fprintf('ALGORITHM_COMPONENTS_PASS\n');
cached=load(fullfile(work,'before.mat'));after=teach_snapshot(mdl);record.preserved_original_blocks=numel(cached.before.blocks);
assert(isequaln(cached.before.regions,after.regions));
for b=cached.before.blocks(:)'
 n=after.blocks(strcmp({after.blocks.sid},b.sid));assert(isscalar(n)&&strcmp(b.type,n.type)&&strcmp(b.path,n.path)&&isequal(b.position,n.position));
end
record.pi_gains=struct;for key={'kp_w','ki_w','ks_w','kp_id','ki_id','ks_id','kp_iq','ki_iq','ks_iq'}
 record.pi_gains.(key{1})=getVariable(mw,key{1});
end
old=load(fullfile(root,'.build','motor_profile_stage','runs.mat'),'record');assert(isequaln(record.pi_gains,old.record.pi_gains));
record.settings=teach_settings(mdl);record.decoupling_default=get_param([mdl '/解耦'],'enabled');assert(strcmp(record.decoupling_default,'on'));
for s=record.settings,for p=s.parameters,if endsWith(p.name,'_on'),assert(strcmp(p.value,'off'));end,end,end
record.before=metrics(cached.baseline,false);before=cached.baseline;clear cached;
fprintf('ALGORITHM_DEFAULT_1S\n');out=sim(mdl);
record.default=metrics(out,true);checkClosed(record.default,30);
record.default.aw_recurrence=checkAW(out,mw);default=out;save(fullfile(work,'default.mat'),'out','-v7.3');clear out;
in=Simulink.SimulationInput(mdl);in=in.setBlockParameter(getfullname(Simulink.ID.getHandle([mdl ':590'])),'Value','-3');in=in.setModelParameter('StopTime','.15');
o=sim(in);vol=teach_values(o.obs_voltage);pd=teach_values(o.obs_pi_d);pq=teach_values(o.obs_pi_q);st=teach_values(o.obs_state);we=getVariable(mw,'p')*st(:,3);
ff=[-we*getVariable(mw,'Lq').*teach_values(o.log_iq) we.*(getVariable(mw,'phis')+getVariable(mw,'Ld')*teach_values(o.log_id))];
record.nonzero_id_feedforward_error_V=max(abs(vol(:,1:2)-[pd(:,4) pq(:,4)]-ff),[],'all');assert(record.nonzero_id_feedforward_error_V<1e-7);clear o;
fprintf('ALGORITHM_REVERSE_1S\n');
refs=find_system(mdl,'SearchDepth',1,'BlockType','Constant','Name','speed_ref');assert(isscalar(refs));ref=refs{1};
set_param(ref,'Value','-2000');out=sim(mdl);
record.negative_start=metrics(out,true);checkClosed(record.negative_start,40);
save(fullfile(work,'negative_start.mat'),'out','-v7.3');clear out;set_param(ref,'Value','n');
% Real reversal uses a temporary From Workspace source in place of speed_ref.
replaceSource(ref,'speed_test');assignin(mw,'speed_test',[(0:0.00005:1)' 2000-4000*double((0:0.00005:1)'>=.35)]);out=sim(mdl);
record.reversal=metrics(out,true);checkClosed(record.reversal,40);record.reversal.aw_recurrence=checkAW(out,mw);
save(fullfile(work,'reversal.mat'),'out','-v7.3');clear out;
close_system(mdl,0);load_system(candidate);mw=get_param(mdl,'ModelWorkspace');
fprintf('ALGORITHM_LOAD_STEP_1S\n');loadBlock=getfullname(Simulink.ID.getHandle([mdl ':523']));
in=Simulink.SimulationInput(mdl);in=in.setBlockParameter(loadBlock,'Time','.35');in=in.setBlockParameter(loadBlock,'InitialValue','0.3*Tn');in=in.setBlockParameter(loadBlock,'FinalValue','0.45*Tn');
out=sim(in);
record.load_step=metrics(out,true);checkClosed(record.load_step,40);save(fullfile(work,'load_step.mat'),'out','-v7.3');clear out;
fprintf('ALGORITHM_BUS_RECOVERY_1S\n');bus=getfullname(Simulink.ID.getHandle([mdl ':681']));replaceSource(bus,'bus_test');
% Physical bus is continuous. A discrete source would make the inherited
% bridge math execute at the bus sample period and destroy PWM resolution.
set_param(bus,'SampleTime','0','Interpolate','on');
assignin(mw,'bus_test',[0 24;.25-1e-6 24;.25 6;.55-1e-6 6;.55 24;1 24]);
out=sim(mdl);record.bus_recovery=metrics(out,true);save(fullfile(work,'bus_recovery_probe.mat'),'out','-v7.3');fprintf('BUS_MEASURED_RANGE %s\n',mat2str([min(teach_values(out.log_UDC)) max(teach_values(out.log_UDC))]));checkClosed(record.bus_recovery,40);record.bus_recovery.aw_recurrence=checkAW(out,mw);
v=teach_values(out.obs_voltage);t=out.obs_voltage.Time;during=t>=.27&t<.53;restored=t>=.8;
record.bus_recovery.saturation_fraction_during=mean(v(during,8));record.bus_recovery.saturation_fraction_restored=mean(v(restored,8));
assert(record.bus_recovery.saturation_fraction_during>.1,'Insufficient voltage test did not trigger saturation.');
assert(record.bus_recovery.saturation_fraction_restored<.01,'Saturation persisted after restoration.');
save(fullfile(work,'bus_recovery.mat'),'out','-v7.3');recovery=out;clear out;
close_system(mdl,0);load_system(candidate);mw=get_param(mdl,'ModelWorkspace');
fprintf('ALGORITHM_RELOAD_DEFAULT_1S\n');out=sim(mdl);
for key={'log_speed','log_id','log_iq','log_Te','log_Tcm_applied','obs_voltage','obs_aw_d','obs_aw_q','obs_mod'}
 a=default.get(key{1});b=out.get(key{1});assert(isequaln(a.Time,b.Time)&&isequaln(a.Data,b.Data),'Saved reload changed results.');
end
record.reloaded_identical=true;assert(isequaln(after,teach_snapshot(mdl)));
assert(isempty(find_system(mdl,'LookUnderMasks','all','FollowLinks','off','LinkStatus','unresolved')));
% Algorithm switch OFF affects both feedforward branches, final limiter stays active.
in=Simulink.SimulationInput(mdl);in=in.setBlockParameter([mdl '/解耦'],'enabled','off');in=in.setModelParameter('StopTime','.15');
off=sim(in);vd=teach_values(off.obs_voltage);pd=teach_values(off.obs_pi_d);pq=teach_values(off.obs_pi_q);
assert(max(abs(vd(:,1)-pd(:,4)))<1e-9&&max(abs(vd(:,2)-pq(:,4)))<1e-9);record.decoupling_off_passed=true;
record.total_blocks=numel(after.blocks);record.root_blocks=numel(find_system(mdl,'SearchDepth',1,'Type','Block'));
record.all_passed=true;teach_writejson(fullfile(folder,'algorithm_stage2_results.json'),record);
plotReport(before,default,recovery,folder);print(['-s' mdl],'-dpng','-r120',fullfile(work,'candidate.png'));
fprintf('ALGORITHM_ALL_PASS %s\n',record.model_sha256);
end

function r=components(mdl,mw)
r=struct;
% Test the actual embedded SVPWM chart using an independent phase-span oracle.
h='algorithm_component';new_system(h);g=onCleanup(@()close_system(h,0));hmw=get_param(h,'ModelWorkspace');hmw.DataSource='MATLAB Code';hmw.MATLABCode=mw.MATLABCode;reload(hmw);
angles=unique([linspace(-pi,pi,721) (0:6)*pi/3-1e-10 (0:6)*pi/3+1e-10]);
vectors=[];for radius=[0 1 13 24 100],vectors=[vectors;radius*cos(angles(:)) radius*sin(angles(:))];end %#ok<AGROW>
N=size(vectors,1);period=50e-6;tt=(0:N-1)'*period;
input=[vectors repmat(24,N,1) repmat(period,N,1)];input=[input;0 0 0 period;1 2 0 period;1 -2 24 1e-4];N=size(input,1);tt=(0:N-1)'*period;
assignin(hmw,'test_input',[tt input]);add_block('simulink/Sources/From Workspace',[h '/input'],'VariableName','test_input','SampleTime','dt','Interpolate','off','OutputAfterFinalValue','Holding final value');
add_block('simulink/Signal Routing/Demux',[h '/split'],'Outputs','4');add_line(h,'input/1','split/1');
add_block(getfullname(Simulink.ID.getHandle([mdl ':240'])),[h '/SVM']);
for k=1:4,add_line(h,sprintf('split/%d',k),sprintf('SVM/%d',k));end
for k=1:3,add_block('simulink/Sinks/To Workspace',[h '/out' num2str(k)],'VariableName',['out' num2str(k)],'SaveFormat','Timeseries');add_line(h,sprintf('SVM/%d',k),sprintf('out%d/1',k));end
set_param(h,'Solver','FixedStepDiscrete','FixedStep','dt','StopTime',num2str(tt(end),17),'ReturnWorkspaceOutputs','on');o=sim(h);
threshold=teach_values(o.out1);sector=teach_values(o.out2);diag=teach_values(o.out3);duty=1-2*threshold./input(:,4);
assert(all(threshold(:)>=-1e-12)&&all(all(threshold<=input(:,4)/2+1e-12)));
phase=input(:,3).*(duty-mean(duty,2));actual=[phase(:,1) (phase(:,2)-phase(:,3))/sqrt(3)];
abc=[input(:,1) -.5*input(:,1)+sqrt(3)/2*input(:,2) -.5*input(:,1)-sqrt(3)/2*input(:,2)];
span=max(abc,[],2)-min(abc,[],2);scale=min(1,input(:,3)./max(span,1e-12));expected=input(:,1:2).*scale;
r.svpwm_vectors=N;r.svpwm_reconstruction_error_V=max(abs(actual-expected),[],'all');
assert(r.svpwm_reconstruction_error_V<1e-10);assert(all(ismember(1:6,unique(sector))));
assert(max(abs(sum(diag(:,1:3),2)-input(:,4)))<1e-12&&all(diag(:,1:3)>=-1e-12,'all'));
assert(max(abs(diag(:,4:6)-duty),[],'all')<1e-12);r.all_six_sectors_and_boundaries=true;
close_system(h,0);clear g;
% Copy the implemented limiter and supply its global input tags.
new_system(h);g=onCleanup(@()close_system(h,0));hmw=get_param(h,'ModelWorkspace');hmw.DataSource='MATLAB Code';hmw.MATLABCode=mw.MATLABCode;reload(hmw);
x=[0 0 24;1 2 24;20 30 24;-20 30 24;20 -30 24;-20 -30 24;0 100 24;100 0 24;1 2 0;0 0 0;1 2 -1;1e-14 0 24];
assignin(hmw,'test_input',[(0:size(x,1)-1)'*period x]);add_block('simulink/Sources/From Workspace',[h '/input'],'VariableName','test_input','SampleTime','dt','Interpolate','off','OutputAfterFinalValue','Holding final value');
add_block('simulink/Signal Routing/Demux',[h '/split'],'Outputs','3');add_line(h,'input/1','split/1');
tags={'vd_req','vq_req','UDC'};for k=1:3,add_block('simulink/Signal Routing/Goto',[h '/tag' num2str(k)],'GotoTag',tags{k},'TagVisibility','global');add_line(h,sprintf('split/%d',k),sprintf('tag%d/1',k));end
add_block([mdl '/限压'],[h '/limit']);set_param(h,'Solver','FixedStepDiscrete','FixedStep','dt','StopTime',num2str((size(x,1)-1)*period,17),'ReturnWorkspaceOutputs','on');o=sim(h);
v=teach_values(o.obs_voltage);vmax=.96*max(x(:,3),0)/sqrt(3);expected=x(:,1:2).*min(1,vmax./max(hypot(x(:,1),x(:,2)),1e-12));
r.vector_limit_error_V=max(abs(v(:,3:4)-expected),[],'all');assert(r.vector_limit_error_V<1e-12);assert(all(hypot(v(:,3),v(:,4))<=vmax+1e-12));r.direction_preserved=true;
close_system(h,0);clear g;
% Distinct d/q gains and limits; actual PI copies vs implicit BE oracle.
for row={'439','d',.4,17,.8,4;'453','q',.7,29,1.1,7}'
 new_system(h);g=onCleanup(@()close_system(h,0));hmw=get_param(h,'ModelWorkspace');hmw.DataSource='MATLAB Code';hmw.MATLABCode=mw.MATLABCode;reload(hmw);
 ax=row{2};kp=row{3};ki=row{4};ks=row{5};hi=row{6};lo=-hi;
 for pair={['kp_i' ax],kp;['ki_i' ax],ki;['ks_i' ax],ks;['uplimit_i' ax],hi;['downlimit_i' ax],lo}',assignin(hmw,pair{1},pair{2});end
 e=[ones(30,1)*.1;ones(70,1)*30;ones(70,1)*-30;zeros(80,1)];ext=[zeros(30,1);ones(70,1)*-2;ones(70,1)*2;zeros(80,1)];
 assignin(hmw,'test_input',[(0:numel(e)-1)'*period e ext]);add_block('simulink/Sources/From Workspace',[h '/input'],'VariableName','test_input','SampleTime','dt','Interpolate','off','OutputAfterFinalValue','Holding final value');
 add_block('simulink/Signal Routing/Demux',[h '/split'],'Outputs','2');add_line(h,'input/1','split/1');
 add_block('simulink/Signal Routing/Goto',[h '/tag'],'GotoTag',['ObsResidual_' ax],'TagVisibility','global');add_line(h,'split/2','tag/1');
 add_block(getfullname(Simulink.ID.getHandle([mdl ':' row{1}])),[h '/PI']);add_line(h,'split/1','PI/1');
 add_block('simulink/Sinks/Terminator',[h '/sink']);add_line(h,'PI/1','sink/1');
 set_param(h,'Solver','FixedStepDiscrete','FixedStep','dt','StopTime',num2str((numel(e)-1)*period,17),'ReturnWorkspaceOutputs','on','AlgebraicLoopMsg','none');o=sim(h);
 actual=teach_values(o.get(['obs_pi_' ax]));xi=zeros(size(e));
 for k=2:numel(e)
  left=lo;right=hi;
  for j=1:80
   trial=(left+right)/2;raw=kp*e(k)+trial;f=trial-min(hi,max(lo,xi(k-1)+period*ki*(e(k)-ks*(raw-min(hi,max(lo,raw))-ext(k)))));
   if f>0,right=trial;else,left=trial;end
  end
  xi(k)=(left+right)/2;
 end
 err=max(abs(actual(:,2)-xi));assert(err<2e-8);r.(['pi_' ax '_integral_error_V'])=err;
 assert(max(abs(actual(:,1)-kp*e))<1e-10&&max(abs(actual(:,4)-min(hi,max(lo,kp*e+xi))))<2e-8);
 close_system(h,0);clear g;
end
r.distinct_axis_bindings_passed=true;
end

function result=checkAW(o,mw)
v=teach_values(o.obs_voltage);d=teach_values(o.obs_pi_d);q=teach_values(o.obs_pi_q);awD=teach_values(o.obs_aw_d);awQ=teach_values(o.obs_aw_q);
ff=[v(:,1)-d(:,4) v(:,2)-q(:,4)];raw=[d(:,3) q(:,3)];ks=[getVariable(mw,'ks_id') getVariable(mw,'ks_iq')];
actual=[awD(:,2) awQ(:,2)];expected=(v(:,3:4)-ff-raw).*ks;
result.maximum_combined_backcalculation_error_A=max(abs(actual-expected),[],'all');assert(result.maximum_combined_backcalculation_error_A<1e-7);
e=[teach_values(o.obs_id_ref)-teach_values(o.log_id) teach_values(o.log_iq_ref)-teach_values(o.log_iq)];
xi=[d(:,2) q(:,2)];ki=[getVariable(mw,'ki_id') getVariable(mw,'ki_iq')];hi=[getVariable(mw,'uplimit_id') getVariable(mw,'uplimit_iq')];lo=-hi;
pred=min(hi,max(lo,xi(1:end-1,:)+getVariable(mw,'dt')*(e(2:end,:)+actual(2:end,:)).*ki));
result.maximum_backward_euler_error_V=max(abs(xi(2:end,:)-pred),[],'all');assert(result.maximum_backward_euler_error_V<2e-6);
end
function replaceSource(path,variable)
parent=get_param(path,'Parent');pos=get_param(path,'Position');ph=get_param(path,'PortHandles');ln=get_param(ph.Outport,'Line');dst=get_param(ln,'DstPortHandle');
delete_line(ln);delete_block(path);add_block('simulink/Sources/From Workspace',path,'VariableName',variable,'SampleTime','dt','Interpolate','off','OutputAfterFinalValue','Holding final value','Position',pos);
ph=get_param(path,'PortHandles');for d=dst(:)',add_line(parent,ph.Outport(1),d,'autorouting','on');end
end
function m=metrics(o,new)
speed=teach_values(o.log_speed);ref=teach_values(o.log_nref);tc=teach_values(o.log_Tcm_applied);iq=teach_values(o.log_iq);
finite=true;names=o.who;for k=1:numel(names),x=o.get(names{k});if isa(x,'timeseries'),finite=finite&&all(isfinite(x.Data(:)));end,end
m=struct('finite',finite,'final_speed_rpm',speed(end),'final_speed_error_rpm',abs(speed(end)-ref(end)), ...
 'peak_speed_abs_rpm',max(abs(speed)),'peak_iq_abs_A',max(abs(iq)),'thresholds_valid',all(tc(:)>=-1e-12&tc(:)<=25e-6+1e-12));
if new
 v=teach_values(o.obs_voltage);mod=teach_values(o.obs_mod);m.max_final_utilization=max(v(:,7));m.saturation_fraction=mean(v(:,8));
 m.modulation_valid=all(mod(:,1:3)>=-1e-12,'all')&&max(abs(sum(mod(:,1:3),2)-50e-6))<1e-12&&all(mod(:,4:6)>=-1e-12&mod(:,4:6)<=1+1e-12,'all')&&all(mod(:,8)==0);
 assert(m.max_final_utilization<=1+1e-10&&m.modulation_valid);
end
end
function checkClosed(m,tol),assert(m.finite&&m.thresholds_valid&&m.final_speed_error_rpm<tol&&m.peak_iq_abs_A<40,'Closed-loop check failed: %s',jsonencode(m));end
function plotReport(before,after,recovery,folder)
f=figure('Visible','off','Color','white','Position',[50 50 1500 1100]);set(f,'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei');tiledlayout(3,2,'TileSpacing','compact');
t=after.log_speed.Time;b=before.log_speed.Time;v=teach_values(after.obs_voltage);d=teach_values(after.obs_pi_d);q=teach_values(after.obs_pi_q);
nexttile;plot(b,teach_values(before.log_speed),t,teach_values(after.log_speed));title('默认启动：修复前 / 后');ylabel('rpm');legend('前','后');grid on;
nexttile;plot(t,[d(:,4) q(:,4) v(:,1)-d(:,4) v(:,2)-q(:,4)]);title('PI输出与前馈');ylabel('V');legend('PI d','PI q','FF d','FF q');grid on;
nexttile;plot(t,v(:,[6 7]));yline(1,'r--');title('请求 / 最终电压利用率');legend('请求','最终');grid on;
nexttile;mod=teach_values(after.obs_mod);plot(t,mod(:,1:3)*1e6);title('有效矢量与总零矢量时间');ylabel('μs');legend('t1','t2','t0总');grid on;
tr=recovery.obs_voltage.Time;vr=teach_values(recovery.obs_voltage);
nexttile;yyaxis left;plot(tr,teach_values(recovery.log_speed));ylabel('rpm');yyaxis right;plot(tr,teach_values(recovery.log_UDC));ylabel('V');title('母线24→6→24 V：饱和后恢复');grid on;
nexttile;plot(tr,vr(:,[6 7 8]));title('低压工况：请求 / 最终利用率 / 饱和标志');legend('请求','最终','饱和');grid on;
sgtitle('算法基础修复 · 原PI增益不变 · 仿真检查');exportgraphics(f,fullfile(folder,'algorithm_stage2_comparison.png'),'Resolution',130);close(f);
end
