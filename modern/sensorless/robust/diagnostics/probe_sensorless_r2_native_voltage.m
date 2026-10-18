function report=probe_sensorless_r2_native_voltage(folder)
% Isolate unchanged native voltage predictor; no plant or R2 acceptance claim.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);
for part={'robust','robust/integration','robust/faults','robust/faults/blocks'},addpath(fullfile(base,part{1}));end
addpath(fullfile(modern,'teaching'));assert(~isfolder(folder));mkdir(folder);mdl='sless_native_voltage_probe';assert(~bdIsLoaded(mdl));
report=struct('kind','reduced_native_voltage_predictor','all_passed',false,'phase','source_check',...
 'plant_reexecuted',false,'whole_model_fault_acceptance',false,'R2_case_status_changed',false,'process_id',matlabProcessID,'matlab_version',version);
copyfile([mfilename('fullpath') '.m'],fullfile(folder,'probe_source.m.txt'));report.probe_sha256=teach_hash([mfilename('fullpath') '.m']);
contract=fullfile(base,'contracts/nonideal_r2_native_voltage_diagnostic.json');copyfile(contract,fullfile(folder,'contract.json'));report.contract_sha256=teach_hash(contract);
reference=fullfile(base,'runs/N3R2_constructor_short_20261018_091939_61018e3f-c571-4ab4-9337-60370a02e273/r1_short_logging_check_attempt_1/record.json');
parent=jsondecode(fileread(reference));assert(strcmp(parent.status,'passed'));report.reference_record_sha256=teach_hash(reference);
files={'robust/faults/blocks/sless_r2_voltage_block.m','robust/faults/sensorless_r2_voltage_step.m',...
 'robust/integration/sensorless_v2_config_rt.m','robust/integration/sensorless_v2_voltage_state.m',...
 'robust/integration/sensorless_v2_front_phase.m','robust/sensorless_deadtime_estimate_step.m',...
 'robust/sensorless_bridge_estimate.m','robust/sensorless_robust_state.m'};
report.sources=struct('path',{},'sha256',{});report.diagnostic_sources=struct('path',{},'sha256',{});
for k=1:numel(files)
 relative=files{k};source=fullfile(base,relative);index=find(strcmp({parent.source_files.path},relative));assert(isscalar(index));
 assert(strcmp(teach_hash(source),parent.source_files(index).sha256));[~,sourceName]=fileparts(source);assert(strcmpi(which(sourceName),source));
 target=fullfile(folder,'source',relative);if ~isfolder(fileparts(target)),mkdir(fileparts(target));end,copyfile(source,target);
 report.sources(end+1)=struct('path',relative,'sha256',teach_hash(source));
end
for fixtureFile={'sless_r2_voltage_fixture_block.m','sless_r2_voltage_audit_block.m'}
 relative=['robust/diagnostics/' fixtureFile{1}];copyfile(fullfile(here,fixtureFile{1}),fullfile(folder,fixtureFile{1}));
 report.diagnostic_sources(end+1)=struct('path',relative,'sha256',teach_hash(fullfile(here,fixtureFile{1})));
end
generation=fullfile(base,'.build','nv',char(java.util.UUID.randomUUID));
Simulink.fileGenControl('set','CacheFolder',fullfile(generation,'c'),'CodeGenFolder',fullfile(generation,'g'),'createDir',true);
cleanup=onCleanup(@()close_private(mdl));
try
 stage('create_reduced_graph');new_system(mdl);set_param(mdl,'SolverType','Fixed-step','Solver','FixedStepDiscrete','FixedStep','62.5e-9',...
  'StopTime','.8','SaveTime','off','SaveOutput','off','SignalLogging','off','ReturnWorkspaceOutputs','on');
 ws=get_param(mdl,'ModelWorkspace');assignin(ws,'front',reshape(parent.config_vector,1,[]));
 add_block('simulink/Sources/Digital Clock',[mdl '/Native_clock'],'SampleTime','62.5e-9');route('Native_clock',1,'time');
 add_block('simulink/Sources/Constant',[mdl '/Config'],'Value','front','VectorParams1D','off');route('Config',1,'cfg');
 chart('Fixture',fullfile(here,'sless_r2_voltage_fixture_block.m'),...
  {'t','1';'threshold','[1 3]';'carrier','1';'bus','1';'diag','[1 12]';'current','[3 1]';'vector','[2 1]';'omega','1';'direction','1';'anchor','1'},...
  {'anchor'},{'time'},{'threshold','carrier','bus','diag','current','vector','omega','direction','anchor'});
 chart('Original_voltage',fullfile(base,files{1}),...
  {'t','1';'threshold','[1 3]';'carrier','1';'bus','1';'diag','[1 12]';'current','[3 1]';'vector_previous','[2 1]';...
   'omega_previous','1';'direction','1';'cfg','[1 35]';'anchor_valid','1';'weighted','[2 1]';'interval','[2 1]';'ready','1';'native','[36 1]';'uncertainty','[2 1]'},...
  {'anchor_valid','ready'},{'time','threshold','carrier','bus','diag','current','vector','omega','direction','cfg','anchor'},...
  {'weighted','interval','ready','native','uncertainty'});
 chart('Independent_audit',fullfile(here,'sless_r2_voltage_audit_block.m'),...
  {'t','1';'weighted','[2 1]';'interval','[2 1]';'ready','1';'native','[36 1]';'uncertainty','[2 1]';'anchor','1';'counters','[7 1]';'prefix','[44 1]';'enable','1'},...
  {'ready','anchor','enable'},{'time','weighted','interval','ready','native','uncertainty','anchor'},{'counters','prefix','enable'});
 logger('Counters','counters','counters','50e-6');logger('Control_rate','control','prefix','50e-6');
 e=[mdl '/Prefix_log'];add_block('built-in/SubSystem',e);add_block('built-in/Inport',[e '/Data'],'PortDimensions','[44 1]');add_block('built-in/EnablePort',[e '/Enable']);
 add_block('simulink/Sinks/To Workspace',[e '/Save'],'VariableName','prefix','SaveFormat','Timeseries','SampleTime','-1','MaxDataPoints','inf');add_line(e,'Data/1','Save/1','autorouting','on');connect('prefix','Prefix_log',1);
 add_block('simulink/Signal Routing/From',[mdl '/Prefix_enable'],'GotoTag','enable');add_line(mdl,'Prefix_enable/1','Prefix_log/Enable','autorouting','on');
 blocks=find_system(mdl,'SearchDepth',1,'Type','Block');for k=1:numel(blocks),x=30+280*mod(k-1,5);y=30+65*floor((k-1)/5);set_param(blocks{k},'Position',[x y x+190 y+35]);end
 save_system(mdl,fullfile(folder,[mdl '.slx']));report.model_sha256=teach_hash(fullfile(folder,[mdl '.slx']));
 stage('run_native_voltage');started=tic;out=sim(mdl);report.elapsed_s=toc(started);assert(isempty(out.ErrorMessage));
 counters=out.get('counters');prefix=out.get('prefix');control=out.get('control');c=teach_values(counters);p=teach_values(prefix);
 stage('independent_pure_prefix');state=sensorless_v2_voltage_state;cfg=sensorless_v2_config_rt(reshape(parent.config_vector,1,[]));expected=zeros(2401,43);
 assert(size(p,1)==2401&&isequal(round(prefix.Time/62.5e-9),(0:2400)'));
 for k=1:2401
  t=p(k,1);[threshold,carrier,bus,diag,current,vector,omega,direction,anchor]=sless_r2_voltage_fixture_block(t);
  [state,w,interval,ready,native,u]=sensorless_r2_voltage_step(state,t,threshold,carrier,bus,diag(7),current,vector,omega,direction,cfg,anchor);
  expected(k,:)=[w;interval;double(ready);native;u]';
 end
 actual=p(:,2:end);difference=abs(actual-expected);bound=64*eps(max(1,abs(expected)));within=difference<=bound;
 exactColumns=[5 6 13:18 25:30 36:38];within(:,exactColumns)=actual(:,exactColumns)==expected(:,exactColumns);
 first=find(any(~within,2),1);if isempty(first),first=0;end
 report.prefix_comparison=struct('samples',2401,'numeric_elements',numel(expected),'max_abs_difference',max(difference,[],'all'),...
  'exact_fraction',mean(actual==expected,'all'),'first_failing_sample',first,'all_passed',all(within,'all'));
 checks=struct('native_endpoint',c(end,2)==12800001&&abs(c(end,1)-.8)<1e-12,'native_boundaries',c(end,3)==16000,...
  'rejected_anchors',c(end,4)==6,'counter_count',numel(counters.Time)==16001,'control_count',numel(control.Time)==16001,...
  'final_ready',c(end,6)==1,'pure_prefix',report.prefix_comparison.all_passed);
 report.checks=checks;report.all_passed=all(structfun(@(x)x,checks));report.native_evaluations=c(end,2);report.boundaries=c(end,3);report.rejected_anchors=c(end,4);
 save(fullfile(folder,'signals.mat'),'counters','prefix','control','expected','-v7.3');report.raw_sha256=teach_hash(fullfile(folder,'signals.mat'));
 for entry=report.sources,assert(strcmp(teach_hash(fullfile(base,entry.path)),entry.sha256));end
 for entry=report.diagnostic_sources,assert(strcmp(teach_hash(fullfile(base,entry.path)),entry.sha256));end
 report.phase='completed';teach_writejson(fullfile(folder,'report.json'),report);fprintf('NATIVE_VOLTAGE_COMPLETE passed=%d\n',report.all_passed);
catch err
 report.phase_at_error=report.phase;report.phase='diagnostic_error';report.error=getReport(err,'extended','hyperlinks','off');teach_writejson(fullfile(folder,'report.json'),report);rethrow(err);
end
 function stage(label)
  report.phase=label;teach_writejson(fullfile(folder,'report.json'),report);fprintf('NATIVE_VOLTAGE_PHASE %s\n',label);
 end
 function logger(block,variable,tag,period)
  add_block('simulink/Sinks/To Workspace',[mdl '/' block],'VariableName',variable,'SaveFormat','Timeseries','SampleTime',period,'MaxDataPoints','inf');connect(tag,block,1);
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
