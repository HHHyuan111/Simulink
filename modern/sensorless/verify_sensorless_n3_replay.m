function report=verify_sensorless_n3_replay(originalFolder,replayFolder)
% Load one complete timeseries at a time, preserving full native-rate equality.
here=fileparts(mfilename('fullpath'));addpath(fullfile(fileparts(here),'teaching'));
a=jsondecode(fileread(fullfile(originalFolder,'campaign.json')));b=jsondecode(fileread(fullfile(replayFolder,'campaign.json')));
assert(isequaln(a.startup_options,b.startup_options)&&strcmp(a.driver_sha256,b.driver_sha256));
names=jsondecode(fileread(fullfile(here,'baseline','log_schema.json')));oldNames={names.name};
rows=struct([]);regressions=struct([]);
for index=1:numel(a.entries)
 x=a.entries(index);if ~strcmp(x.kind,'observer'),continue;end
 match=find(strcmp({b.entries.kind},'observer')&strcmp({b.entries.case_id},x.case_id));assert(isscalar(match));y=b.entries(match);
 assert(~isempty(x.completed_folder)&&~isempty(y.completed_folder));
 ra=check_record(x.completed_folder,here);rb=check_record(y.completed_folder,here);
 assert(isequaln(ra.source_files,rb.source_files)&&isequaln(ra.contracts,rb.contracts)&&strcmp(ra.matlab_version,rb.matlab_version));
 [same,count,failures]=compare_raw(fullfile(x.completed_folder,'signals.mat'),fullfile(y.completed_folder,'signals.mat'),{});
 ma=jsondecode(fileread(fullfile(x.completed_folder,'metrics.json')));mb=jsondecode(fileread(fullfile(y.completed_folder,'metrics.json')));
 r=struct('case_id',x.case_id,'raw_Time_Data_identical',same,'numeric_elements',count,'failures',{failures},...
  'metrics_identical',isequaln(ma,mb),'case_required_passed',ra.all_passed&&rb.all_passed,...
  'passed',same&&isequaln(ma,mb)&&ra.all_passed&&rb.all_passed);
 if isempty(rows),rows=r;else,rows(end+1)=r;end %#ok<AGROW>
 baselineId=x.case_id;
 if startsWith(baselineId,'mismatch_')||ismember(baselineId,{'noise_002A','missing_5_samples','observer_reset'}),baselineId='steady_3000';end
 base=find(strcmp({a.entries.kind},'plant_reference')&strcmp({a.entries.case_id},baselineId));assert(isscalar(base));
 ref=a.entries(base);check_record(ref.completed_folder,here);
 [same,count,failures]=compare_raw(fullfile(ref.completed_folder,'signals.mat'),fullfile(x.completed_folder,'signals.mat'),oldNames);
 rr=struct('case_id',x.case_id,'baseline_case_id',baselineId,'old_logs',numel(oldNames),'identical',same,'numeric_elements',count,'failures',{failures});
 if isempty(regressions),regressions=rr;else,regressions(end+1)=rr;end %#ok<AGROW>
 fprintf('N3_REPLAY %s data=%d old52=%d\n',x.case_id,r.passed,rr.identical);
end
assert(numel(rows)==16,'All sixteen frozen cases required.');
report=struct('schema',1,'node','N3','original_folder',originalFolder,'replay_folder',replayFolder,...
 'driver_sha256',teach_hash([mfilename('fullpath') '.m']),'cases',rows,'old_log_regressions',regressions,...
 'all_passed',all([rows.passed])&&all([regressions.identical]));
teach_writejson(fullfile(replayFolder,'replay_validation.json'),report);
fprintf('N3_REPLAY_ALL_PASSED=%d elements=%g\n',report.all_passed,sum([rows.numeric_elements]));
end
function r=check_record(folder,here)
r=jsondecode(fileread(fullfile(folder,'record.json')));assert(ismember(r.status,{'passed','failed_metrics'}));
assert(strcmp(r.raw_sha256,teach_hash(fullfile(folder,'signals.mat'))));
for f=r.source_files(:)',assert(strcmp(f.sha256,teach_hash(fullfile(here,f.path))),'Source changed: %s',f.path);end
for f=r.contracts(:)',assert(strcmp(f.sha256,teach_hash(fullfile(here,f.path))));end
assert(r.layer_restored&&r.reference_restored);
end
function [passed,count,failures]=compare_raw(first,second,names)
a=whos('-file',first);b=whos('-file',second);
if isempty(names),assert(isequal({a.name},{b.name}));names={a.name};end
count=0;failures={};
for k=1:numel(names)
 name=names{k};x=load(first,name);y=load(second,name);p=x.(name);q=y.(name);
 count=count+numel(p.Time)+numel(p.Data);
 if ~isequaln(p.Time,q.Time)||~isequaln(p.Data,q.Data),failures{end+1}=name;end %#ok<AGROW>
 clear x y p q;
end
passed=isempty(failures);
end
