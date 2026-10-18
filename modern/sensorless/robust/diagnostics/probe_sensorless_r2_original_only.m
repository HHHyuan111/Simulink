function record=probe_sensorless_r2_original_only(folder)
% One original-model differential control; no observer layer installation.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);mdl='PMSM_FOC_R2026a';
for d={'','sensorless','sensorless/robust','sensorless/robust/integration','sensorless/robust/execution_v3','sensorless/robust/execution_v8',...
 'teaching','control','timing','deadtime','framework','layout/appearance'},addpath(fullfile(modern,d{1}));end
assert(~isfolder(folder)&&~bdIsLoaded(mdl));mkdir(folder);
record=struct('kind','original_only_differential_control','phase','source_check','all_passed',false,'observer_installed',false,...
 'R2_case_status_changed',false,'formal_R3',false,'process_id',feature('getpid'),'matlab_version',version);
copyfile([mfilename('fullpath') '.m'],fullfile(folder,'probe_source.m.txt'));record.probe_sha256=teach_hash([mfilename('fullpath') '.m']);
contract=fullfile(base,'contracts/nonideal_r2_original_only_diagnostic.json');copyfile(contract,fullfile(folder,'contract.json'));record.contract_sha256=teach_hash(contract);
generation=fullfile(base,'.build','oc',char(java.util.UUID.randomUUID));Simulink.fileGenControl('set','CacheFolder',fullfile(generation,'c'),'CodeGenFolder',fullfile(generation,'g'),'createDir',true);
sources={'robust/integration/sensorless_v2_stimulus.m','sensorless_n3_stimulus.m','sensorless_n3_restore.m',...
 'robust/execution_v3/sensorless_r2_initialize_stopped.m','robust/execution_v8/sensorless_r2_run_initialized.m'};
record.sources=struct('path',{},'sha256',{});
for k=1:numel(sources)
 source=fullfile(base,sources{k});target=fullfile(folder,'source',sources{k});if ~isfolder(fileparts(target)),mkdir(fileparts(target));end,copyfile(source,target);
 record.sources(end+1)=struct('path',sources{k},'sha256',teach_hash(source));
end
modelFile=fullfile(modern,[mdl '.slx']);record.model_sha256=teach_hash(modelFile);sm=[];cleanup=onCleanup(@()close_private(mdl));
try
 stage('load_original');load_system(modelFile);pmsm_reference('restore');original=teach_snapshot(mdl);fixed=pmsm_reference('capture');originalInit=get_param(mdl,'InitFcn');
 assert(getSimulinkBlockHandle([mdl '/无感观测'])<0);reduction=get_param(mdl,'BlockReduction');assert(strcmp(reduction,'on'));record.block_reduction=reduction;
 stage('configure_original_profile');test=struct('window_on',false,'interference_s',0,'adc_span_A',20);backup=sensorless_v2_stimulus(mdl,test);
 record.initialization=sensorless_r2_initialize_stopped(mdl);configured=teach_snapshot(mdl);record.configuration=teach_settings(mdl);ws=get_param(mdl,'ModelWorkspace');before=workspace_values(ws);
 h=getVariable(ws,'timing_h');assert(h==62.5e-9);record.native_h_s=h;
 stage('initialize_original_once');sm=simulation(mdl);sm=setModelParameter(sm,StopTime='.8');initialize(sm);assert(strcmp(sm.Status,'initialized'));afterCompile=workspace_values(ws);assert(isequaln(before,afterCompile));
 stage('advance_original_without_observer');[out,record.execution]=sensorless_r2_run_initialized(sm,h,.8,folder);assert(isempty(out.ErrorMessage));clear sm;sm=[];
 afterSimulation=workspace_values(ws);assert(isequaln(before,afterSimulation));schema=jsondecode(fileread(fullfile(base,'baseline/log_schema.json')));names={schema.name};assert(numel(names)==52);
 stage('archive_original52');signals=struct;endpoint=false;
 for k=1:numel(names)
  series=out.get(names{k});assert(isa(series,'timeseries')&&all(isfinite(series.Time))&&all(isfinite(series.Data),'all'));signals.(names{k})=series;
  endpoint=endpoint||abs(series.Time(end)-.8)<1e-12;
 end
 assert(endpoint&&record.execution.requested_major_steps==12800001&&record.execution.last_step);record.endpoint_verified=true;
 save(fullfile(folder,'signals.mat'),'-struct','signals','-v7.3');record.raw_sha256=teach_hash(fullfile(folder,'signals.mat'));clear out;
 stage('restore_original');set_param(mdl,'InitFcn',originalInit);sensorless_n3_restore(mdl,backup);afterModel=teach_snapshot(mdl);afterFixed=pmsm_reference('capture');
 record.restoration=isequaln(original,afterModel)&&isequaln(fixed,afterFixed)&&strcmp(get_param(mdl,'InitFcn'),originalInit)&&strcmp(get_param(mdl,'BlockReduction'),reduction);assert(record.restoration);
 record.workspace_unchanged=isequaln(before,afterCompile)&&isequaln(before,afterSimulation);assert(record.workspace_unchanged);
 save(fullfile(folder,'restoration.mat'),'original','configured','afterModel','fixed','afterFixed','before','afterCompile','afterSimulation','-v7.3');
 stage('compare_original52');plan=jsondecode(fileread(fullfile(base,'contracts/nonideal_r2_core_replay_diagnostic.json')));reference=fullfile(base,plan.reference_folder,'signals.mat');assert(strcmp(teach_hash(reference),plan.reference_raw_sha256));
 old=load(reference,names{:});record.comparisons=struct('name',{},'data_exact',{},'class_exact',{},'time_exact',{},'native_ticks_exact',{},'time_encoding_allowed',{},'max_time_delta_s',{});
 for k=1:numel(names)
  name=names{k};a=signals.(name);b=old.(name);ticksSame=isequaln(round(a.Time/h),round(b.Time/h));delta=Inf;
  if isequal(size(a.Time),size(b.Time)),delta=max(abs(a.Time-b.Time));end
  encoding=ismember(name,{'obs_dead_gates','obs_dead_requested'})&&ticksSame&&delta<=4*eps(max(abs(b.Time)));
  record.comparisons(end+1)=struct('name',name,'data_exact',isequaln(a.Data,b.Data),'class_exact',strcmp(class(a.Data),class(b.Data)),...
   'time_exact',isequaln(a.Time,b.Time),'native_ticks_exact',ticksSame,'time_encoding_allowed',encoding,'max_time_delta_s',delta);
 end
 q=record.comparisons;record.all52_data_exact=all([q.data_exact]&[q.class_exact]);record.all52_time_ticks_exact=all([q.native_ticks_exact]);
 record.all52_time_encoding_accepted=all([q.time_exact]|[q.time_encoding_allowed]);record.all_passed=record.all52_data_exact&&record.all52_time_ticks_exact&&record.all52_time_encoding_accepted;
 for k=1:numel(record.sources),assert(strcmp(teach_hash(fullfile(base,record.sources(k).path)),record.sources(k).sha256));end
 assert(strcmp(record.model_sha256,teach_hash(modelFile)));record.phase='completed';teach_writejson(fullfile(folder,'report.json'),record);fprintf('ORIGINAL_ONLY_COMPLETE exact=%d\n',record.all_passed);
catch err
 record.phase_at_error=record.phase;record.phase='diagnostic_error';record.error=getReport(err,'extended','hyperlinks','off');teach_writejson(fullfile(folder,'report.json'),record);
 try,if ~isempty(sm)&&~strcmp(sm.Status,'inactive'),terminate(sm);end,catch,end,rethrow(err);
end
 function stage(name)
  record.phase=name;teach_writejson(fullfile(folder,'report.json'),record);fprintf('ORIGINAL_ONLY_PHASE %s\n',name);
 end
end
function values=workspace_values(ws)
entries=whos(ws);names=sort({entries.name});values=struct('name',{},'value',{});for k=1:numel(names),values(k)=struct('name',names{k},'value',getVariable(ws,names{k}));end
end
function close_private(mdl)
if bdIsLoaded(mdl),close_system(mdl,0);end
end
