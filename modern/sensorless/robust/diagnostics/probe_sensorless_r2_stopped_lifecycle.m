function report=probe_sensorless_r2_stopped_lifecycle(folder)
% Reproduce stopped lifecycle failures with a fixed bound and durable edges.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);mdl='PMSM_FOC_R2026a';
for part={'','sensorless','sensorless/robust','sensorless/robust/integration','sensorless/robust/performance','sensorless/robust/execution_v3',...
 'sensorless/robust/phase_guard','sensorless/robust/faults','sensorless/robust/scenarios','sensorless/robust/literal_plant',...
 'sensorless/robust/execution_v8','sensorless/robust/constructor','sensorless/robust/model_reference','sensorless/robust/generated_backend','teaching','control','timing','deadtime','framework','layout/appearance'}
 addpath(fullfile(modern,part{1}));
end
assert(~isfolder(folder)&&~bdIsLoaded(mdl));mkdir(folder);cleanup=onCleanup(@()close_private(mdl));
report=struct('kind','bounded_stopped_lifecycle','phase','prepare','all_passed',false,...
 'process_id',matlabProcessID,'matlab_version',version,'simulation_starts',0,'compile_requested',false,...
 'observer_constructed',false,'model_saved',false,'native_retries',0,'cycle',0,'completed_cycles',0);
source=fullfile(modern,[mdl '.slx']);target=fullfile(folder,[mdl '.slx']);copyfile(source,target);
report.model_sha256=teach_hash(source);assert(strcmp(teach_hash(target),report.model_sha256));
copyfile([mfilename('fullpath') '.m'],fullfile(folder,'probe_source.m.txt'));report.probe_sha256=teach_hash([mfilename('fullpath') '.m']);
contract=fullfile(base,'contracts/nonideal_r2_stopped_lifecycle_stress.json');copyfile(contract,fullfile(folder,'contract.json'));report.contract_sha256=teach_hash(contract);
timer=tic;baselineGraph='';baselineFixed='';baselineInit='';
try
 for cycle=1:20
  if toc(timer)>=300,report.time_bound_reached=true;break;end
  report.cycle=cycle;edge('before_load');load_system(target);edge('after_load');
  report.current_root=bdroot;report.current_system=gcs;assert(strcmp(report.current_root,mdl),'R2:UnexpectedRoot','Unexpected root before restore.');
  edge('before_fixed_restore');pmsm_reference_geometry('restore');edge('after_fixed_restore');
  edge('before_graph_capture');graph=teach_snapshot(mdl);edge('after_graph_capture');
  edge('before_fixed_capture');fixed=pmsm_reference('capture');edge('after_fixed_capture');
  edge('before_callback_read');initialization=get_param(mdl,'InitFcn');edge('after_callback_read');
  graphText=jsonencode(graph);fixedText=jsonencode(fixed);
  if cycle==1
   baselineGraph=graphText;baselineFixed=fixedText;baselineInit=initialization;
   save(fullfile(folder,'first_cycle_snapshot.mat'),'graph','fixed','initialization','-v7.3');
   report.first_cycle_snapshot_sha256=teach_hash(fullfile(folder,'first_cycle_snapshot.mat'));
  end
  assert(strcmp(graphText,baselineGraph)&&strcmp(fixedText,baselineFixed)&&strcmp(initialization,baselineInit),'R2:StoppedStateMismatch','Stopped state differs from first cycle.');
  assert(strcmp(teach_hash(source),report.model_sha256)&&strcmp(teach_hash(target),report.model_sha256));
  edge('before_close');close_system(mdl,0);edge('after_close');assert(~bdIsLoaded(mdl));
  report.completed_cycles=cycle;edge('cycle_completed');
 end
 report.all_passed=report.completed_cycles==20;report.no_reproduction_within_bound=report.all_passed;
 report.source_unchanged=strcmp(teach_hash(source),report.model_sha256);report.copy_unchanged=strcmp(teach_hash(target),report.model_sha256);
 assert(report.source_unchanged&&report.copy_unchanged);edge('completed');
catch err
 report.phase_at_error=report.phase;report.error_identifier=err.identifier;report.phase='failed';report.elapsed_s=toc(timer);
 teach_writejson(fullfile(folder,'report.json'),report);rethrow(err);
end
 function edge(label)
  report.phase=label;report.elapsed_s=toc(timer);teach_writejson(fullfile(folder,'report.json'),report);
  file=fopen(fullfile(folder,'edges.jsonl'),'a','n','UTF-8');assert(file>=0);guard=onCleanup(@()fclose(file));
  fprintf(file,'%s\n',jsonencode(struct('cycle',report.cycle,'phase',label,'elapsed_s',report.elapsed_s)));
  fprintf('STOPPED_LIFECYCLE %d %s\n',report.cycle,label);
 end
end
function close_private(mdl)
if bdIsLoaded(mdl),close_system(mdl,0);end
end
