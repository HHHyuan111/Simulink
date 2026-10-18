function report=probe_sensorless_r2_reduced_graph(id,folder)
% Reduced control-rate graph, source-bound to accepted wrapper scripts.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);
for d={'','robust/integration','robust/phase_guard'},addpath(fullfile(base,d{1}));end
addpath(fullfile(modern,'teaching'));assert(ismember(id,{'baseline','missing_five','reset_one'}));assert(~isfolder(folder));mkdir(folder);
contract=fullfile(base,'contracts/nonideal_r2_reduced_graph_diagnostic.json');copyfile(contract,fullfile(folder,'contract.json'));
pure=fullfile(base,'runs/N3R2_core_isolation_once');prior=jsondecode(fileread(fullfile(pure,'report.json')));assert(prior.baseline_exact);
if ~strcmp(id,'baseline')
 b=jsondecode(fileread(fullfile(base,'runs/N3R2_reduced_core_baseline_time_field_fixed/report.json')));assert(b.all_passed&&strcmp(b.probe_sha256,teach_hash([mfilename('fullpath') '.m'])));
end
parent=jsondecode(fileread(fullfile(base,'contracts/nonideal_r2_core_replay_diagnostic.json')));
reference=jsondecode(fileread(fullfile(base,parent.reference_folder,'record.json')));mdl=['sless_core_' id];assert(~bdIsLoaded(mdl));
report=struct('kind','reduced_control_rate_core_graph','case_id',id,'all_passed',false,'phase','load_inputs',...
 'matlab_version',version,'process_id',feature('getpid'),'plant_reexecuted',false,'native_supervision_tested',false,...
 'whole_model_fault_acceptance',false,'contract_sha256',teach_hash(contract),'pure_report_sha256',teach_hash(fullfile(pure,'report.json')));
copyfile([mfilename('fullpath') '.m'],fullfile(folder,'probe_source.m.txt'));report.probe_sha256=teach_hash([mfilename('fullpath') '.m']);
generation=fullfile(base,'.build','cr',char(java.util.UUID.randomUUID));Simulink.fileGenControl('set','CacheFolder',fullfile(generation,'c'),'CodeGenFolder',fullfile(generation,'g'),'createDir',true);
cleanup=onCleanup(@()close_private(mdl));
try
 if strcmp(id,'baseline'),a=load(fullfile(pure,'baseline.mat'),'input','baseline','t');input=a.input;expected=a.baseline;
 else,a=load(fullfile(pure,[id '_core.mat']),'mutated','result','t');input=a.mutated;expected=a.result;end
 n=numel(a.t);probeTime=(0:n-1)'*50e-6;report.samples=n;report.physical_reference_start_s=a.t(1);report.clock_mapping='physical reference =28.875us + ordinal*50us';
 stage('create_reduced_model');new_system(mdl);set_param(mdl,'SolverType','Fixed-step','Solver','FixedStepDiscrete','FixedStep','50e-6',...
  'StartTime','0','StopTime',num2str(probeTime(end),17),'ReturnWorkspaceOutputs','on','SaveTime','off','SaveOutput','off','SignalLogging','off');
 ws=get_param(mdl,'ModelWorkspace');assignin(ws,'cfg',reshape(reference.observer_config,1,[]));assignin(ws,'front',reshape(reference.config_vector,1,[]));
 values={input.input_i,input.input_v,logical(input.sample_valid),logical(input.reset)};tags={'current','voltage','sample_valid','reset'};
 for k=1:4
  variable=['recorded_' tags{k}];stream=struct('time',[],'signals',struct('values',values{k},'dimensions',size(values{k},2)));assignin(ws,variable,stream);block=['Recorded_' tags{k}];
  add_block('simulink/Sources/From Workspace',[mdl '/' block],'VariableName',variable,'SampleTime','50e-6','Interpolate','off','OutputAfterFinalValue','Holding final value','Position',[20 50*k 140 25+50*k]);
  if k<=2
   reshapeName=['Column_' tags{k}];add_block('simulink/Math Operations/Reshape',[mdl '/' reshapeName],'OutputDimensionality','Column vector (2-D)','Position',[170 50*k 210 25+50*k]);
   add_line(mdl,[block '/1'],[reshapeName '/1'],'autorouting','on');route(reshapeName,1,tags{k});
  else,route(block,1,tags{k});end
 end
 for item={'Cfg','cfg','cfg';'Frontend','front','front';'Direction','1','direction';'Enabled','1','enabled'}'
  add_block('simulink/Sources/Constant',[mdl '/' item{1}],'Value',item{2},'VectorParams1D','off');route(item{1},1,item{3});
 end
 chart('SMO','blocks/sless_smo_block.m',...
  {'current','[2 1]';'voltage','[2 1]';'valid','1';'reset','1';'cfg','[1 18]';'estimate','[2 1]';'residual','[2 1]';'injection','[2 1]'},...
  {'valid','reset'},{'current','voltage','sample_valid','reset','cfg'},{'i_hat','i_residual','injection'});
 chart('EMF','robust/integration/blocks/sless_v2_emf_block.m',...
  {'injection','[2 1]';'omega_previous','1';'direction','1';'valid','1';'reset','1';'cfg','[1 18]';'front_cfg','[1 35]';...
   'emf','[2 1]';'vector','[2 1]';'raw_angle','1';'phase','1';'magnitude','1';'front_phase','1'},...
  {'valid','reset'},{'injection','omega_previous','direction','sample_valid','reset','cfg','front'},...
  {'emf','vector','theta_raw','phase_correction','emf_magnitude','front_phase'});
 chart('PLL','blocks/sless_pll_block.m',...
  {'vector','[2 1]';'magnitude','1';'direction','1';'valid','1';'reset','1';'enabled','1';'cfg','[1 18]';...
   'theta','1';'omega','1';'error','1';'integral','1';'saturated','1';'speed','1'},...
  {'valid','reset','saturated'},{'vector','emf_magnitude','direction','sample_valid','reset','enabled','cfg'},...
  {'theta','omega_e','pll_error','pll_integral','pll_saturated','speed'});
 add_block('simulink/Discrete/Unit Delay',[mdl '/Omega_history'],'InitialCondition','0','SampleTime','50e-6');connect('omega_e','Omega_history',1);route('Omega_history',1,'omega_previous');
 chart('Quality','blocks/sless_validity_block.m',...
  {'residual','[2 1]';'error','1';'magnitude','1';'saturated','1';'sample_valid','1';'direction','1';'reset','1';'cfg','[1 18]';...
   'valid','1';'state','1';'history','[3 1]'},...
  {'saturated','sample_valid','reset','valid'},{'i_residual','pll_error','emf_magnitude','pll_saturated','sample_valid','direction','reset','cfg'},...
  {'valid','state','history'});
 chart('Phase_guard','robust/phase_guard/blocks/sless_r2_phase_guard_block.m',...
  {'theta','1';'vector','[2 1]';'quality','1';'sample_valid','1';'reset','1';'cfg','[1 18]';'packet_valid','1';'diagnostic','[8 1]'},...
  {'quality','sample_valid','reset','packet_valid'},{'theta','vector','valid','sample_valid','reset','cfg'},{'packet_valid','phase_guard'});
 fields=fieldnames(expected);
 for k=1:numel(fields)
  name=['Log_' fields{k}];add_block('simulink/Sinks/To Workspace',[mdl '/' name],'VariableName',['probe_' fields{k}],...
   'SaveFormat','Timeseries','SampleTime','50e-6','MaxDataPoints','inf');connect(fields{k},name,1);
 end
 % Distribute blocks only for this diagnostic artifact; all tags remain scoped.
 blocks=find_system(mdl,'SearchDepth',1,'Type','Block');blocks=blocks(~strcmp(blocks,mdl));
 for k=1:numel(blocks),x=30+270*mod(k-1,5);y=30+65*floor((k-1)/5);set_param(blocks{k},'Position',[x y x+190 y+35]);end
 report.scoped_goto_count=numel(find_system(mdl,'BlockType','Goto'));report.solver=get_param(mdl,'Solver');report.fixed_step_s=str2double(get_param(mdl,'FixedStep'));
 save_system(mdl,fullfile(folder,[mdl '.slx']));report.reduced_model_sha256=teach_hash(fullfile(folder,[mdl '.slx']));assert(bdIsLoaded(mdl));
 stage('compile_and_run_reduced_graph');started=tic;out=sim(mdl);report.elapsed_s=toc(started);assert(isempty(out.ErrorMessage));
 stage('compare_complete_outputs');report.comparisons=struct('field',{},'exact',{},'max_abs',{},'first_differing_sample',{});actual=struct;
 for k=1:numel(fields)
  name=fields{k};series=out.get(['probe_' name]);assert(numel(series.Time)==n&&isequal(round(series.Time/50e-6),(0:n-1)'));
  a=teach_values(series);b=expected.(name);assert(isequal(size(a),size(b)));actual.(name)=a;first=find(any(a~=b,2),1);if isempty(first),first=0;end
  report.comparisons(end+1)=struct('field',name,'exact',isequaln(a,b),'max_abs',max(abs(a-b),[],'all'),'first_differing_sample',first);
 end
 report.numeric_elements=sum(structfun(@numel,expected));report.all_passed=all([report.comparisons.exact]);report.phase='completed';report.R2_case_status_changed=false;
 save(fullfile(folder,'comparison.mat'),'actual','expected','probeTime','-v7.3');
 for k=1:numel(report.sources),assert(strcmp(teach_hash(fullfile(base,report.sources(k).path)),report.sources(k).sha256));end
 teach_writejson(fullfile(folder,'report.json'),report);fprintf('REDUCED_CORE_COMPLETE %s exact=%d\n',id,report.all_passed);
catch err
 report.phase_at_error=report.phase;report.phase='diagnostic_error';report.error=getReport(err,'extended','hyperlinks','off');teach_writejson(fullfile(folder,'report.json'),report);rethrow(err);
end
 function stage(name)
  report.phase=name;teach_writejson(fullfile(folder,'report.json'),report);fprintf('REDUCED_CORE_PHASE %s\n',name);
 end
 function chart(name,relative,sizes,boolean,inputs,outputs)
  stage(['before_install_' name]);source=fullfile(base,relative);index=find(strcmp({reference.source_files.path},relative));assert(isscalar(index)&&strcmp(teach_hash(source),reference.source_files(index).sha256));
  if ~isfield(report,'sources'),report.sources=struct('path',{},'sha256',{});end
  target=fullfile(folder,'source',relative);if ~isfolder(fileparts(target)),mkdir(fileparts(target));end,copyfile(source,target);
  report.sources(end+1)=struct('path',relative,'sha256',teach_hash(source));
  add_block('simulink/User-Defined Functions/MATLAB Function',[mdl '/' name]);rt=sfroot;c=rt.find('-isa','Stateflow.EMChart','Path',[mdl '/' name]);c.Script=fileread(source);
  c.ChartUpdate='DISCRETE';c.SampleTime='50e-6';c.VectorOutputs1D=false;
  for j=1:size(sizes,1)
   d=c.find('-isa','Stateflow.Data','Name',sizes{j,1});assert(isscalar(d));d.Props.Array.Size=sizes{j,2};d.DataType='double';if ismember(sizes{j,1},boolean),d.DataType='boolean';end
  end
  for j=1:numel(inputs),connect(inputs{j},name,j);end
  for j=1:numel(outputs),route(name,j,outputs{j});end
  stage(['after_install_' name]);
 end
 function connect(tag,dest,port)
  source=['Read_' dest '_' num2str(port)];add_block('simulink/Signal Routing/From',[mdl '/' source],'GotoTag',['Probe_' tag]);add_line(mdl,[source '/1'],[dest '/' num2str(port)],'autorouting','on');
 end
 function route(source,port,tag)
  dest=['Publish_' tag];add_block('simulink/Signal Routing/Goto',[mdl '/' dest],'GotoTag',['Probe_' tag],'TagVisibility','scoped');
  add_block('simulink/Signal Routing/Goto Tag Visibility',[mdl '/Visible_' tag],'GotoTag',['Probe_' tag]);add_line(mdl,[source '/' num2str(port)],[dest '/1'],'autorouting','on');
 end
end
function close_private(mdl)
if bdIsLoaded(mdl),close_system(mdl,0);end
end
