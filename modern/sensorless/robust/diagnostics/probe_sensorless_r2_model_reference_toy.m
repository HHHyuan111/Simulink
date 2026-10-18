function report=probe_sensorless_r2_model_reference_toy(folder)
% Model boundary feasibility only; no motor or completed observer case rerun.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);
addpath(fullfile(modern,'teaching'),fullfile(base,'robust/execution_v8'));assert(~isfolder(folder));mkdir(folder);
parent='sl_r2_mrp';child='sl_r2_mrc';assert(~bdIsLoaded(parent)&&~bdIsLoaded(child));
report=struct('kind','normal_model_reference_logging_feasibility','all_passed',false,'phase','create_child',...
 'plant_reexecuted',false,'whole_model_fault_acceptance',false,'R2_case_status_changed',false,'process_id',matlabProcessID,'matlab_version',version);
copyfile([mfilename('fullpath') '.m'],fullfile(folder,'probe_source.m.txt'));report.probe_sha256=teach_hash([mfilename('fullpath') '.m']);
contract=fullfile(base,'contracts/nonideal_r2_model_reference_toy.json');copyfile(contract,fullfile(folder,'contract.json'));report.contract_sha256=teach_hash(contract);
generation=fullfile(base,'.build','mr',char(java.util.UUID.randomUUID));Simulink.fileGenControl('set','CacheFolder',fullfile(generation,'c'),'CodeGenFolder',fullfile(generation,'g'),'createDir',true);
cleanup=onCleanup(@()close_private(parent,child));sm=[];addpath(folder);
try
 new_system(child);configure(child);ws=get_param(child,'ModelWorkspace');assignin(ws,'offset',1.234);
 add_block('built-in/Inport',[child '/Input'],'PortDimensions','1','SampleTime','62.5e-9');
 add_block('simulink/Math Operations/Bias',[child '/Child_offset'],'Bias','offset');add_line(child,'Input/1','Child_offset/1','autorouting','on');
 add_block('simulink/Sources/Digital Clock',[child '/Native_clock'],'SampleTime','62.5e-9');
 add_block('simulink/Signal Routing/Mux',[child '/Native_pair'],'Inputs','2');add_line(child,'Native_clock/1','Native_pair/1','autorouting','on');add_line(child,'Child_offset/1','Native_pair/2','autorouting','on');
 log_block(child,'Native_pair','Native_log','ref_native','-1');
 add_block('simulink/Sources/Digital Clock',[child '/JEOS_clock'],'SampleTime','[50e-6 28.875e-6]');log_block(child,'JEOS_clock','JEOS_log','ref_jeos','-1');
 add_block('simulink/User-Defined Functions/MATLAB Function',[child '/Completion_hit']);rt=sfroot;ch=rt.find('-isa','Stateflow.EMChart','Path',[child '/Completion_hit']);
 ch.Script=sprintf('function hit=f(t)\n%%#codegen\nk=round(t/62.5e-9);hit=k>=510&&mod(k-510,800)==0;\nend\n');ch.ChartUpdate='DISCRETE';ch.SampleTime='62.5e-9';ch.VectorOutputs1D=false;
 data=ch.find('-isa','Stateflow.Data','Name','t');data.DataType='double';data.Props.Array.Size='1';data=ch.find('-isa','Stateflow.Data','Name','hit');data.DataType='boolean';data.Props.Array.Size='1';
 add_line(child,'Native_clock/1','Completion_hit/1','autorouting','on');e=[child '/Completion_log'];add_block('built-in/SubSystem',e);
 add_block('built-in/Inport',[e '/Data'],'PortDimensions','1');add_block('built-in/EnablePort',[e '/Enable']);
 add_block('simulink/Sinks/To Workspace',[e '/Save'],'VariableName','ref_completion','SaveFormat','Timeseries','SampleTime','-1','MaxDataPoints','inf');add_line(e,'Data/1','Save/1','autorouting','on');
 add_line(child,'Native_clock/1','Completion_log/1','autorouting','on');add_line(child,'Completion_hit/1','Completion_log/Enable','autorouting','on');
 save_system(child,fullfile(folder,[child '.slx']));report.child_model_sha256=teach_hash(fullfile(folder,[child '.slx']));
 stage('create_parent_reference');new_system(parent);configure(parent);parentWs=get_param(parent,'ModelWorkspace');assignin(parentWs,'offset',100);
 add_block('simulink/Sources/Constant',[parent '/Input'],'Value','9.876');
 add_block('simulink/Ports & Subsystems/Model',[parent '/Observer_boundary'],'ModelName',child,'SimulationMode','Normal');
 add_line(parent,'Input/1','Observer_boundary/1','autorouting','on');save_system(parent,fullfile(folder,[parent '.slx']));report.parent_model_sha256=teach_hash(fullfile(folder,[parent '.slx']));
 stage('initialize_reference_once');sm=simulation(parent);sm=setModelParameter(sm,StopTime='.02');initialize(sm);assert(strcmp(sm.Status,'initialized'));
 ports=get_param([parent '/Observer_boundary'],'PortHandles');report.input_ports=numel(ports.Inport);report.output_ports=numel(ports.Outport);
 assert(getVariable(ws,'offset')==1.234&&getVariable(parentWs,'offset')==100);
 stage('advance_reference_hierarchy');[out,report.execution]=sensorless_r2_run_initialized(sm,62.5e-9,.02,folder);clear sm;sm=[];assert(isempty(out.ErrorMessage));
 report.output_variables=sort(out.who);expectedNames=sort({'ref_native';'ref_jeos';'ref_completion'});assert(isequal(report.output_variables(:),expectedNames));
 native=out.get('ref_native');jeos=out.get('ref_jeos');completion=out.get('ref_completion');assert(isa(native,'timeseries')&&isa(jeos,'timeseries')&&isa(completion,'timeseries'));
 n=teach_values(native);j=teach_values(jeos);p=teach_values(completion);h=62.5e-9;
 checks=struct('native_rows',isequal(size(n),[320001 2]),'native_ticks',isequal(round(native.Time/h),(0:320000)'),...
  'native_data_ticks',isequal(round(n(:,1)/h),(0:320000)'),...
  'JEOS_ticks',numel(jeos.Time)==400&&isequal(round(jeos.Time/h),(462:800:320000)')&&isequal(round(j/h),(462:800:320000)'),...
  'completion_ticks',numel(completion.Time)==400&&isequal(round(completion.Time/h),(510:800:320000)')&&isequal(round(p/h),(510:800:320000)'),...
  'workspace_scope',all(n(:,2)==9.876+1.234)&&getVariable(ws,'offset')==1.234&&getVariable(parentWs,'offset')==100,...
  'zero_output_model_executed',report.input_ports==1&&report.output_ports==0,'normal_mode',strcmpi(get_param([parent '/Observer_boundary'],'SimulationMode'),'normal'));
 report.checks=checks;report.all_passed=all(structfun(@(x)x,checks));report.native_rows=size(n,1);report.JEOS_rows=numel(jeos.Time);report.completion_rows=numel(completion.Time);
 save(fullfile(folder,'signals.mat'),'native','jeos','completion','-v7.3');report.raw_sha256=teach_hash(fullfile(folder,'signals.mat'));
 report.phase='completed';teach_writejson(fullfile(folder,'report.json'),report);fprintf('MODEL_REFERENCE_TOY passed=%d\n',report.all_passed);
catch err
 report.phase_at_error=report.phase;report.phase='diagnostic_error';report.error=getReport(err,'extended','hyperlinks','off');teach_writejson(fullfile(folder,'report.json'),report);
 try
  if ~isempty(sm)&&~strcmp(sm.Status,'inactive'),terminate(sm);end
 catch
 end
 rethrow(err);
end
 function stage(label)
  report.phase=label;teach_writejson(fullfile(folder,'report.json'),report);fprintf('MODEL_REFERENCE_TOY_PHASE %s\n',label);
 end
end
function configure(mdl)
set_param(mdl,'SolverType','Fixed-step','Solver','FixedStepDiscrete','FixedStep','62.5e-9','SolverMode','SingleTasking','EnableMultiTasking','off',...
 'StopTime','.02','SaveTime','off','SaveOutput','off','SignalLogging','off','ReturnWorkspaceOutputs','on');
end
function log_block(mdl,source,name,variable,period)
add_block('simulink/Sinks/To Workspace',[mdl '/' name],'VariableName',variable,'SaveFormat','Timeseries','SampleTime',period,'MaxDataPoints','inf');add_line(mdl,[source '/1'],[name '/1'],'autorouting','on');
end
function close_private(parent,child)
if bdIsLoaded(parent),close_system(parent,0);end
if bdIsLoaded(child),close_system(child,0);end
end
