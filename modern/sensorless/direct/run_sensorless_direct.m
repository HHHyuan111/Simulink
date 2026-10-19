function report=run_sensorless_direct(label)
% One normal simulation of the saved direct local-model adaptation.
base=sensorless_direct_setup;mdl='PMSM_FOC_R2026a';
assert(ismember(label,{'first','repeat'}));folder=fullfile(base,'runs',['SMO_direct_' label]);
assert(~isfolder(folder),'Run already exists.');mkdir(folder);
profile=jsondecode(fileread(fullfile(base,'direct','acceptance.json')));
modelFile=fullfile(base,'models','direct',[mdl '.slx']);build=jsondecode(fileread(fullfile(base,'models','direct','build.json')));
report=struct('phase','load','passed',false,'process_id',matlabProcessID,'simulation_starts',0,'label',label,...
 'model_sha256',teach_hash(modelFile),'matlab_version',version);
assert(build.passed&&strcmp(report.model_sha256,build.model_sha256));
if strcmp(label,'repeat')
 first=jsondecode(fileread(fullfile(base,'runs','SMO_direct_first','report.json')));
 if ~first.passed
  reviewFile=fullfile(base,'runs','SMO_direct_first','review.json');review=jsondecode(fileread(reviewFile));
  assert(review.passed&&strcmp(review.original_first_report_sha256,teach_hash(fullfile(base,'runs','SMO_direct_first','report.json'))));
  assert(strcmp(review.first_raw_sha256,first.raw_sha256)&&strcmp(review.model_sha256,first.model_sha256));
  first.passed=review.passed;first.original_control_unchanged=review.original_control_unchanged;report.first_postprocessing_review_sha256=teach_hash(reviewFile);
 end
 assert(first.passed);
 assert(first.process_id~=report.process_id&&strcmp(first.model_sha256,report.model_sha256));
end
cache=fullfile(base,'.build',['direct_' label]);Simulink.fileGenControl('set','CacheFolder',fullfile(cache,'c'),'CodeGenFolder',fullfile(cache,'g'),'createDir',true);
load_system(modelFile);cleanup=onCleanup(@()close_private(mdl)); %#ok<NASGU>
try
 report.phase='normal_function_comparison';write_report;
 report.normal_function_check=verify_sensorless_direct_nominal(build.frontend_config);
 report.phase='simulate';report.simulation_starts=1;write_report;started=tic;
 out=sim(mdl,'SimulationMode','normal','StopTime',num2str(profile.duration_s,17),'ReturnWorkspaceOutputs','on');
 report.elapsed_s=toc(started);assert(isempty(out.ErrorMessage));
 report.phase='save_raw';write_report;signals=struct;
 for key=out.who'
  value=out.get(key{1});if isa(value,'timeseries'),signals.(key{1})=value;end
 end
 save(fullfile(folder,'signals.mat'),'-struct','signals','-v7.3');report.raw_sha256=teach_hash(fullfile(folder,'signals.mat'));clear out;
 close_system(mdl,0);
 report.phase='analyse';write_report;
 metrics=analyse_sensorless_direct(signals,profile);teach_writejson(fullfile(folder,'metrics.json'),metrics);
 report.metrics_passed=metrics.passed;report.log_count=numel(fieldnames(signals));
 if strcmp(label,'first')
  report.phase='original_control_comparison';write_report;
  original=check_sensorless_direct_original(signals,profile.duration_s);teach_writejson(fullfile(folder,'original52.json'),original);
  report.original_control_unchanged=original.passed;
 else
  report.original_control_unchanged=first.original_control_unchanged;
  report.original_control_comparison='Confirmed through exact repeat of all logs, including original52';
 end
 report.repeat_exact=true;
 if strcmp(label,'repeat')
  previous=load(fullfile(base,'runs','SMO_direct_first','signals.mat'));names=fieldnames(signals);comparisons=struct('name',{},'data_exact',{},'time_accepted',{});
  assert(isequal(sort(names),sort(fieldnames(previous))));
  for k=1:numel(names)
   a=signals.(names{k});b=previous.(names{k});exact=isequaln(a.Time,b.Time);
   encoding=false;
   if ismember(names{k},{'obs_dead_gates','obs_dead_requested'})&&isequal(size(a.Time),size(b.Time))
    encoding=isequal(round(a.Time/62.5e-9),round(b.Time/62.5e-9))&&max(abs(a.Time-b.Time))<=4*eps(max(abs(b.Time)));
   end
   comparisons(k)=struct('name',names{k},'data_exact',isequaln(a.Data,b.Data),'time_accepted',exact||encoding);
  end
  report.repeat_exact=all([comparisons.data_exact]&[comparisons.time_accepted]);teach_writejson(fullfile(folder,'repeat_comparison.json'),comparisons);
 end
 report.model_file_unchanged=strcmp(teach_hash(modelFile),build.model_sha256);
 report.passed=metrics.passed&&report.original_control_unchanged&&report.repeat_exact&&report.model_file_unchanged;report.phase='completed';write_report;
catch err
 report.failed_phase=report.phase;report.phase='failed';report.error_identifier=err.identifier;write_report;rethrow(err);
end
 function write_report,teach_writejson(fullfile(folder,'report.json'),report);fprintf('SMO_DIRECT %s %s\n',label,report.phase);end
end
function close_private(mdl)
if bdIsLoaded(mdl),close_system(mdl,0);end
end
