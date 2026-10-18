function report=probe_sensorless_r2_rapid_toy(folder)
% Standalone execution feasibility; never opens or simulates the motor model.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);
addpath(fullfile(modern,'teaching'));assert(~isfolder(folder));mkdir(folder);
mdl='sl_r2_rapid_toy';assert(~bdIsLoaded(mdl));cleanup=onCleanup(@()close_private(mdl));
report=struct('kind','rapid_execution_feasibility','phase','compiler_inventory','all_passed',false,...
 'process_id',matlabProcessID,'matlab_version',version,'normal_starts',0,'rapid_starts',0,...
 'native_retries',0,'plant_reexecuted',false,'R2_passed',false,'host_settings_changed',false);
source=[mfilename('fullpath') '.m'];copyfile(source,fullfile(folder,'probe_source.m.txt'));report.probe_sha256=teach_hash(source);
contract=fullfile(base,'contracts/nonideal_r2_rapid_feasibility.json');copyfile(contract,fullfile(folder,'contract.json'));report.contract_sha256=teach_hash(contract);
try
 report.compilers=struct('selected_C',{compiler_rows('C','Selected')},'installed_C',{compiler_rows('C','Installed')},...
  'selected_CXX',{compiler_rows('C++','Selected')},'installed_CXX',{compiler_rows('C++','Installed')});
 stage('compiler_inventory');
 assert(~isempty(report.compilers.selected_C),'R2:NoSelectedCompiler','No selected C compiler; no settings or installations changed.');
 generation=fullfile(base,'.build','rapid_toy',char(java.util.UUID.randomUUID));
 Simulink.fileGenControl('set','CacheFolder',fullfile(generation,'c'),'CodeGenFolder',fullfile(generation,'g'),'createDir',true);
 report.generation_folder=generation;stage('create_fixture');new_system(mdl);
 set_param(mdl,'SolverType','Fixed-step','Solver','FixedStepDiscrete','FixedStep','62.5e-9','SolverMode','SingleTasking','EnableMultiTasking','off',...
  'StopTime','.02','SaveTime','off','SaveOutput','off','SignalLogging','off','ReturnWorkspaceOutputs','on');
 ws=get_param(mdl,'ModelWorkspace');assignin(ws,'offset',1.234);assignin(ws,'input_value',9.876);
 add_block('simulink/Sources/Constant',[mdl '/Input'],'Value','input_value');
 add_block('simulink/Math Operations/Bias',[mdl '/Offset'],'Bias','offset');add_line(mdl,'Input/1','Offset/1');
 add_block('simulink/Sources/Digital Clock',[mdl '/Native_clock'],'SampleTime','62.5e-9');
 add_block('simulink/Signal Routing/Mux',[mdl '/Native_pair'],'Inputs','2');add_line(mdl,'Native_clock/1','Native_pair/1');add_line(mdl,'Offset/1','Native_pair/2');
 log_block(mdl,'Native_pair','Native_log','rapid_native');
 add_block('simulink/Sources/Digital Clock',[mdl '/JEOS_clock'],'SampleTime','[50e-6 28.875e-6]');log_block(mdl,'JEOS_clock','JEOS_log','rapid_jeos');
 add_block('simulink/User-Defined Functions/MATLAB Function',[mdl '/Completion_hit']);rt=sfroot;ch=rt.find('-isa','Stateflow.EMChart','Path',[mdl '/Completion_hit']);
 ch.Script=sprintf('function hit=f(t)\n%%#codegen\nk=round(t/62.5e-9);hit=k>=510&&mod(k-510,800)==0;\nend\n');
 ch.ChartUpdate='DISCRETE';ch.SampleTime='62.5e-9';ch.VectorOutputs1D=false;
 data=ch.find('-isa','Stateflow.Data','Name','t');data.DataType='double';data.Props.Array.Size='1';
 data=ch.find('-isa','Stateflow.Data','Name','hit');data.DataType='boolean';data.Props.Array.Size='1';
 add_line(mdl,'Native_clock/1','Completion_hit/1');e=[mdl '/Completion_log'];add_block('built-in/SubSystem',e);
 add_block('built-in/Inport',[e '/Data'],'PortDimensions','1');add_block('built-in/EnablePort',[e '/Enable']);
 add_block('simulink/Sinks/To Workspace',[e '/Save'],'VariableName','rapid_completion','SaveFormat','Timeseries','SampleTime','-1','MaxDataPoints','inf');
 add_line(e,'Data/1','Save/1');add_line(mdl,'Native_clock/1','Completion_log/1');add_line(mdl,'Completion_hit/1','Completion_log/Enable');
 save_system(mdl,fullfile(folder,[mdl '.slx']));report.fixture_sha256=teach_hash(fullfile(folder,[mdl '.slx']));
 stage('normal_once');report.normal_starts=1;stage('normal_once');normal=sim(mdl,'SimulationMode','normal');
 report.normal_checks=oracle(normal);assert(all(structfun(@(x)x,report.normal_checks)));
 stage('build_standalone_target');rtp=Simulink.BlockDiagram.buildRapidAcceleratorTarget(mdl);save(fullfile(folder,'rtp.mat'),'rtp');
 files=dir(fullfile(generation,'**','*.exe'));assert(~isempty(files),'No generated standalone executable found.');
 report.generated_executables=repmat(struct('path','','sha256',''),numel(files),1);
 for k=1:numel(files),p=fullfile(files(k).folder,files(k).name);report.generated_executables(k)=struct('path',p,'sha256',teach_hash(p));end
 report.rapid_starts=1;stage('rapid_once');rapid=sim(mdl,'SimulationMode','rapid-accelerator');
 report.rapid_checks=oracle(rapid);names={'rapid_native','rapid_jeos','rapid_completion'};comparison=struct;
 for k=1:numel(names)
  a=normal.get(names{k});b=rapid.get(names{k});
  comparison.(names{k})=struct('class_equal',strcmp(class(a),class(b)),...
   'Time_equal',isequaln(a.Time,b.Time),'Data_equal',isequaln(a.Data,b.Data),'dimensions_equal',isequal(size(a.Data),size(b.Data)));
 end
 report.comparison=comparison;report.workspace_unchanged=getVariable(ws,'offset')==1.234&&getVariable(ws,'input_value')==9.876;
 report.fixture_file_unchanged=strcmp(teach_hash(fullfile(folder,[mdl '.slx'])),report.fixture_sha256);
 report.all_passed=all(structfun(@(x)x,report.rapid_checks))&&all(structfun(@(x)all(structfun(@(y)y,x)),comparison))&&report.workspace_unchanged&&report.fixture_file_unchanged;
 save(fullfile(folder,'signals.mat'),'normal','rapid','-v7.3');report.raw_sha256=teach_hash(fullfile(folder,'signals.mat'));
 stage('completed');fprintf('RAPID_TOY_COMPLETED passed=%d\n',report.all_passed);
catch err
 report.phase_at_error=report.phase;report.error_identifier=err.identifier;report.error=getReport(err,'extended','hyperlinks','off');
 report.phase='diagnostic_error';teach_writejson(fullfile(folder,'report.json'),report);rethrow(err);
end
 function stage(value)
  report.phase=value;teach_writejson(fullfile(folder,'report.json'),report);fprintf('RAPID_TOY_PHASE %s\n',value);
 end
end
function rows=compiler_rows(language,scope)
configs=mex.getCompilerConfigurations(language,scope);rows=repmat(struct('name','','version','','manufacturer',''),numel(configs),1);
for k=1:numel(configs),rows(k)=struct('name',configs(k).Name,'version',configs(k).Version,'manufacturer',configs(k).Manufacturer);end
end
function checks=oracle(out)
names=sort({'rapid_native';'rapid_jeos';'rapid_completion'});assert(isempty(out.ErrorMessage));actual=out.who;assert(isequal(sort(actual(:)),names));
native=out.get('rapid_native');jeos=out.get('rapid_jeos');completion=out.get('rapid_completion');n=teach_values(native);j=teach_values(jeos);p=teach_values(completion);h=62.5e-9;
checks=struct('timeseries',isa(native,'timeseries')&&isa(jeos,'timeseries')&&isa(completion,'timeseries'),...
 'finite',all(isfinite([native.Time(:);n(:);jeos.Time(:);j(:);completion.Time(:);p(:)])),...
 'native_rows',isequal(size(n),[320001 2]),'native_ticks',isequal(round(native.Time/h),(0:320000)'),...
 'native_data_ticks',isequal(round(n(:,1)/h),(0:320000)'),...
 'JEOS_ticks',numel(jeos.Time)==400&&isequal(round(jeos.Time/h),(462:800:320000)')&&isequal(round(j/h),(462:800:320000)'),...
 'completion_ticks',numel(completion.Time)==400&&isequal(round(completion.Time/h),(510:800:320000)')&&isequal(round(p/h),(510:800:320000)'),...
 'workspace_value',all(n(:,2)==9.876+1.234));
end
function log_block(mdl,source,name,variable)
add_block('simulink/Sinks/To Workspace',[mdl '/' name],'VariableName',variable,'SaveFormat','Timeseries','SampleTime','-1','MaxDataPoints','inf');add_line(mdl,[source '/1'],[name '/1']);
end
function close_private(mdl)
if bdIsLoaded(mdl),close_system(mdl,0);end
end
