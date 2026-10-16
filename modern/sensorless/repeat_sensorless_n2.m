function result=repeat_sensorless_n2(originalFolder)
% Start from a separate MATLAB -batch process; compare every archived sample.
here=fileparts(mfilename('fullpath'));addpath(here,fullfile(fileparts(here),'teaching'));
original=jsondecode(fileread(fullfile(originalFolder,'record.json')));
assert(strcmp(original.status,'passed')&&original.all_passed,'Original N2 did not pass.');
assert(strcmp(original.matlab_version,version),'MATLAB version changed.');
for f=original.source_files(:)'
 assert(strcmp(f.sha256,teach_hash(fullfile(here,f.path))),'Source changed: %s',f.path);
end
assert(strcmp(original.plan_sha256,teach_hash(fullfile(here,'milestones','N2_test_plan.json'))));
assert(strcmp(original.model_sha256,teach_hash(fullfile(fileparts(here),'PMSM_FOC_R2026a.slx'))));
for r=original.cases(:)'
 assert(strcmp(r.sha256,teach_hash(fullfile(originalFolder,r.file))),'Raw data changed: %s',r.file);
end
replay=validate_sensorless_n2;
rows=struct('case_id',{},'logs',{},'numeric_elements',{},'identical',{},'failures',{});
for k=1:numel(original.cases)
 a=original.cases(k);b=replay.cases(k);assert(strcmp(a.id,b.id));
 before=load(fullfile(originalFolder,a.file),'signals');after=load(fullfile(replay.folder,b.file),'signals');
 names=fieldnames(before.signals);assert(isequal(names,fieldnames(after.signals)));
 failures={};count=0;
 for j=1:numel(names)
  name=names{j};x=before.signals.(name);y=after.signals.(name);
  count=count+numel(x.Time)+numel(x.Data);
  if ~isequaln(x.Time,y.Time)||~isequaln(x.Data,y.Data),failures{end+1}=name;end %#ok<AGROW>
 end
 rows(k)=struct('case_id',a.id,'logs',numel(names),'numeric_elements',count,...
  'identical',isempty(failures),'failures',{failures});
end
before=jsondecode(fileread(fullfile(originalFolder,'analysis.json')));
after=jsondecode(fileread(fullfile(replay.folder,'analysis.json')));
result=struct('schema',1,'node','N2','original_folder',originalFolder,'replay_folder',replay.folder,...
 'matlab_version',version,'driver_sha256',teach_hash(fullfile(here,'repeat_sensorless_n2.m')),...
 'cases',rows,'analysis_identical',isequaln(before,after),...
 'all_passed',all([rows.identical])&&isequaln(before,after));
teach_writejson(fullfile(replay.folder,'replay_validation.json'),result);
fprintf('N2_REPLAY_PASSED=%d numeric_elements=%d\n',result.all_passed,sum([rows.numeric_elements]));
assert(result.all_passed,'N2 replay differed; preserve both runs.');
end
