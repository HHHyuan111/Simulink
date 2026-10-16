function record=validate_sensorless_n3_case(caseId,folder,label,observerPresent)
% One complete frozen N3 case in a fresh MATLAB process; no model save.
if nargin<3,label='formal';end
if nargin<4,observerPresent=true;end
here=fileparts(mfilename('fullpath'));root=fileparts(here);mdl='PMSM_FOC_R2026a';
for part={'','sensorless','teaching','control','timing','deadtime','framework','layout/appearance'},addpath(fullfile(root,part{1}));end
assert(~bdIsLoaded(mdl));if ~isfolder(folder),mkdir(folder);end
allPlan=jsondecode(fileread(fullfile(here,'contracts','test_plan_v1.json')));cases=allPlan.cases;
if ~iscell(cases),cases=num2cell(cases);end
index=find(cellfun(@(x)strcmp(x.id,caseId)&&strcmp(x.node,'N3'),cases));assert(isscalar(index));testcase=cases{index};
record=struct('schema',1,'node','N3','case_id',caseId,'label',label,'folder',folder,'status','running',...
 'matlab_version',version,'process_id',feature('getpid'),'phase','source_snapshot',...
 'model_sha256',teach_hash(fullfile(root,[mdl '.slx'])),'source_files',struct('path',{},'sha256',{}),...
 'contracts',struct('path',{},'sha256',{}),'observer_present',observerPresent,'raw_format','top_level_timeseries_v1');
for name={'contracts/acceptance_v1.json','contracts/test_plan_v1.json','milestones/N3_test_plan.json','milestones/N3_final_parameters.json'}
 record.contracts(end+1)=struct('path',name{1},'sha256',teach_hash(fullfile(here,name{1})));
end
files=[dir(fullfile(here,'*.m'));dir(fullfile(here,'blocks','*.m'))];mkdir(fullfile(folder,'source'));
for f=files(:)'
 relative=strrep(erase(fullfile(f.folder,f.name),[here filesep]),'\','/');
 record.source_files(end+1)=struct('path',relative,'sha256',teach_hash(fullfile(f.folder,f.name))); %#ok<AGROW>
 target=fullfile(folder,'source',relative);if ~isfolder(fileparts(target)),mkdir(fileparts(target));end
 copyfile(fullfile(f.folder,f.name),target);
end
teach_writejson(fullfile(folder,'record.json'),record);
sldiagviewer.diary(fullfile(folder,'diagnostics.log'),'UTF-8');
Simulink.fileGenControl('set','CacheFolder',fullfile(folder,'.build','cache'),...
 'CodeGenFolder',fullfile(folder,'.build','codegen'),'createDir',true);
cleanup=onCleanup(@()close_private(mdl));
try
 phase('load');load_system(fullfile(root,[mdl '.slx']));pmsm_reference('restore');
 phase('snapshot_before');original=teach_snapshot(mdl);fixedState=pmsm_reference('capture');
 phase('stimulus');backup=sensorless_n3_stimulus(mdl,testcase);set_param(mdl,'SimulationCommand','update');
 configured=teach_snapshot(mdl);motorPI=read_motor_pi(mdl);ws=get_param(mdl,'ModelWorkspace');
 if observerPresent
 phase('install');pmsm_sensorless_model('install',mdl);
 observer=[mdl '/无感观测'];
 frozen=jsondecode(fileread(fullfile(here,'milestones','N3_final_parameters.json')));
 for key=fieldnames(frozen.observer_design)'
  set_param(observer,key{1},num2str(frozen.observer_design.(key{1}),17));
 end
 if isfield(testcase,'direction'),set_param(observer,'direction',num2str(testcase.direction));end
 if isfield(testcase,'observer_parameter_multiplier')
  multiplier=testcase.observer_parameter_multiplier;
  if isfield(multiplier,'Rs'),set_param(observer,'R_hat',num2str(motorPI.Rs*multiplier.Rs,17));end
  if isfield(multiplier,'L'),set_param(observer,'L_hat',num2str(motorPI.Ld*multiplier.L,17));end
 end
 record.fault_configuration=sensorless_n3_faults(mdl,testcase);
 pmsm_sensorless_init(mdl); % Update read-only display while model is stopped.
 callback=get_param(mdl,'InitFcn');assert(contains(callback,'pmsm_sensorless_init(bdroot);'));
 set_param(mdl,'InitFcn',strrep(callback,'pmsm_sensorless_init(bdroot);','pmsm_sensorless_init_n3(bdroot);'));
 phase('compile');set_param(mdl,'SimulationCommand','update');
 graph=check_sensorless_graph(mdl,configured);teach_writejson(fullfile(folder,'graph.json'),graph);assert(graph.passed);
 ws=get_param(mdl,'ModelWorkspace');c=sensorless_rt_config(getVariable(ws,'sless_cfg'));
 record.observer_config=c;
 end
 record.motor_pi=motorPI;record.effective_case=testcase;
 speedBlock=sprintf([mdl '/PI Controller_w/Discrete-Time\nIntegrator']);
 expression=get_param(speedBlock,'SampleTime');speedRate=slResolve(expression,speedBlock);
 expectedRate=getVariable(ws,'timing_speed_sample');assert(isequaln(speedRate,expectedRate));
 if isscalar(speedRate),speedRate=[speedRate 0];end
 assert(isnumeric(speedRate)&&numel(speedRate)==2&&speedRate(1)==100e-6);
 record.speed_task_sample=speedRate;
 record.speed_rate_evidence='original masked SampleTime resolved with slResolve and checked against timing_speed_sample; N0/N2 compiled rate evidence retained; no extra legacy compile/term cycle';
 if observerPresent,c.evaluation_speed_sample=speedRate;record.observer_config=c;end
 record.timing_h=getVariable(ws,'timing_h');record.control_sample=getVariable(ws,'timing_control_sample');
 teach_writejson(fullfile(folder,'effective_configuration.json'),record);
 phase('simulate');in=Simulink.SimulationInput(mdl);in=in.setModelParameter('StopTime',num2str(testcase.duration_s,17));
 started=tic;out=sim(in);record.simulation_elapsed_s=toc(started);
 phase('archive');signals=struct;
 for name=out.who'
  series=out.get(name{1});if ~isa(series,'timeseries'),continue;end
  assert(all(isfinite(series.Time),'all')&&all(isfinite(series.Data),'all'),'Nonfinite log: %s',name{1});signals.(name{1})=series;
 end
 if observerPresent
 assert(isequaln(signals.obs_sless_theta.Time,signals.obs_sless_truth_theta.Time));
 error=teach_values(signals.obs_sless_theta)-teach_values(signals.obs_sless_truth_theta);
 signals.obs_sless_angle_error=timeseries(atan2(sin(error),cos(error)),signals.obs_sless_theta.Time);
 signals.obs_sless_speed_error=timeseries(teach_values(signals.obs_sless_speed)-teach_values(signals.obs_sless_truth_speed),signals.obs_sless_speed.Time);
 end
 save(fullfile(folder,'signals.mat'),'-struct','signals','-v7.3');record.raw_sha256=teach_hash(fullfile(folder,'signals.mat'));record.log_count=numel(fieldnames(signals));
 phase('metrics');metrics=struct('kind','plant_reference','passed',true);
 if observerPresent,metrics=analyse_sensorless_n3_case(signals,testcase,c);end
 teach_writejson(fullfile(folder,'metrics.json'),metrics);
 assert(isequaln(motorPI,read_motor_pi(mdl)),'Original motor/PI values changed.');
 clear signals out;
 phase('restore');if observerPresent,pmsm_sensorless_model('remove',mdl);end
 afterLayer=teach_snapshot(mdl);record.layer_restored=isequaln(configured,afterLayer);
 sensorless_n3_restore(mdl,backup);after=teach_snapshot(mdl);afterState=pmsm_reference('capture');
 record.reference_restored=isequaln(original,after)&&isequaln(fixedState,afterState);
 save(fullfile(folder,'restoration.mat'),'original','configured','afterLayer','after','fixedState','afterState');
 assert(record.layer_restored&&record.reference_restored,'Original model did not restore.');
 assert(strcmp(record.model_sha256,teach_hash(fullfile(root,[mdl '.slx']))));
 for f=record.source_files(:)',assert(strcmp(f.sha256,teach_hash(fullfile(here,f.path))),'Source changed during case: %s',f.path);end
 record.all_passed=metrics.passed;record.status='passed';if ~record.all_passed,record.status='failed_metrics';end
 record.phase='completed';teach_writejson(fullfile(folder,'record.json'),record);
 fprintf('N3_CASE_COMPLETED %s passed=%d elapsed=%g folder=%s\n',caseId,metrics.passed,record.simulation_elapsed_s,folder);
catch err
 record.status='failed_execution';record.error=err.message;teach_writejson(fullfile(folder,'record.json'),record);rethrow(err);
end
 function phase(value)
  record.phase=value;teach_writejson(fullfile(folder,'record.json'),record);fprintf('N3_PHASE %s %s\n',caseId,value);
 end
end
function values=read_motor_pi(mdl)
ws=get_param(mdl,'ModelWorkspace');values=struct;
for key={'Rs','Ld','Lq','phis','p','J','F','Vdc','Iq_limit','kp_w','ki_w','ks_w','kp_id','ki_id','ks_id','kp_iq','ki_iq','ks_iq'}
 values.(key{1})=getVariable(ws,key{1});
end
end
function close_private(mdl)
if bdIsLoaded(mdl),close_system(mdl,0);end
end
