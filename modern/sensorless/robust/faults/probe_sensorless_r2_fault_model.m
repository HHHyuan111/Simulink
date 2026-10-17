function report=probe_sensorless_r2_fault_model(folder,id,duration)
% Compile/short simulation only; this probe cannot establish fault recovery.
if nargin<2,id='r1_short_logging_check';end
if nargin<3,duration=0;end
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);mdl='PMSM_FOC_R2026a';
for d={'','sensorless','sensorless/robust','sensorless/robust/integration','sensorless/robust/performance','sensorless/robust/execution_v3','sensorless/robust/phase_guard','sensorless/robust/faults','teaching','control','timing','deadtime','framework','layout/appearance'},addpath(fullfile(modern,d{1}));end
assert(~bdIsLoaded(mdl));report=sensorless_r2_fault_snapshot(folder);report.case_id=id;report.process_id=feature('getpid');report.simulation_called=duration>0;report.short_probe_only=true;
cleanup=onCleanup(@()close_private(mdl));Simulink.fileGenControl('set','CacheFolder',fullfile(folder,'.build/cache'),'CodeGenFolder',fullfile(folder,'.build/codegen'),'createDir',true);
try
 report=stage(report,folder,'load');load_system(fullfile(modern,[mdl '.slx']));pmsm_reference('restore');original=teach_snapshot(mdl);fixed=pmsm_reference('capture');originalInit=get_param(mdl,'InitFcn');
 plan=jsondecode(fileread(fullfile(base,'contracts/nonideal_r2_test_plan.json')));cases=plan.cases;if ~iscell(cases),cases=num2cell(cases);end
 testcase=cases{find(cellfun(@(x)strcmp(x.id,id),cases))};backup=sensorless_v2_stimulus(mdl,testcase);sensorless_r2_initialize_stopped(mdl);pwm=[];
 if strcmp(id,'deadline_jitter'),pwm=sensorless_r2_fault_pwm_model(mdl,sensorless_r2_fault_program(testcase));end
 configured=teach_snapshot(mdl);report=stage(report,folder,'install');pmsm_sensorless_v2_model('install',mdl,0);sensorless_r2_phase_guard_model(mdl);
 sensorless_r2_logging(mdl);report.adapter=sensorless_r2_fault_model(mdl,testcase);
 if strcmp(id,'deadline_jitter'),sensorless_r2_pwm_event_logging(mdl);end
 sensorless_r2_initialize_stopped(mdl);
 set_param([mdl '/无感观测/观测/R2累计记录'],'SampleTime','50e-6');
 report=stage(report,folder,'observer_compile');set_param(mdl,'SimulationCommand','update');report.graph=check_sensorless_v2_graph(mdl,configured);assert(report.graph.passed);
 if duration>0
  report=stage(report,folder,'short_simulate');out=sim(mdl,'StopTime',num2str(duration,17));signals=struct;
  for key=out.who',series=out.get(key{1});if isa(series,'timeseries'),signals.(key{1})=series;end,end
  save(fullfile(folder,'signals.mat'),'-struct','signals','-v7.3');report.raw_sha256=teach_hash(fullfile(folder,'signals.mat'));report.log_count=numel(fieldnames(signals));
 end
 report=stage(report,folder,'restore');pmsm_sensorless_v2_model('remove',mdl);assert(isequaln(configured,teach_snapshot(mdl)));
 if ~isempty(pwm),sensorless_r2_restore_fault_pwm(pwm);end
 set_param(mdl,'InitFcn',originalInit);sensorless_n3_restore(mdl,backup);assert(isequaln(original,teach_snapshot(mdl))&&isequaln(fixed,pmsm_reference('capture')));
 sensorless_v2_guard_sources(report);report.phase='completed';report.status='diagnostic_passed';report.restored=true;teach_writejson(fullfile(folder,'record.json'),report);
catch err
 report.status='failed_execution';report.error=getReport(err,'extended','hyperlinks','off');teach_writejson(fullfile(folder,'record.json'),report);rethrow(err);
end
end
function report=stage(report,folder,phase)
report.phase=phase;teach_writejson(fullfile(folder,'record.json'),report);
end
function close_private(mdl)
if bdIsLoaded(mdl),close_system(mdl,0);end
end
