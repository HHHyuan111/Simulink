function report=probe_sensorless_r2_freewheel_inheritance(folder)
% Test continuous inheritance without opening or simulating the motor model.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);
addpath(fullfile(modern,'teaching'));assert(~isfolder(folder));mkdir(folder);
names={'r2_fw_continuous','r2_fw_inherited'};cleanup=onCleanup(@()close_private(names));
report=struct('kind','freewheel_continuous_inheritance','phase','source','all_passed',false,...
 'process_id',matlabProcessID,'matlab_version',version,'normal_starts',0,'rapid_starts',0,...
 'main_model_loaded',false,'R2_passed',false,'native_retries',0);
source=[mfilename('fullpath') '.m'];copyfile(source,fullfile(folder,'probe_source.m.txt'));report.probe_sha256=teach_hash(source);
contract=fullfile(base,'contracts/nonideal_r2_freewheel_inheritance_probe.json');copyfile(contract,fullfile(folder,'contract.json'));report.contract_sha256=teach_hash(contract);
try
 kernel=fullfile(modern,'deadtime','bridge_freewheel.m');code=fileread(kernel);report.kernel_sha256=teach_hash(kernel);
 assert(~contains(code,'persistent')&&~contains(code,'global'));
 frozen=jsondecode(fileread(fullfile(base,'milestones/N3R2/final_candidate.json')));
 report.original_model_sha256=teach_hash(fullfile(modern,'PMSM_FOC_R2026a.slx'));
 inventory=jsondecode(fileread(fullfile(base,'baseline/n0_inventory.json')));assert(strcmp(report.original_model_sha256,inventory.model_sha256_after));
 extracted=fullfile(folder,'source_model_xml');unzip(fullfile(modern,'PMSM_FOC_R2026a.slx'),extracted);
 doc=xmlread(fullfile(extracted,'simulink','stateflow','chart_65.xml'));nodes=doc.getElementsByTagName('P');embedded='';
 for k=0:nodes.getLength-1,n=nodes.item(k);if strcmp(char(n.getAttribute('Name')),'script'),embedded=char(n.getTextContent);end,end
 assert(strcmp(strrep(embedded,sprintf('\r\n'),sprintf('\n')),strrep(code,sprintf('\r\n'),sprintf('\n'))));
 report.embedded_kernel_exact=true;copyfile(kernel,fullfile(folder,'bridge_freewheel_source.m.txt'));
 generation=fullfile(base,'.build','freewheel_inheritance',char(java.util.UUID.randomUUID));
 Simulink.fileGenControl('set','CacheFolder',fullfile(generation,'c'),'CodeGenFolder',fullfile(generation,'g'),'createDir',true);
 report.generation_folder=generation;
 for k=1:2
  method='CONTINUOUS';if k==2,method='INHERITED';end
  fixture(names{k},method,code,folder);
 end
 % Compile-time rate inspection only; no extra simulation starts.
 rates=cell(2,3);
 for k=1:2
  mdl=names{k};stage(['compile_rates_' num2str(k)]);feval(mdl,[],[],[],'compile');term=onCleanup(@()feval(mdl,[],[],[],'term'));
  for j=1:3,rates{k,j}=get_param([mdl '/Bridge' num2str(j)],'CompiledSampleTime');assert(isequal(rates{k,j},[0 0]));end
  clear term;
 end
 report.compiled_sample_times=rates;
 report.normal_starts=1;stage('continuous_normal_once');continuous=sim(names{1},'SimulationMode','normal');
 save(fullfile(folder,'continuous_raw.mat'),'continuous','-v7.3');assert(isempty(continuous.ErrorMessage));
 report.normal_starts=2;stage('inherited_normal_once');inherited=sim(names{2},'SimulationMode','normal');
 save(fullfile(folder,'inherited_raw.mat'),'inherited','-v7.3');assert(isempty(inherited.ErrorMessage));
 report.normal_comparison=compare(continuous,inherited);assert(report.normal_comparison.all_passed);
 stage('build_inherited_rapid_once');rtp=Simulink.BlockDiagram.buildRapidAcceleratorTarget(names{2});save(fullfile(folder,'rtp.mat'),'rtp');
 report.rapid_starts=1;stage('inherited_rapid_once');rapid=sim(names{2},'SimulationMode','rapid-accelerator');
 save(fullfile(folder,'rapid_raw.mat'),'rapid','-v7.3');assert(isempty(rapid.ErrorMessage));
 report.rapid_comparison=compare(inherited,rapid);assert(report.rapid_comparison.all_passed);
 report.files_unchanged=strcmp(report.original_model_sha256,teach_hash(fullfile(modern,'PMSM_FOC_R2026a.slx')))&&strcmp(report.kernel_sha256,teach_hash(kernel));
 report.raw_files=struct;
 for file={'continuous_raw.mat','inherited_raw.mat','rapid_raw.mat'},report.raw_files.(strrep(file{1},'.mat',''))=teach_hash(fullfile(folder,file{1}));end
 report.all_passed=report.files_unchanged;stage('completed');
catch err
 report.phase_at_error=report.phase;report.phase='failed';report.error_identifier=err.identifier;
 teach_writejson(fullfile(folder,'report.json'),report);rethrow(err);
end
 function stage(label),report.phase=label;teach_writejson(fullfile(folder,'report.json'),report);fprintf('FREEWHEEL_INHERITANCE %s\n',label);end
end

function fixture(mdl,method,kernel,folder)
assert(~bdIsLoaded(mdl));new_system(mdl);
set_param(mdl,'SolverType','Fixed-step','Solver','ode4','FixedStep','62.5e-9','SolverMode','SingleTasking','EnableMultiTasking','off',...
 'StopTime','.00135','SaveTime','off','SaveOutput','off','SignalLogging','off','ReturnWorkspaceOutputs','on');
add_block('simulink/Sources/Clock',[mdl '/Time']);
program=sprintf(['function [gates,x1,x2,x3,b1,b2,b3]=stimulus(t)\n%%#codegen\n' ...
 'index=min(floor((t+1e-15)/50e-6),26);gates=zeros(1,6);\n' ...
 'for k=1:3,digit=mod(floor(index/3^(k-1)),3);gates(2*k-1)=double(digit==1);gates(2*k)=double(digit==2);end\n' ...
 'w=2*pi*15000;theta=1000*t;\n' ...
 'x1=[2*sin(w*t) 2*cos(w*t) 100*sin(w*t/3) theta];\n' ...
 'x2=[.009*sin(w*t) .009*cos(w*t) 1000*sin(w*t/3) theta];\n' ...
 'x3=[-2*sin(w*t) 2*cos(w*t) -100*sin(w*t/3) theta];\n' ...
 'b1=24+3*sin(w*t/7);b2=3+2*sin(w*t/7);b3=3*sin(w*t/7);\nend\n']);
chart(mdl,'Stimulus',program,'INHERITED',{'gates','[1 6]';'x1','[1 4]';'x2','[1 4]';'x3','[1 4]';'b1','1';'b2','1';'b3','1'});
add_line(mdl,'Time/1','Stimulus/1');log(mdl,'Stimulus/1','gates');
for j=1:3
 n=num2str(j);b=['Bridge' n];chart(mdl,b,kernel,method,{'phase','[1 3]';'diagnostic','[1 9]'});
 add_line(mdl,'Stimulus/1',[b '/1']);add_line(mdl,['Stimulus/' num2str(j+1)],[b '/2']);add_line(mdl,['Stimulus/' num2str(j+4)],[b '/3']);
 drop=1;if j==3,drop=0;end
 add_block('simulink/Sources/Constant',[mdl '/Config' n],'Value',sprintf('[2 .015 .01 %d .01 .7]',drop));add_line(mdl,['Config' n '/1'],[b '/4']);
 add_block('simulink/Continuous/Integrator',[mdl '/Integral' n]);add_line(mdl,[b '/1'],['Integral' n '/1']);
 log(mdl,[b '/1'],['phase' n]);log(mdl,[b '/2'],['diagnostic' n]);log(mdl,['Integral' n '/1'],['integral' n]);
 log(mdl,['Stimulus/' num2str(j+1)],['state' n]);
end
save_system(mdl,fullfile(folder,[mdl '.slx']));
end

function chart(mdl,name,code,method,outputs)
path=[mdl '/' name];add_block('simulink/User-Defined Functions/MATLAB Function',path);r=sfroot;c=r.find('-isa','Stateflow.EMChart','Path',path);
c.Script=code;c.ChartUpdate=method;c.VectorOutputs1D=false;
for k=1:size(outputs,1),v=c.find('-isa','Stateflow.Data','Name',outputs{k,1});v.Props.Array.Size=outputs{k,2};v.DataType='double';end
end
function log(mdl,source,name)
add_block('simulink/Sinks/To Workspace',[mdl '/Log_' name],'VariableName',['fw_' name],'SaveFormat','Timeseries','SampleTime','-1','MaxDataPoints','inf');add_line(mdl,source,['Log_' name '/1']);
end
function result=compare(a,b)
names=a.who;assert(isequal(sort(names),sort(b.who))&&numel(names)==13);rows=struct;
for k=1:numel(names)
 name=names{k};x=a.get(name);y=b.get(name);assert(isa(x,'timeseries')&&isa(y,'timeseries'));
 rows.(name)=struct('Time_equal',isequal(x.Time,y.Time),'Data_equal',isequal(x.Data,y.Data),'class_equal',strcmp(class(x.Data),class(y.Data)),...
  'dimensions_equal',isequal(size(x.Data),size(y.Data)),'finite',all(isfinite([x.Time(:);x.Data(:);y.Time(:);y.Data(:)])),...
  'native_rows',numel(x.Time)==21601&&numel(y.Time)==21601);
end
result=struct('logs',numel(names),'details',rows,'all_passed',all(structfun(@(row)all(structfun(@(v)v,row)),rows)));
end
function close_private(names)
for k=1:numel(names),if bdIsLoaded(names{k}),close_system(names{k},0);end,end
end
