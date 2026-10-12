function finalize_algorithm_stage2
% Verify preservation and task rates, render reports, then publish the candidate.
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);addpath(fullfile(root,'teaching'));
work=fullfile(root,'.build','algorithm_stage');mdl='PMSM_FOC_R2026a';candidate=fullfile(work,[mdl '.slx']);canonical=fullfile(root,[mdl '.slx']);
record=jsondecode(fileread(fullfile(folder,'algorithm_stage2_results.json')));
assert(record.all_passed&&strcmp(teach_hash(candidate),record.model_sha256)&&strcmp(teach_hash(canonical),record.source_sha256));
load_system(candidate);guard=onCleanup(@()close_system(mdl,0));old=load(fullfile(work,'before.mat'),'before');now=teach_snapshot(mdl);
changed=struct('sid',{},'path',{},'parameters',{},'inputs',{});
allowed={'439','449','463','220','221','213','144','152','240'};
for b=old.before.blocks(:)'
 n=now.blocks(strcmp({now.blocks.sid},b.sid));assert(isscalar(n)&&strcmp(b.path,n.path)&&strcmp(b.type,n.type)&&isequal(b.position,n.position)&&strcmp(b.orientation,n.orientation));
 parameters=~isequaln(b.params,n.params)||~isequaln(b.mask,n.mask);inputs=~isequaln(b.inputs,n.inputs);
 if parameters||inputs
  id=extractAfter(b.sid,':');changed(end+1)=struct('sid',b.sid,'path',b.path,'parameters',parameters,'inputs',inputs); %#ok<AGROW>
  assert(ismember(id,allowed)||startsWith(id,'240::')||ismember(b.path,{[mdl '/PI观测/总览'],[mdl '/时序观测/总览']}),'Unexpected original block change: %s',b.path);
 end
end
assert(isequaln(old.before.regions,now.regions)&&isequaln(old.before.config,now.config));
for k=1:size(old.before.scripts,1)
 path=old.before.scripts{k,1};if contains(path,'SVPWM Function'),continue;end
 ix=strcmp(now.scripts(:,1),path);assert(nnz(ix)==1&&strcmp(now.scripts{ix,2},old.before.scripts{k,2}));
end
record.original_geometry_and_regions_preserved=true;record.original_changes=changed;
% Three diagnostic Gotos became redundant when scopes were split by unit.
% Remove only these new branches; verify every recorded signal is identical.
for path={[mdl '/限压/标签_ObsVoltage'],[mdl '/PI Controller_w1/标签_ObsAW_d'],[mdl '/PI Controller_w2/标签_ObsAW_q']}
 ph=get_param(path{1},'PortHandles');line=get_param(ph.Inport(1),'Line');src=get_param(line,'SrcPortHandle');
 delete_line(get_param(path{1},'Parent'),src,ph.Inport(1));delete_block(path{1});
end
fprintf('ALGORITHM_DIAGNOSTIC_CLEANUP_1S\n');clean=sim(mdl);d=load(fullfile(work,'default.mat'));names=d.out.who;count=0;
for k=1:numel(names)
 a=d.out.get(names{k});if ~isa(a,'timeseries'),continue;end
 b=clean.get(names{k});assert(isequaln(a.Time,b.Time)&&isequaln(a.Data,b.Data),'Diagnostic cleanup changed %s',names{k});count=count+1;
end
clear clean d;record.before_diagnostic_cleanup_sha256=record.model_sha256;record.diagnostic_cleanup_identical_timeseries=count;
save_system(mdl,candidate);record.model_sha256=teach_hash(candidate);now=teach_snapshot(mdl);
record.total_blocks=numel(now.blocks);record.root_blocks=numel(find_system(mdl,'SearchDepth',1,'Type','Block'));
feval(mdl,[],[],[],'compile');rates=struct;
try
 for row={'442',50e-6;'456',50e-6;'438',100e-6;'240',50e-6}'
  st=get_param(Simulink.ID.getHandle([mdl ':' row{1}]),'CompiledSampleTime');if iscell(st),st=vertcat(st{:});end
  positive=unique(st(isfinite(st(:,1))&st(:,1)>0,1));assert(isscalar(positive)&&abs(positive-row{2})<1e-12);rates.(['sid_' row{1}])=positive;
 end
catch err,feval(mdl,[],[],[],'term');rethrow(err);end
feval(mdl,[],[],[],'term');record.compiled_periods_s=rates;
% Check the mixed continuous-plant/discrete-control case that exposed inheritance.
bus=[mdl '/DC Voltage Source'];ph=get_param(bus,'PortHandles');line=get_param(ph.Outport(1),'Line');dest=get_param(line,'DstPortHandle');pos=get_param(bus,'Position');
delete_line(line);delete_block(bus);add_block('simulink/Sources/From Workspace',bus,'VariableName','bus_rate_probe','SampleTime','0','Interpolate','on','Position',pos);
ph=get_param(bus,'PortHandles');for target=dest(:)',add_line(mdl,ph.Outport(1),target,'autorouting','on');end
assignin(get_param(mdl,'ModelWorkspace'),'bus_rate_probe',[0 24;.5 6;1 24]);feval(mdl,[],[],[],'compile');transient=struct;
try
 for row={[mdl '/SVPWM Function v1.0'],50e-6;[mdl '/限压/比例限幅'],50e-6;[mdl '/Universal Bridge/phase_A'],0}'
  st=get_param(row{1},'CompiledSampleTime');if iscell(st),st=vertcat(st{:});end
  assert(isscalar(unique(st(:,1)))&&abs(st(1,1)-row{2})<1e-12,'Unexpected transient-bus task rate: %s',row{1});
  transient.(matlab.lang.makeValidName(get_param(row{1},'Name')))=st(1,1);
 end
catch err,feval(mdl,[],[],[],'term');rethrow(err);end
feval(mdl,[],[],[],'term');record.continuous_bus_compiled_periods_s=transient;
close_system(mdl,0);load_system(candidate);
report=fullfile(folder,'report_algorithm');d=load(fullfile(work,'default.mat'));record.default.observation_metrics=plot_observation_report(d.out,'算法修复 · 沉沙200W · 默认启动',fullfile(report,'default'));clear d;
d=load(fullfile(work,'bus_recovery.mat'));record.bus_recovery.observation_metrics=plot_observation_report(d.out,'母线24→6→24V · 原PI增益',fullfile(report,'bus_recovery'));clear d;
print(['-s' mdl],'-dpng','-r120',fullfile(work,'candidate.png'));
record.complete_board_emulation=false;record.pi_retuned=false;
record.notes={'PI axis clamps and integral clamps are retained. Final residual and axis residual telescope to Vfinal-FF-PIraw; there is one combined correction.', ...
 'Backward Euler retains an implicit algebraic solve at each current tick; this is not a bit-exact firmware integrator.', ...
 'True gate deadtime, ADC valid windows, sequential conversion, ABZ estimator, alignment and active protection remain future work.'};
teach_writejson(fullfile(folder,'algorithm_stage2_results.json'),record);
fprintf('ALGORITHM_REVIEW_READY %s\n',record.model_sha256);
end
