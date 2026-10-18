function report=probe_sensorless_r2_single_reference_logging(folder)
% Verify that a single zero-output referenced observer can retain its logs.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);addpath(fullfile(modern,'teaching'));
assert(~isfolder(folder));mkdir(folder);parent='r2_single_log_parent';child='r2_single_log_child';
assert(~bdIsLoaded(parent)&&~bdIsLoaded(child));cleanup=onCleanup(@()close_private(parent,child));
report=struct('kind','single_reference_logging','phase','construct','all_passed',false,'process_id',matlabProcessID,...
 'matlab_version',version,'normal_starts',0,'rapid_starts',0,'R2_passed',false,'main_model_loaded',false);
source=[mfilename('fullpath') '.m'];copyfile(source,fullfile(folder,'probe_source.m.txt'));report.probe_sha256=teach_hash(source);
contract=fullfile(base,'contracts/nonideal_r2_single_reference_logging_probe.json');copyfile(contract,fullfile(folder,'contract.json'));report.contract_sha256=teach_hash(contract);
try
 generation=fullfile(base,'.build','single_reference_logging',char(java.util.UUID.randomUUID));
 Simulink.fileGenControl('set','CacheFolder',fullfile(generation,'c'),'CodeGenFolder',fullfile(generation,'g'),'createDir',true);
 report.generation_folder=generation;
 new_system(child);set_param(child,'SolverType','Fixed-step','Solver','FixedStepDiscrete','FixedStep','62.5e-9',...
  'ModelReferenceNumInstancesAllowed','Single','SolverMode','SingleTasking','EnableMultiTasking','off','ReturnWorkspaceOutputs','on','SaveTime','off','SaveOutput','off','SignalLogging','off');
 ws=get_param(child,'ModelWorkspace');ws.DataSource='Model File';assignin(ws,'gain',3.25);
 add_block('built-in/Inport',[child '/NativeTime'],'PortDimensions','1','OutDataTypeStr','double','SampleTime','62.5e-9');
 add_block('simulink/Math Operations/Gain',[child '/Gain'],'Gain','gain');add_line(child,'NativeTime/1','Gain/1');
 add_block('simulink/Signal Routing/Mux',[child '/Pair'],'Inputs','2');add_line(child,'NativeTime/1','Pair/1');add_line(child,'Gain/1','Pair/2');
 log(child,'Pair/1','child_native','-1');
 add_block('simulink/Sources/Digital Clock',[child '/JEOS'],'SampleTime','[50e-6 28.875e-6]');log(child,'JEOS/1','child_jeos','-1');
 childFile=fullfile(folder,[child '.slx']);save_system(child,childFile);report.child_file_sha256=teach_hash(childFile);addpath(folder);
 new_system(parent);set_param(parent,'SolverType','Fixed-step','Solver','ode4','FixedStep','62.5e-9','SolverMode','SingleTasking','EnableMultiTasking','off',...
  'StopTime','.02','ReturnWorkspaceOutputs','on','SaveTime','off','SaveOutput','off','SignalLogging','off');
 add_block('simulink/Sources/Digital Clock',[parent '/NativeTime'],'SampleTime','62.5e-9');
 add_block('simulink/Ports & Subsystems/Model',[parent '/Observer'],'ModelName',child,'SimulationMode','Normal');add_line(parent,'NativeTime/1','Observer/1');
 add_block('simulink/Sources/Clock',[parent '/ContinuousTime']);add_block('simulink/Continuous/Integrator',[parent '/ContinuousIntegral']);
 add_line(parent,'ContinuousTime/1','ContinuousIntegral/1');log(parent,'ContinuousIntegral/1','parent_integral','62.5e-9');
 parentFile=fullfile(folder,[parent '.slx']);save_system(parent,parentFile);report.parent_file_sha256=teach_hash(parentFile);
 refs=find_system(parent,'BlockType','ModelReference','ModelName',child);assert(numel(refs)==1);p=get_param(refs{1},'PortHandles');assert(numel(p.Inport)==1&&isempty(p.Outport));
 report.actual_references=1;report.allowed_references=get_param(child,'ModelReferenceNumInstancesAllowed');assert(strcmp(report.allowed_references,'Single'));
 report.normal_starts=1;stage('normal_once');normal=sim(parent,'SimulationMode','normal');save(fullfile(folder,'normal_raw.mat'),'normal','-v7.3');assert(isempty(normal.ErrorMessage));
 stage('build_rapid_once');rtp=Simulink.BlockDiagram.buildRapidAcceleratorTarget(parent);save(fullfile(folder,'rtp.mat'),'rtp');
 report.rapid_starts=1;stage('rapid_once');rapid=sim(parent,'SimulationMode','rapid-accelerator');save(fullfile(folder,'rapid_raw.mat'),'rapid','-v7.3');assert(isempty(rapid.ErrorMessage));
 report.comparison=compare(normal,rapid);report.all_passed=report.comparison.all_passed&&getVariable(ws,'gain')==3.25&&...
  strcmp(report.parent_file_sha256,teach_hash(parentFile))&&strcmp(report.child_file_sha256,teach_hash(childFile));
 report.normal_raw_sha256=teach_hash(fullfile(folder,'normal_raw.mat'));report.rapid_raw_sha256=teach_hash(fullfile(folder,'rapid_raw.mat'));
 assert(report.all_passed);stage('completed');
catch err
 report.phase_at_error=report.phase;report.phase='failed';report.error_identifier=err.identifier;teach_writejson(fullfile(folder,'report.json'),report);rethrow(err);
end
 function stage(label),report.phase=label;teach_writejson(fullfile(folder,'report.json'),report);fprintf('SINGLE_REFERENCE_LOGGING %s\n',label);end
end
function result=compare(a,b)
expected=sort({'child_native';'child_jeos';'parent_integral'});namesA=a.who;namesB=b.who;
assert(isequal(sort(namesA(:)),expected)&&isequal(sort(namesB(:)),expected));rows=struct;
for k=1:numel(expected)
 name=expected{k};x=a.get(name);y=b.get(name);assert(isa(x,'timeseries')&&isa(y,'timeseries'));
 rows.(name)=struct('Time_equal',isequal(x.Time,y.Time),'Data_equal',isequal(x.Data,y.Data),...
  'class_equal',strcmp(class(x.Data),class(y.Data)),'dimensions_equal',isequal(size(x.Data),size(y.Data)),...
  'finite',all(isfinite([x.Time(:);x.Data(:);y.Time(:);y.Data(:)])));
end
x=a.get('child_native');v=teach_values(x);j=a.get('child_jeos');
result=struct('logs',3,'details',rows,'native_rows',numel(x.Time)==320001,'native_ticks',isequal(round(x.Time/62.5e-9),(0:320000)'),...
 'JEOS_rows',numel(j.Time)==400,'JEOS_ticks',isequal(round(j.Time/62.5e-9),(462:800:320000)'),...
 'gain_exact',isequal(v(:,2),v(:,1)*3.25));
result.all_passed=all(structfun(@(row)all(structfun(@(v)v,row)),rows))&&result.native_rows&&result.native_ticks&&result.JEOS_rows&&result.JEOS_ticks&&result.gain_exact;
end
function log(mdl,src,name,sample)
add_block('simulink/Sinks/To Workspace',[mdl '/Log_' name],'VariableName',name,'SaveFormat','Timeseries','SampleTime',sample,'MaxDataPoints','inf');add_line(mdl,src,['Log_' name '/1']);
end
function close_private(parent,child)
if bdIsLoaded(parent),close_system(parent,0);end
if bdIsLoaded(child),close_system(child,0);end
end
