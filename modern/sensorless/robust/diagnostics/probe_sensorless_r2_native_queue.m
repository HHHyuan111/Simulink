function report=probe_sensorless_r2_native_queue(folder)
% Native queue execution isolation. Synthetic evidence never closes R2 cases.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);
for part={'robust','robust/integration','robust/faults','robust/faults/blocks'},addpath(fullfile(base,part{1}));end
addpath(fullfile(modern,'teaching'));assert(~isfolder(folder));mkdir(folder);
mdl='sless_native_queue_probe';assert(~bdIsLoaded(mdl));h=62.5e-9;
report=struct('kind','reduced_native_publication_queue','all_passed',false,'phase','source_check',...
 'plant_reexecuted',false,'whole_model_fault_acceptance',false,'R2_case_status_changed',false,...
 'process_id',matlabProcessID,'matlab_version',version);
copyfile([mfilename('fullpath') '.m'],fullfile(folder,'probe_source.m.txt'));report.probe_sha256=teach_hash([mfilename('fullpath') '.m']);
contract=fullfile(base,'contracts/nonideal_r2_native_queue_diagnostic.json');copyfile(contract,fullfile(folder,'contract.json'));report.contract_sha256=teach_hash(contract);
reference=fullfile(base,'runs/N3R2_constructor_short_20261018_091939_61018e3f-c571-4ab4-9337-60370a02e273/r1_short_logging_check_attempt_1/record.json');
parent=jsondecode(fileread(reference));assert(strcmp(parent.status,'passed'));report.reference_record_sha256=teach_hash(reference);
files={'robust/faults/blocks/sless_r2_queue_block.m','robust/faults/sensorless_r2_fault_queue_step.m',...
 'robust/faults/sensorless_r2_fault_queue_state.m','robust/integration/sensorless_v2_config_rt.m',...
 'robust/integration/sensorless_v2_queue_step.m','robust/integration/sensorless_v2_queue_state.m',...
 'robust/sensorless_robust_state.m','robust/sensorless_publish_step.m','robust/sensorless_event_plan.m'};
report.sources=struct('path',{},'sha256',{});
for k=1:numel(files)
 relative=files{k};source=fullfile(base,relative);index=find(strcmp({parent.source_files.path},relative));assert(isscalar(index));
 assert(strcmp(teach_hash(source),parent.source_files(index).sha256));[~,name]=fileparts(source);assert(strcmpi(which(name),source));
 target=fullfile(folder,'source',relative);if ~isfolder(fileparts(target)),mkdir(fileparts(target));end,copyfile(source,target);
 report.sources(end+1)=struct('path',relative,'sha256',teach_hash(source));
end
report.diagnostic_sources=struct('path',{},'sha256',{});
for fixtureFile={'sless_r2_queue_fixture_block.m','sless_r2_queue_audit_block.m'}
 relative=['robust/diagnostics/' fixtureFile{1}];copyfile(fullfile(here,fixtureFile{1}),fullfile(folder,fixtureFile{1}));
 report.diagnostic_sources(end+1)=struct('path',relative,'sha256',teach_hash(fullfile(here,fixtureFile{1})));
end
generation=fullfile(base,'.build','nq',char(java.util.UUID.randomUUID));
Simulink.fileGenControl('set','CacheFolder',fullfile(generation,'c'),'CodeGenFolder',fullfile(generation,'g'),'createDir',true);
cleanup=onCleanup(@()close_private(mdl));
try
 stage('create_reduced_graph');new_system(mdl);set_param(mdl,'SolverType','Fixed-step','Solver','FixedStepDiscrete','FixedStep','62.5e-9',...
  'StopTime','.8','SaveTime','off','SaveOutput','off','SignalLogging','off','ReturnWorkspaceOutputs','on');
 ws=get_param(mdl,'ModelWorkspace');assignin(ws,'front',reshape(parent.config_vector,1,[]));
 add_block('simulink/Sources/Digital Clock',[mdl '/Native_clock'],'SampleTime','62.5e-9');route('Native_clock',1,'time');
 add_block('simulink/Sources/Constant',[mdl '/Config'],'Value','front','VectorParams1D','off');route('Config',1,'cfg');
 chart('Fixture',fullfile(here,'sless_r2_queue_fixture_block.m'),...
  {'t','1';'theta','1';'omega','1';'quality','1';'adc_valid','1';'timing_valid','1';'reset','1';'missing','1';'jitter','1'},...
  {'quality','adc_valid','timing_valid','reset','missing'},{'time'},...
  {'theta','omega','quality','adc_valid','timing_valid','reset','missing','jitter'});
 chart('Original_queue',fullfile(base,files{1}),...
  {'t','1';'theta','1';'omega','1';'observer_valid','1';'input_valid','1';'timing_valid','1';'cfg','[1 35]';...
   'reset','1';'missing','1';'jitter','1';'values','[13 1]';'permit','1';'reason','1';'diagnostic','[8 1]'},...
  {'observer_valid','input_valid','timing_valid','reset','missing','permit'},...
  {'time','theta','omega','quality','adc_valid','timing_valid','cfg','reset','missing','jitter'},...
  {'values','permit','reason','diagnostic'});
 chart('Independent_audit',fullfile(here,'sless_r2_queue_audit_block.m'),...
  {'t','1';'values','[13 1]';'permit','1';'reason','1';'diagnostic','[8 1]';'counters','[7 1]';'trace','[24 1]';'enable','1'},...
  {'permit','enable'},{'time','values','permit','reason','diagnostic'},{'counters','trace','enable'});
 add_block('simulink/Sinks/To Workspace',[mdl '/Counters'],'VariableName','counters','SaveFormat','Timeseries','SampleTime','50e-6','MaxDataPoints','inf');connect('counters','Counters',1);
 e=[mdl '/Event_log'];add_block('built-in/SubSystem',e);
 add_block('built-in/Inport',[e '/Data'],'PortDimensions','[24 1]');add_block('built-in/EnablePort',[e '/Enable']);
 add_block('simulink/Sinks/To Workspace',[e '/Save'],'VariableName','events','SaveFormat','Timeseries','SampleTime','-1','MaxDataPoints','inf');
 add_line(e,'Data/1','Save/1','autorouting','on');connect('trace','Event_log',1);
 add_block('simulink/Signal Routing/From',[mdl '/Event_enable'],'GotoTag','enable');add_line(mdl,'Event_enable/1','Event_log/Enable','autorouting','on');
 blocks=find_system(mdl,'SearchDepth',1,'Type','Block');
 for k=1:numel(blocks),x=30+280*mod(k-1,5);y=30+65*floor((k-1)/5);set_param(blocks{k},'Position',[x y x+190 y+35]);end
 save_system(mdl,fullfile(folder,[mdl '.slx']));report.model_sha256=teach_hash(fullfile(folder,[mdl '.slx']));
 stage('run_native_queue');started=tic;out=sim(mdl);report.elapsed_s=toc(started);assert(isempty(out.ErrorMessage));
 counters=out.get('counters');events=out.get('events');c=teach_values(counters);v=teach_values(events);
 stage('independent_integer_oracle');references=(462:800:12800000)';sequence=(0:numel(references)-1)';
 keep=references<4800462|references>=4804462;references=references(keep);sequence=sequence(keep);
 completion=references+48+16*double(references>=11200000);published=v(v(:,14)>.5,:);
 expectedEvents=unique([(0:800:12800000)';completion;4800462;9600462]);
 checks=struct('native_endpoint',c(end,2)==12800001&&abs(c(end,1)-.8)<1e-12,...
  'counter_samples',numel(counters.Time)==16001,'publication_count',c(end,3)==15995&&size(published,1)==15995,...
  'completion_ticks_exact',isequal(round(published(:,1)/h),completion),...
  'sequence_exact',isequal(published(:,2),sequence),'reference_ticks_exact',isequal(round(published(:,3)/h),references),...
  'event_ticks_exact',isequal(round(events.Time/h),expectedEvents)&&numel(expectedEvents)==31998,...
  'first_native_vetoes',c(end,7)==2,'epochs',c(end,6)==2,'permitted_prediction',c(end,5)<=1e-10,...
  'permission_before_and_after_faults',any(v(v(:,1)>.28&v(:,1)<.30,15))&&any(v(v(:,1)>.68,15)));
 report.checks=checks;report.all_passed=all(structfun(@(x)x,checks));report.native_evaluations=c(end,2);report.publications=c(end,3);report.events=size(v,1);
 report.synthetic_qualification_not_599_sample_core=true;save(fullfile(folder,'signals.mat'),'counters','events','-v7.3');report.raw_sha256=teach_hash(fullfile(folder,'signals.mat'));
 for entry=report.sources,assert(strcmp(teach_hash(fullfile(base,entry.path)),entry.sha256));end
 for entry=report.diagnostic_sources,assert(strcmp(teach_hash(fullfile(base,entry.path)),entry.sha256));end
 report.phase='completed';teach_writejson(fullfile(folder,'report.json'),report);fprintf('NATIVE_QUEUE_COMPLETE passed=%d\n',report.all_passed);
catch err
 report.phase_at_error=report.phase;report.phase='diagnostic_error';report.error=getReport(err,'extended','hyperlinks','off');teach_writejson(fullfile(folder,'report.json'),report);rethrow(err);
end
 function stage(name)
  report.phase=name;teach_writejson(fullfile(folder,'report.json'),report);fprintf('NATIVE_QUEUE_PHASE %s\n',name);
 end
 function chart(name,source,sizes,boolean,inputs,outputs)
  add_block('simulink/User-Defined Functions/MATLAB Function',[mdl '/' name]);rt=sfroot;ch=rt.find('-isa','Stateflow.EMChart','Path',[mdl '/' name]);ch.Script=fileread(source);
  ch.ChartUpdate='DISCRETE';ch.SampleTime='62.5e-9';ch.VectorOutputs1D=false;
  for j=1:size(sizes,1),chartData=ch.find('-isa','Stateflow.Data','Name',sizes{j,1});assert(isscalar(chartData));chartData.Props.Array.Size=sizes{j,2};chartData.DataType='double';if ismember(sizes{j,1},boolean),chartData.DataType='boolean';end,end
  for j=1:numel(inputs),connect(inputs{j},name,j);end
  for j=1:numel(outputs),route(name,j,outputs{j});end
 end
 function connect(tag,destination,port)
  fromName=['Input_' destination '_' num2str(port)];add_block('simulink/Signal Routing/From',[mdl '/' fromName],'GotoTag',tag);add_line(mdl,[fromName '/1'],[destination '/' num2str(port)],'autorouting','on');
 end
 function route(source,port,tag)
  gotoName=['Publish_' tag];add_block('simulink/Signal Routing/Goto',[mdl '/' gotoName],'GotoTag',tag,'TagVisibility','scoped');
  add_block('simulink/Signal Routing/Goto Tag Visibility',[mdl '/Visible_' tag],'GotoTag',tag);add_line(mdl,[source '/' num2str(port)],[gotoName '/1'],'autorouting','on');
 end
end
function close_private(mdl)
if bdIsLoaded(mdl),close_system(mdl,0);end
end
