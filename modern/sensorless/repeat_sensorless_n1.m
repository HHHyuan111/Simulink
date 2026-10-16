function result=repeat_sensorless_n1(originalFolder)
% Run in a NEW MATLAB process. Verify source/config, then compare raw arrays.
here=fileparts(mfilename('fullpath'));addpath(here,fullfile(fileparts(here),'teaching'));
original=jsondecode(fileread(fullfile(originalFolder,'record.json')));
assert(strcmp(original.status,'passed')&&original.all_passed,'原记录不是已通过的N1。');
assert(strcmp(original.matlab_version,version),'MATLAB版本不同。');
for f=original.source_files(:)'
 assert(strcmp(f.sha256,teach_hash(fullfile(here,f.path))),'源码已改变：%s',f.path);
end
assert(strcmp(original.contract_sha256,teach_hash(fullfile(here,'contracts','acceptance_v1.json'))));
assert(strcmp(original.test_plan_sha256,teach_hash(fullfile(here,'contracts','test_plan_v1.json'))));
assert(strcmp(original.raw_sha256,teach_hash(fullfile(originalFolder,'raw.mat'))),'原始数据被改动。');
replay=validate_sensorless_n1;
before=load(fullfile(originalFolder,'raw.mat'),'raw');after=load(fullfile(replay.folder,'raw.mat'),'raw');
names=fieldnames(before.raw);assert(isequal(names,fieldnames(after.raw)));
rows=struct('group',{},'identical',{},'numeric_elements',{});
for k=1:numel(names)
 name=names{k};rows(k)=struct('group',name,'identical',isequaln(before.raw.(name),after.raw.(name)),...
  'numeric_elements',count_elements(before.raw.(name)));
end
originalMetrics=jsondecode(fileread(fullfile(originalFolder,'metrics.json')));
replayMetrics=jsondecode(fileread(fullfile(replay.folder,'metrics.json')));
result=struct('schema',1,'node','N1','original_folder',originalFolder,'replay_folder',replay.folder,...
 'matlab_version',version,'new_process_requirement','caller starts a separate MATLAB -batch process',...
 'driver_sha256',teach_hash(fullfile(here,'repeat_sensorless_n1.m')),'groups',rows,...
 'metrics_identical',isequaln(originalMetrics,replayMetrics),'all_passed',all([rows.identical])&&isequaln(originalMetrics,replayMetrics));
teach_writejson(fullfile(replay.folder,'replay_validation.json'),result);
fprintf('N1_REPLAY_PASSED=%d numeric_elements=%d\n',result.all_passed,sum([rows.numeric_elements]));
assert(result.all_passed,'N1独立复跑不一致；保留失败记录。');
end

function n=count_elements(value)
n=0;
if isnumeric(value)||islogical(value),n=numel(value);
elseif iscell(value),for k=1:numel(value),n=n+count_elements(value{k});end
elseif isstruct(value)
 for j=1:numel(value),for key=fieldnames(value)',n=n+count_elements(value(j).(key{1}));end,end
end
end
