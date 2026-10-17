function record=probe_sensorless_r2_compiled_monitor(folder)
% One-shot isolated code-generation diagnostic; no PMSM model is loaded.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));
addpath(fullfile(base,'robust','performance'),fullfile(fileparts(base),'teaching'));
assert(~isfolder(folder));mkdir(folder);mdl='sensorless_r2_monitor_probe';assert(~bdIsLoaded(mdl));
record=struct('kind','isolated_compiled_monitor_probe','acceptance_evidence',false,...
 'pmsm_loaded',false,'attempt_limit',1,'process_id',feature('getpid'),...
 'status','running','phase','create','source_sha256',teach_hash([mfilename('fullpath') '.m']));
sources={'sensorless_r2_monitor_state.m','sensorless_r2_monitor_step.m','blocks/sless_r2_monitor_block.m','sensorless_r2_event_audit.m'};
for k=1:numel(sources)
 source=fullfile(base,'robust','performance',sources{k});
 record.core_sources(k)=struct('path',sources{k},'sha256',teach_hash(source));
end
teach_writejson(fullfile(folder,'record.json'),record);
Simulink.fileGenControl('set','CacheFolder',fullfile(folder,'.build','cache'),...
 'CodeGenFolder',fullfile(folder,'.build','codegen'),'createDir',true);
cleanup=onCleanup(@()close_private(mdl));
try
 new_system(mdl);set_param(mdl,'SolverType','Fixed-step','Solver','FixedStepDiscrete',...
  'FixedStep','62.5e-9','StopTime','0.0025','ReturnWorkspaceOutputs','on');
 add_block('simulink/Sources/Clock',[mdl '/t']);
 pub=zeros(13,1);pub(6)=.2;pub(8)=1000;
 add_block('simulink/Sources/Constant',[mdl '/pub'],'Value',mat2str(pub,17),'VectorParams1D','off');
 add_block('simulink/Sources/Step',[mdl '/permit_step'],...
  'Time',num2str(32001*62.5e-9,17),'Before','1','After','0','SampleTime','62.5e-9');
 add_block('simulink/Signal Attributes/Data Type Conversion',[mdl '/permit'],'OutDataTypeStr','boolean');
 add_line(mdl,'permit_step/1','permit/1');
 constants={'reason','0','double';'adc','1','boolean';'timing','1','boolean';...
  'reset','0','boolean';'truth_theta','.5','double';'truth_rpm','1000','double'};
 for k=1:size(constants,1)
  add_block('simulink/Sources/Constant',[mdl '/' constants{k,1}],...
   'Value',constants{k,2},'OutDataTypeStr',constants{k,3});
 end
 path=[mdl '/monitor'];add_block('simulink/User-Defined Functions/MATLAB Function',path);
 rt=sfroot;chart=rt.find('-isa','Stateflow.EMChart','Path',path);
 chart.Script=fileread(fullfile(base,'robust','performance','blocks','sless_r2_monitor_block.m'));
 chart.ChartUpdate='DISCRETE';chart.SampleTime='62.5e-9';chart.VectorOutputs1D=false;
 dimensions={'t','1';'pub','[13 1]';'permit','1';'reason','1';'adc_valid','1';'timing_valid','1';...
  'reset','1';'truth_theta','1';'truth_rpm','1';'counters','[12 1]';'event','[16 1]';'changed','1'};
 for k=1:size(dimensions,1)
  data=chart.find('-isa','Stateflow.Data','Name',dimensions{k,1});data.Props.Array.Size=dimensions{k,2};data.DataType='double';
  if ismember(dimensions{k,1},{'permit','adc_valid','timing_valid','reset','changed'}),data.DataType='boolean';end
 end
 names={'t','pub','permit','reason','adc','timing','reset','truth_theta','truth_rpm'};
 for k=1:numel(names),add_line(mdl,[names{k} '/1'],['monitor/' num2str(k)]);end
 for k=1:2
  name=['log' num2str(k)];add_block('simulink/Sinks/To Workspace',[mdl '/' name],...
   'VariableName',name,'SaveFormat','Timeseries','SampleTime','62.5e-9','MaxDataPoints','inf');
  add_line(mdl,['monitor/' num2str(k)],[name '/1']);
 end
 add_block('simulink/Sinks/Terminator',[mdl '/unused']);add_line(mdl,'monitor/3','unused/1');
 record.phase='compile';teach_writejson(fullfile(folder,'record.json'),record);fprintf('R2_MONITOR_PROBE compile\n');
 set_param(mdl,'SimulationCommand','update');
 record.phase='simulate';teach_writejson(fullfile(folder,'record.json'),record);fprintf('R2_MONITOR_PROBE simulate\n');
 out=sim(mdl);log1=out.log1;log2=out.log2;
 record.phase='compare';teach_writejson(fullfile(folder,'record.json'),record);
 actual=teach_values(log1);actualEvents=teach_values(log2);assert(size(actual,1)==40001);
 expected=zeros(40001,12);expectedEvents=zeros(40001,16);s=sensorless_r2_monitor_state;h=62.5e-9;
 for tick=0:40000
  [s,c,e]=sensorless_r2_monitor_step(s,tick*h,pub,tick<32001,0,true,true,false,.5,1000,h,50e-6);
  expected(tick+1,:)=c';expectedEvents(tick+1,:)=e';
 end
 assert(isequaln(actual,expected)&&isequaln(actualEvents,expectedEvents));
 assert(actual(end,2)==32001*h&&actual(end,2)>.002);
 audit=sensorless_r2_event_audit(actualEvents,actual,h);assert(audit.all_passed);
 save(fullfile(folder,'probe.mat'),'log1','log2','expected','expectedEvents','audit','-v7.3');
 for k=1:numel(sources)
  assert(strcmp(record.core_sources(k).sha256,teach_hash(fullfile(base,'robust','performance',sources{k}))));
 end
 record.status='diagnostic_passed';record.phase='completed';record.native_samples=size(actual,1);
 record.false_valid_longest_s=actual(end,2);record.exact_elements=numel(actual)+numel(actualEvents);
 record.raw_sha256=teach_hash(fullfile(folder,'probe.mat'));record.event_audit=audit;
 teach_writejson(fullfile(folder,'record.json'),record);fprintf('R2_MONITOR_PROBE_COMPLETED exact_elements=%d\n',record.exact_elements);
catch err
 record.status='failed_execution';record.error=getReport(err,'extended','hyperlinks','off');teach_writejson(fullfile(folder,'record.json'),record);rethrow(err);
end
end
function close_private(mdl)
if bdIsLoaded(mdl),close_system(mdl,0);end
end
