function report=probe_sensorless_r2_native_logger(folder)
% Minimal native evaluation/logging reproducer; no electric plant or core.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);
addpath(fullfile(base,'robust/performance'),fullfile(modern,'teaching'));assert(~isfolder(folder));mkdir(folder);
mdl='sless_native_logger_probe';assert(~bdIsLoaded(mdl));h=62.5e-9;
report=struct('kind','reduced_native_monitor_logger','all_passed',false,'phase','source_check',...
 'plant_reexecuted',false,'synthetic_negative_control',true,'R2_case_status_changed',false,'process_id',feature('getpid'),'matlab_version',version);
copyfile([mfilename('fullpath') '.m'],fullfile(folder,'probe_source.m.txt'));report.probe_sha256=teach_hash([mfilename('fullpath') '.m']);
contract=fullfile(base,'contracts/nonideal_r2_native_logger_diagnostic.json');copyfile(contract,fullfile(folder,'contract.json'));report.contract_sha256=teach_hash(contract);
referencePlan=jsondecode(fileread(fullfile(base,'contracts/nonideal_r2_core_replay_diagnostic.json')));
reference=jsondecode(fileread(fullfile(base,referencePlan.reference_folder,'record.json')));
files={'robust/performance/sensorless_r2_logging.m','robust/performance/blocks/sless_r2_monitor_block.m',...
 'robust/performance/sensorless_r2_monitor_step.m','robust/performance/sensorless_r2_monitor_state.m','robust/performance/sensorless_r2_event_audit.m'};
report.sources=struct('path',{},'sha256',{});
for k=1:numel(files)
 relative=files{k};source=fullfile(base,relative);index=find(strcmp({reference.source_files.path},relative));assert(isscalar(index)&&strcmp(teach_hash(source),reference.source_files(index).sha256));
 target=fullfile(folder,'source',relative);if ~isfolder(fileparts(target)),mkdir(fileparts(target));end,copyfile(source,target);
 report.sources(end+1)=struct('path',relative,'sha256',teach_hash(source));
end
copyfile(fullfile(here,'sless_r2_native_fixture_block.m'),fullfile(folder,'fixture_source.m.txt'));report.fixture_sha256=teach_hash(fullfile(here,'sless_r2_native_fixture_block.m'));
generation=fullfile(base,'.build','nl',char(java.util.UUID.randomUUID));Simulink.fileGenControl('set','CacheFolder',fullfile(generation,'c'),'CodeGenFolder',fullfile(generation,'g'),'createDir',true);
cleanup=onCleanup(@()close_private(mdl));
try
 stage('create_fixture_graph');new_system(mdl);set_param(mdl,'SolverType','Fixed-step','Solver','FixedStepDiscrete','FixedStep','62.5e-9',...
  'StopTime','.8','SaveTime','off','SaveOutput','off','SignalLogging','off','ReturnWorkspaceOutputs','on');
 ws=get_param(mdl,'ModelWorkspace');assignin(ws,'timing_h',h);assignin(ws,'dt',50e-6);
 root=[mdl '/无感观测'];add_block('built-in/SubSystem',root);add_block('built-in/SubSystem',[root '/观测']);
 add_block('simulink/Sources/Digital Clock',[root '/Native_clock'],'SampleTime','62.5e-9');route('Native_clock',1,'SLessV2_native_time');
 add_block('simulink/User-Defined Functions/MATLAB Function',[root '/Fixture']);rt=sfroot;c=rt.find('-isa','Stateflow.EMChart','Path',[root '/Fixture']);c.Script=fileread(fullfile(here,'sless_r2_native_fixture_block.m'));
 c.ChartUpdate='DISCRETE';c.SampleTime='62.5e-9';c.VectorOutputs1D=false;
 sizes={'t','1';'pub','[13 1]';'permit','1';'reason','1';'adc_valid','1';'timing_valid','1';'reset','1';'truth_theta','1';'truth_rpm','1'};
 for k=1:size(sizes,1)
  d=c.find('-isa','Stateflow.Data','Name',sizes{k,1});d.Props.Array.Size=sizes{k,2};d.DataType='double';if ismember(sizes{k,1},{'permit','adc_valid','timing_valid','reset'}),d.DataType='boolean';end
 end
 add_line(root,'Native_clock/1','Fixture/1','autorouting','on');
 tags={'SLessV2_publication','SLessV2_control_permit','SLessV2_deny_reason','SLessV2_adc_valid','SLessV2_timing_valid','SLessV2_reset','theta_e','speed'};
 for k=1:numel(tags),route('Fixture',k,tags{k});end
 stage('install_original_monitor_logger');report.logging=sensorless_r2_logging(mdl);set_param([root '/观测/R2累计记录'],'SampleTime','50e-6');
 save_system(mdl,fullfile(folder,[mdl '.slx']));report.model_sha256=teach_hash(fullfile(folder,[mdl '.slx']));
 stage('compile_and_run_native_fixture');started=tic;out=sim(mdl);report.elapsed_s=toc(started);assert(isempty(out.ErrorMessage));
 counters=out.get('obs_sless_r2_native_counters');events=out.get('obs_sless_r2_native_events');cdata=teach_values(counters);edata=teach_values(events);
 stage('independent_event_oracle');expected=unique([0:800:12800000 510:800:12800000 3232001 9600462 9601262])';
 audit=sensorless_r2_event_audit(edata,cdata,h);report.audit=audit;
 checks=struct('native_endpoint',cdata(end,12)==12800001&&abs(cdata(end,1)-.8)<1e-12,...
  'counter_count',numel(counters.Time)==16001,'event_ticks_exact',isequal(round(events.Time/h),expected)&&numel(expected)==32004,...
  'false_valid_longest_ticks',round(cdata(end,2)/h)==32001,'false_valid_total_ticks',round(cdata(end,3)/h)==32001,...
  'permit_total_ticks',round(cdata(end,4)/h)==11995200,'permission_violations_zero',all(cdata(end,5:7)==0),'event_counter_audit',audit.all_passed);
 report.checks=checks;report.all_passed=all(structfun(@(x)x,checks));report.native_evaluations=cdata(end,12);report.events=size(edata,1);report.counter_samples=size(cdata,1);
 report.deliberate_false_valid_longest_s=cdata(end,2);report.permission_duration_s=cdata(end,4);
 save(fullfile(folder,'signals.mat'),'counters','events','-v7.3');report.raw_sha256=teach_hash(fullfile(folder,'signals.mat'));
 for k=1:numel(report.sources),assert(strcmp(teach_hash(fullfile(base,report.sources(k).path)),report.sources(k).sha256));end
 report.phase='completed';teach_writejson(fullfile(folder,'report.json'),report);fprintf('NATIVE_LOGGER_COMPLETE passed=%d\n',report.all_passed);
catch err
 report.phase_at_error=report.phase;report.phase='diagnostic_error';report.error=getReport(err,'extended','hyperlinks','off');teach_writejson(fullfile(folder,'report.json'),report);rethrow(err);
end
 function stage(name)
  report.phase=name;teach_writejson(fullfile(folder,'report.json'),report);fprintf('NATIVE_LOGGER_PHASE %s\n',name);
 end
 function route(source,port,tag)
  dest=['Publish_' tag];add_block('simulink/Signal Routing/Goto',[root '/' dest],'GotoTag',tag,'TagVisibility','scoped');
  add_block('simulink/Signal Routing/Goto Tag Visibility',[root '/Visible_' tag],'GotoTag',tag);add_line(root,[source '/' num2str(port)],[dest '/1'],'autorouting','on');
 end
end
function close_private(mdl)
if bdIsLoaded(mdl),close_system(mdl,0);end
end
