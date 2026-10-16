function record=validate_sensorless_v2_case(id,folder,observer)
% One short physical integration attempt in a private fresh MATLAB process.
if nargin<3,observer=true;end
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);mdl='PMSM_FOC_R2026a';
for directory={'','sensorless','sensorless/robust','sensorless/robust/integration','teaching','control','timing','deadtime','framework','layout/appearance'},addpath(fullfile(modern,directory{1}));end
assert(~bdIsLoaded(mdl));record=sensorless_v2_snapshot_sources(folder);record.case_id=id;record.observer_present=observer;
plan=jsondecode(fileread(fullfile(base,'contracts','nonideal_r1_test_plan.json')));cases=plan.integration_cases;
i=find(strcmp({cases.id},id));assert(isscalar(i));testcase=cases(i);
if strcmp(id,'window')
 amendment=jsondecode(fileread(fullfile(base,'contracts','nonideal_r1_window_addendum.json')));
 testcase.window_settle_s=amendment.window_settle_s;
end
record.effective_case=testcase;
Simulink.fileGenControl('set','CacheFolder',fullfile(folder,'.build','cache'),'CodeGenFolder',fullfile(folder,'.build','codegen'),'createDir',true);
sldiagviewer.diary(fullfile(folder,'diagnostics.log'),'UTF-8');cleanup=onCleanup(@()close_private(mdl));
try
 phase('load');load_system(fullfile(modern,[mdl '.slx']));pmsm_reference('restore');original=teach_snapshot(mdl);fixed=pmsm_reference('capture');
 phase('configure');backup=sensorless_v2_stimulus(mdl,testcase);set_param(mdl,'SimulationCommand','update');configured=teach_snapshot(mdl);
 ws=get_param(mdl,'ModelWorkspace');record.control_sample=getVariable(ws,'timing_control_sample');record.speed_sample=getVariable(ws,'timing_speed_sample');
 record.h_s=getVariable(ws,'timing_h');record.configuration=teach_settings(mdl);
 assert(max(abs(record.control_sample-[50e-6 28.875e-6]))<1e-15);assert(max(abs(record.speed_sample-[100e-6 78.875e-6]))<1e-15);assert(record.h_s==62.5e-9);
 if observer
  phase('install');pmsm_sensorless_v2_model('install',mdl,testcase.interference_s);
  phase('compile');set_param(mdl,'SimulationCommand','update');graph=check_sensorless_v2_graph(mdl,configured);
  teach_writejson(fullfile(folder,'graph.json'),graph);assert(graph.passed,'R1 graph checks failed.');
  record.config_vector=getVariable(ws,'sless_v2_cfg');record.observer_config=getVariable(ws,'sless_cfg');
 end
 phase('simulate');started=tic;out=sim(mdl,'StopTime',num2str(testcase.duration_s,17));record.elapsed_s=toc(started);
 phase('archive');signals=struct;
 for key=out.who'
  series=out.get(key{1});if ~isa(series,'timeseries'),continue;end
  assert(all(isfinite(series.Time),'all')&&all(isfinite(series.Data),'all'),'Nonfinite data: %s',key{1});signals.(key{1})=series;
 end
 save(fullfile(folder,'signals.mat'),'-struct','signals','-v7.3');record.raw_sha256=teach_hash(fullfile(folder,'signals.mat'));record.log_count=numel(fieldnames(signals));
 if observer
  phase('audit');metrics=audit_sensorless_v2_case(signals,record,testcase);teach_writejson(fullfile(folder,'metrics.json'),metrics);assert(metrics.all_passed);
  pmsm_sensorless_v2_model('remove',mdl);
 end
 phase('restore');afterLayer=teach_snapshot(mdl);record.layer_restored=isequaln(configured,afterLayer);
 sensorless_n3_restore(mdl,backup);after=teach_snapshot(mdl);afterFixed=pmsm_reference('capture');
 record.reference_restored=isequaln(original,after)&&isequaln(fixed,afterFixed);
 save(fullfile(folder,'restoration.mat'),'original','configured','afterLayer','after','fixed','afterFixed');
 assert(record.layer_restored&&record.reference_restored,'R1 model restoration failed.');sensorless_v2_guard_sources(record);
 record.status='passed';record.phase='completed';record.all_passed=true;teach_writejson(fullfile(folder,'record.json'),record);
 fprintf('N3R1_CASE_PASSED %s observer=%d folder=%s\n',id,observer,folder);
catch err
 record.status='failed';record.error=getReport(err,'extended','hyperlinks','off');teach_writejson(fullfile(folder,'record.json'),record);rethrow(err);
end
 function phase(value)
  record.phase=value;teach_writejson(fullfile(folder,'record.json'),record);fprintf('N3R1_PHASE %s %s observer=%d\n',id,value,observer);
 end
end
function close_private(mdl)
if bdIsLoaded(mdl),close_system(mdl,0);end
end
