function report=probe_sensorless_r2_observer_graph(folder)
% Clone the actual observer hierarchy; replace external plant inputs only.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);
for part={'','sensorless','sensorless/robust','sensorless/robust/integration','sensorless/robust/performance',...
 'sensorless/robust/execution_v3','sensorless/robust/phase_guard','sensorless/robust/faults','sensorless/robust/scenarios',...
 'sensorless/robust/execution_v8','sensorless/robust/constructor','teaching','control','timing','deadtime','framework','layout/appearance'}
 addpath(fullfile(modern,part{1}));
end
assert(~isfolder(folder));sourceModel='PMSM_FOC_R2026a';mdl='sless_og_probe';assert(~bdIsLoaded(sourceModel)&&~bdIsLoaded(mdl));
snapshot=sensorless_r2_constructor_snapshot(folder);
report=struct('kind','standalone_complete_observer_graph','all_passed',false,'phase','prerequisites',...
 'plant_reexecuted',false,'whole_model_fault_acceptance',false,'R2_case_status_changed',false,...
 'process_id',matlabProcessID,'matlab_version',version,'sources',snapshot.source_files);
report.snapshot_record_sha256=teach_hash(fullfile(folder,'record.json'));
copyfile([mfilename('fullpath') '.m'],fullfile(folder,'probe_source.m.txt'));report.probe_sha256=teach_hash([mfilename('fullpath') '.m']);
contract=fullfile(base,'contracts/nonideal_r2_observer_graph_diagnostic.json');copyfile(contract,fullfile(folder,'contract.json'));report.contract_sha256=teach_hash(contract);
addendum=fullfile(base,'contracts/nonideal_r2_observer_graph_context_addendum.json');copyfile(addendum,fullfile(folder,'context_addendum.json'));report.context_addendum_sha256=teach_hash(addendum);
report.diagnostic_sources=struct('path',{},'sha256',{});
for fixtureFile={'sless_r2_observer_fixture_block.m','sless_r2_voltage_fixture_block.m'}
 copyfile(fullfile(here,fixtureFile{1}),fullfile(folder,fixtureFile{1}));
 report.diagnostic_sources(end+1)=struct('path',['robust/diagnostics/' fixtureFile{1}],'sha256',teach_hash(fullfile(here,fixtureFile{1})));
end
generation=fullfile(base,'.build','og',char(java.util.UUID.randomUUID));Simulink.fileGenControl('set','CacheFolder',fullfile(generation,'c'),'CodeGenFolder',fullfile(generation,'g'),'createDir',true);
representative=fullfile(generation,'c','slprj','_sfprj',mdl,'_self','sfun','src',['c999_' mdl '.c']);assert(strlength(representative)<240);report.representative_codegen_path_length=strlength(representative);
cleanup=onCleanup(@()close_private(sourceModel,mdl));sm=[];
try
 for previous={'N3R2_native_queue_isolation_once','N3R2_native_voltage_isolation_once'}
  evidence=jsondecode(fileread(fullfile(base,'runs',previous{1},'report.json')));assert(evidence.all_passed&&strcmp(evidence.phase,'completed'));
 end
 plan=jsondecode(fileread(fullfile(base,'contracts/nonideal_r2_test_plan.json')));cases=plan.cases;if ~iscell(cases),cases=num2cell(cases);end
 selected=cellfun(@(x)strcmp(x.id,'missing_five'),cases);assert(sum(selected)==1);testcase=cases{selected};
 stage('construct_actual_observer_stopped');load_system(fullfile(modern,[sourceModel '.slx']));pmsm_reference_geometry('restore');
 original=teach_snapshot(sourceModel);fixed=pmsm_reference('capture');originalInit=get_param(sourceModel,'InitFcn');
 backup=sensorless_v2_stimulus(sourceModel,testcase);set_param([sourceModel '/speed_ref'],'Value','3000');
 report.original_initialization=sensorless_r2_initialize_stopped(sourceModel);pmsm_sensorless_v2_geometry_model('install',sourceModel,0);
 report.phase_guard=sensorless_r2_phase_guard_model(sourceModel);report.logging=sensorless_r2_logging(sourceModel);
 set_param([sourceModel '/无感观测/观测/R2累计记录'],'SampleTime','50e-6');report.fault_adapter=sensorless_r2_fault_model(sourceModel,testcase);
 report.observer_initialization=sensorless_r2_initialize_stopped(sourceModel);sourceRoot=[sourceModel '/无感观测'];
 before=workspace_values(get_param(sourceModel,'ModelWorkspace'));assert(numel(before)==86);
 sourceCatalog=catalog(sourceRoot);sourceCharts=charts(sourceRoot);
 blocks=find_system(sourceRoot,'LookUnderMasks','all','BlockType','ToWorkspace');expectedLogs=sort(cellfun(@(b)get_param(b,'VariableName'),blocks,'UniformOutput',false));assert(numel(unique(expectedLogs))==numel(expectedLogs));
 provided=tags(sourceRoot,'Goto');used=tags(sourceRoot,'From');external=sort(setdiff(used,provided));
 declared=sort({'SLessAppliedThreshold';'ObsCarrier';'UDC';'Iabc_meas';'SLessV2ADC';'ObsADCTiming';'ObsPWMTiming';'theta_e';'speed'});
 assert(isequal(external(:),declared(:)));report.external_tags=external;report.observer_log_count=numel(expectedLogs);
 stage('clone_without_plant');new_system(mdl);set_param(mdl,'SolverType','Fixed-step','Solver','FixedStepDiscrete','FixedStep','timing_h',...
  'StopTime','.8','SaveTime','off','SaveOutput','off','SignalLogging','off','ReturnWorkspaceOutputs','on');
 sourceOptions=get_param(sourceModel,'ObjectParameters');report.execution_config=struct('name',{},'value',{});
 for configKey={'SolverType','Solver','FixedStep','SolverMode','EnableMultiTasking'}
  if isfield(sourceOptions,configKey{1})
   value=get_param(sourceModel,configKey{1});set_param(mdl,configKey{1},value);assert(isequaln(get_param(mdl,configKey{1}),value));
   report.execution_config(end+1)=struct('name',configKey{1},'value',value);
  end
 end
 ws=get_param(mdl,'ModelWorkspace');for k=1:numel(before),assignin(ws,before(k).name,before(k).value);end
 root=[mdl '/无感观测'];add_block(sourceRoot,root);
 report.clone_block_catalog_exact=isequaln(sourceCatalog,catalog(root));report.clone_chart_scripts_exact=isequaln(sourceCharts,charts(root));
 report.clone_workspace_exact=isequaln(before,workspace_values(ws));report.clone_block_count=numel(sourceCatalog);report.clone_chart_count=numel(sourceCharts);
 assert(report.clone_block_catalog_exact&&report.clone_chart_scripts_exact&&report.clone_workspace_exact);
 stage('restore_source_before_reduced_execution');set_param(0,'CurrentSystem',sourceModel);assert(strcmp(bdroot,sourceModel));
 pmsm_sensorless_v2_geometry_model('remove',sourceModel);set_param(sourceModel,'InitFcn',originalInit);sensorless_n3_restore(sourceModel,backup);
 afterModel=teach_snapshot(sourceModel);afterFixed=pmsm_reference('capture');report.original_restored=isequaln(original,afterModel)&&isequaln(fixed,afterFixed);assert(report.original_restored);
 sensorless_v2_guard_sources(snapshot);sensorless_r2_verify_constructor;close_system(sourceModel,0);report.original_closed_before_execution=~bdIsLoaded(sourceModel);
 stage('install_nine_synthetic_external_sources');set_param(0,'CurrentSystem',mdl);assert(strcmp(bdroot,mdl));
 add_block('simulink/Sources/Digital Clock',[mdl '/Fixture_clock'],'SampleTime','timing_h');
 add_block('simulink/User-Defined Functions/MATLAB Function',[mdl '/Fixture']);rt=sfroot;ch=rt.find('-isa','Stateflow.EMChart','Path',[mdl '/Fixture']);ch.Script=fileread(fullfile(here,'sless_r2_observer_fixture_block.m'));
 ch.ChartUpdate='DISCRETE';ch.SampleTime='timing_h';ch.VectorOutputs1D=false;
 sizes={'t','1';'threshold','[1 3]';'carrier','1';'bus','1';'measured','[3 1]';'adc','[3 1]';'adc_diag','[1 15]';'pwm_diag','[1 12]';'truth_theta','1';'truth_speed','1'};
 for k=1:size(sizes,1),chartData=ch.find('-isa','Stateflow.Data','Name',sizes{k,1});assert(isscalar(chartData));chartData.Props.Array.Size=sizes{k,2};chartData.DataType='double';end
 add_line(mdl,'Fixture_clock/1','Fixture/1','autorouting','on');
 fixtureTags={'SLessAppliedThreshold','ObsCarrier','UDC','Iabc_meas','SLessV2ADC','ObsADCTiming','ObsPWMTiming','theta_e','speed'};
 for k=1:numel(fixtureTags)
  name=['Fixture_' fixtureTags{k}];add_block('simulink/Signal Routing/Goto',[mdl '/' name],'GotoTag',fixtureTags{k},'TagVisibility','scoped');
  add_block('simulink/Signal Routing/Goto Tag Visibility',[mdl '/Visible_' fixtureTags{k}],'GotoTag',fixtureTags{k});
  if k==1
      add_block('simulink/Math Operations/Reshape',[mdl '/Threshold_original_1D'],'OutputDimensionality','1-D array');
      add_line(mdl,'Fixture/1','Threshold_original_1D/1','autorouting','on');add_line(mdl,'Threshold_original_1D/1',[name '/1'],'autorouting','on');
  else
      add_line(mdl,['Fixture/' num2str(k)],[name '/1'],'autorouting','on');
  end
 end
 save_system(mdl,fullfile(folder,[mdl '.slx']));report.model_sha256=teach_hash(fullfile(folder,[mdl '.slx']));
 stage('initialize_reduced_graph_once');sm=simulation(mdl);sm=setModelParameter(sm,StopTime='.8');initialize(sm);assert(strcmp(sm.Status,'initialized'));
 assert(isequaln(before,workspace_values(ws)));stage('advance_reduced_graph');[out,report.execution]=sensorless_r2_run_initialized(sm,62.5e-9,.8,folder);clear sm;sm=[];assert(isempty(out.ErrorMessage));
 signals=struct;for key=out.who',series=out.get(key{1});if isa(series,'timeseries'),assert(all(isfinite(series.Time),'all')&&all(isfinite(series.Data),'all'));signals.(key{1})=series;end,end
 report.all_observer_logs_preserved=isequal(sort(fieldnames(signals)),expectedLogs(:));assert(report.all_observer_logs_preserved);
 stage('archive_and_audit');save(fullfile(folder,'signals.mat'),'-struct','signals','-v7.3');report.raw_sha256=teach_hash(fullfile(folder,'signals.mat'));
 c=teach_values(signals.obs_sless_r2_native_counters);e=teach_values(signals.obs_sless_r2_native_events);report.event_audit=sensorless_r2_event_audit(e,c,62.5e-9);
 t=signals.obs_sless_v2_theta.Time;q=teach_values(signals.obs_sless_r2_fault_queue);anchor=teach_values(signals.obs_sless_r2_anchor_valid);
 missing=t>=.600028875-1e-12&t<.600278875-1e-12;pub=teach_values(signals.obs_sless_r2_actual_publications);onset=find(round(e(:,1)/62.5e-9)==9600462);
 checks=struct('native_endpoint',c(end,12)==12800001&&abs(c(end,1)-.8)<1e-12,'JEOS_samples',numel(t)==16000,...
  'publication_count',size(pub,1)==15995,'missing_count',sum(missing)==5&&sum(q(:,2))==5,'anchor_rejected',all(anchor(missing)==0),...
  'first_native_veto',isscalar(onset)&&e(onset,3)==0&&bitand(uint16(e(onset,4)),uint16(2048))~=0,...
  'event_counter_audit',report.event_audit.all_passed,'workspace_unchanged',isequaln(before,workspace_values(ws)),...
  'source_restored',report.original_restored,'all_observer_logs',report.all_observer_logs_preserved);
 report.checks=checks;report.all_passed=all(structfun(@(x)x,checks));report.native_evaluations=c(end,12);report.publications=size(pub,1);report.synthetic_false_valid_longest_s=c(end,2);
 report.synthetic_accuracy_is_not_an_acceptance_criterion=true;sensorless_v2_guard_sources(snapshot);sensorless_r2_verify_constructor;
 for entry=report.diagnostic_sources,assert(strcmp(teach_hash(fullfile(base,entry.path)),entry.sha256));end
 save(fullfile(folder,'source_restoration.mat'),'original','afterModel','fixed','afterFixed','before','sourceCatalog','sourceCharts','-v7.3');
 report.phase='completed';teach_writejson(fullfile(folder,'report.json'),report);fprintf('COMPLETE_OBSERVER_GRAPH passed=%d\n',report.all_passed);
catch err
 report.phase_at_error=report.phase;report.phase='diagnostic_error';report.error=getReport(err,'extended','hyperlinks','off');teach_writejson(fullfile(folder,'report.json'),report);
 try
  if ~isempty(sm)&&~strcmp(sm.Status,'inactive'),terminate(sm);end
 catch
 end
 rethrow(err);
end
 function stage(label)
  report.phase=label;teach_writejson(fullfile(folder,'report.json'),report);fprintf('OBSERVER_GRAPH_PHASE %s\n',label);
 end
end
function values=workspace_values(ws)
entries=whos(ws);names=sort({entries.name});values=struct('name',{},'value',{});
for k=1:numel(names),values(k)=struct('name',names{k},'value',getVariable(ws,names{k}));end
end
function values=tags(root,type)
blocks=find_system(root,'LookUnderMasks','all','BlockType',type);values=unique(cellfun(@(b)get_param(b,'GotoTag'),blocks,'UniformOutput',false));
end
function result=catalog(root)
blocks=sort(find_system(root,'LookUnderMasks','all','Type','Block'));result=struct('relative',{},'type',{});
for k=1:numel(blocks),result(k)=struct('relative',strrep(blocks{k},root,''),'type',get_param(blocks{k},'BlockType'));end
end
function result=charts(root)
rt=sfroot;allCharts=rt.find('-isa','Stateflow.EMChart');result=repmat(struct('relative','','script',''),numel(allCharts),1);count=0;
for k=1:numel(allCharts)
 if startsWith(allCharts(k).Path,[root '/']),count=count+1;result(count)=struct('relative',strrep(allCharts(k).Path,root,''),'script',allCharts(k).Script);end
end
result=result(1:count);
if ~isempty(result),[~,index]=sort({result.relative});result=result(index);end
end
function close_private(source,mdl)
if bdIsLoaded(source),close_system(source,0);end
if bdIsLoaded(mdl),close_system(mdl,0);end
end
