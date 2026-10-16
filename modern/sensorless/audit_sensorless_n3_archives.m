function report=audit_sensorless_n3_archives(originalFolder,replayFolder,capsuleSource)
% Audit all frozen cases without promoting an incomplete replay to a pass.
here=fileparts(mfilename('fullpath'));addpath(fullfile(fileparts(here),'teaching'));
a=jsondecode(fileread(fullfile(originalFolder,'campaign.json')));
b=jsondecode(fileread(fullfile(replayFolder,'campaign.json')));
assert(isequaln(a.startup_options,b.startup_options)&&strcmp(a.driver_sha256,b.driver_sha256));
plan=jsondecode(fileread(fullfile(capsuleSource,'contracts','test_plan_v1.json')));
cases=plan.cases;if ~iscell(cases),cases=num2cell(cases);end
ids=cellfun(@(x)x.id,cases(cellfun(@(x)strcmp(x.node,'N3'),cases)),'UniformOutput',false);
assert(numel(ids)==16&&numel(b.entries)==16&&isequal(sort(ids(:)),sort({b.entries.case_id}')));
schema=jsondecode(fileread(fullfile(capsuleSource,'baseline','log_schema.json')));oldNames={schema.name};
rows=struct([]);regressions=struct([]);
for id=ids(:)'
 x=a.entries(strcmp({a.entries.kind},'observer')&strcmp({a.entries.case_id},id{1}));assert(isscalar(x));
 y=b.entries(strcmp({b.entries.kind},'observer')&strcmp({b.entries.case_id},id{1}));assert(isscalar(y));
 ra=check_record(x.completed_folder,capsuleSource);
 r=struct('case_id',id{1},'replay_completed',false,'raw_Time_Data_identical',false,'numeric_elements',0,...
  'metrics_identical',false,'case_required_passed',false,'failures',{{}},'attempts',y.attempts,'passed',false);
 if ~isempty(y.completed_folder)
  rb=check_record(y.completed_folder,capsuleSource);
  assert(isequaln(ra.source_files,rb.source_files)&&isequaln(ra.contracts,rb.contracts)&&strcmp(ra.matlab_version,rb.matlab_version));
  [same,count,failures]=compare_sensorless_n3_raw(fullfile(x.completed_folder,'signals.mat'),fullfile(y.completed_folder,'signals.mat'),{});
  ma=jsondecode(fileread(fullfile(x.completed_folder,'metrics.json')));mb=jsondecode(fileread(fullfile(y.completed_folder,'metrics.json')));
  r.replay_completed=true;r.raw_Time_Data_identical=same;r.numeric_elements=count;r.failures=failures;
  r.metrics_identical=isequaln(ma,mb);r.case_required_passed=ra.all_passed&&rb.all_passed;
  r.passed=same&&r.metrics_identical&&r.case_required_passed;
 else
  assert(strcmp(y.status,'incomplete')&&numel(y.attempts)==2);
  r.failures={'no_complete_replay_after_two_native_failures'};
 end
 if isempty(rows),rows=r;else,rows(end+1)=r;end %#ok<AGROW>
 baselineId=id{1};
 if startsWith(baselineId,'mismatch_')||ismember(baselineId,{'noise_002A','missing_5_samples','observer_reset'}),baselineId='steady_3000';end
 ref=a.entries(strcmp({a.entries.kind},'plant_reference')&strcmp({a.entries.case_id},baselineId));assert(isscalar(ref));
 check_record(ref.completed_folder,capsuleSource);
 [same,count,failures]=compare_sensorless_n3_raw(fullfile(ref.completed_folder,'signals.mat'),fullfile(x.completed_folder,'signals.mat'),oldNames);
 rr=struct('case_id',id{1},'baseline_case_id',baselineId,'old_logs',numel(oldNames),'identical',same,'numeric_elements',count,'failures',{failures});
 if isempty(regressions),regressions=rr;else,regressions(end+1)=rr;end %#ok<AGROW>
 fprintf('N3_AUDIT %s completed=%d replay=%d old52=%d\n',id{1},r.replay_completed,r.passed,rr.identical);
end
completed=[rows.replay_completed];
report=struct('schema',1,'node','N3','status','incomplete_replay_not_accepted',...
 'original_folder',originalFolder,'replay_folder',replayFolder,'executed_source_folder',capsuleSource,...
 'audit_driver_sha256',teach_hash([mfilename('fullpath') '.m']),...
 'comparison_driver_sha256',teach_hash(fullfile(here,'compare_sensorless_n3_raw.m')),...
 'required_replay_cases',16,'completed_replay_cases',sum(completed),'cases',rows,'old_log_regressions',regressions,...
 'completed_replays_identical',all([rows(completed).passed]),'old52_all_identical',all([regressions.identical]),...
 'all_passed',all([rows.passed])&&all([regressions.identical]));
if report.all_passed,report.status='complete_replay_passed';end
teach_writejson(fullfile(replayFolder,'replay_validation.json'),report);
fprintf('N3_AUDIT_ALL_PASSED=%d completed=%d/16 elements=%g\n',report.all_passed,sum(completed),sum([rows.numeric_elements]));
end

function r=check_record(folder,source)
r=jsondecode(fileread(fullfile(folder,'record.json')));assert(strcmp(r.status,'passed')&&r.all_passed);
assert(strcmp(r.raw_sha256,teach_hash(fullfile(folder,'signals.mat'))));
for f=r.source_files(:)',assert(strcmp(f.sha256,teach_hash(fullfile(source,f.path))),'Executed source mismatch: %s',f.path);end
for f=r.contracts(:)',assert(strcmp(f.sha256,teach_hash(fullfile(source,f.path))));end
assert(r.layer_restored&&r.reference_restored);
end

