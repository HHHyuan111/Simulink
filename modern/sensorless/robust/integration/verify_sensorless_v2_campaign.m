function report=verify_sensorless_v2_campaign(campaign)
% Fresh third process. Complete arrays, all four cases and all original logs.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);
addpath(base,fileparts(here),here,fullfile(modern,'teaching'));
assert(~bdIsLoaded('PMSM_FOC_R2026a'));manifest=jsondecode(fileread(fullfile(campaign,'campaign.json')));
jobs=manifest.jobs;report=struct('schema',1,'node','N3R1','campaign',campaign,'model_loaded',false,...
 'component_raw_identical',false,'cases',struct('id',{},'replay_all_logs',{},'replay_elements',{},'original_52_formal',{},'original_52_replay',{},'regression_elements',{}));
a=folder('component_first');b=folder('component_replay');ra=check(a,'raw.mat');rb=check(b,'raw.mat');
assert(isequaln(ra.source_files,rb.source_files)&&isequaln(ra.contracts,rb.contracts));
x=load(fullfile(a,'raw.mat'));y=load(fullfile(b,'raw.mat'));report.component_raw_identical=isequaln(x,y);assert(report.component_raw_identical);clear x y;
schema=jsondecode(fileread(fullfile(base,'baseline','log_schema.json')));oldNames={schema.name};assert(numel(oldNames)==52);
for id={'combined','rail','window','deadline'}
 a=folder([id{1} '_formal']);b=folder([id{1} '_replay']);reference=folder([id{1} '_baseline']);
 ra=check(a,'signals.mat');rb=check(b,'signals.mat');rc=check(reference,'signals.mat');
 assert(isequaln(ra.source_files,rb.source_files)&&isequaln(ra.source_files,rc.source_files));
 assert(isequaln(ra.contracts,rb.contracts)&&isequaln(ra.contracts,rc.contracts));
 [same,count,failures]=compare_sensorless_n3_raw(fullfile(a,'signals.mat'),fullfile(b,'signals.mat'));assert(same,strjoin(failures,','));
 [sameA,nA,failures]=compare_sensorless_n3_raw(fullfile(a,'signals.mat'),fullfile(reference,'signals.mat'),oldNames);assert(sameA,strjoin(failures,','));
 [sameB,nB,failures]=compare_sensorless_n3_raw(fullfile(b,'signals.mat'),fullfile(reference,'signals.mat'),oldNames);assert(sameB,strjoin(failures,','));
 report.cases(end+1)=struct('id',id{1},'replay_all_logs',same,'replay_elements',count,...
  'original_52_formal',sameA,'original_52_replay',sameB,'regression_elements',nA+nB); %#ok<AGROW>
 fprintf('N3R1_EXACT_REPLAY_REGRESSION %s replay=%d regression=%d\n',id{1},count,nA+nB);
end
report.all_passed=true;report.verification_process_id=feature('getpid');report.driver_sha256=teach_hash([mfilename('fullpath') '.m']);
teach_writejson(fullfile(campaign,'verification.json'),report);
fprintf('N3R1_VERIFICATION_PASSED %s\n',campaign);
 function p=folder(label)
  i=find(strcmp({jobs.label},label));assert(isscalar(i)&&strcmp(jobs(i).status,'passed'));
  p=jobs(i).completed_folder;
 end
 function r=check(p,rawname)
  r=jsondecode(fileread(fullfile(p,'record.json')));assert(strcmp(r.status,'passed')&&r.all_passed);
  assert(strcmp(r.raw_sha256,teach_hash(fullfile(p,rawname))));sensorless_v2_guard_sources(r);
  for f=r.source_files(:)',assert(strcmp(f.sha256,teach_hash(fullfile(p,'source',f.path))),'Source capsule damaged.');end
 end
end
