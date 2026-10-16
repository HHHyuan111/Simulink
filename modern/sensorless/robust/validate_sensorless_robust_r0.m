function record=validate_sensorless_robust_r0(folder)
% Frozen R0 component evidence. A fresh process; never loads the PMSM model.
here=fileparts(mfilename('fullpath'));root=fileparts(here);modern=fileparts(root);
addpath(here,fullfile(modern,'teaching'));
if nargin<1
 folder=fullfile(root,'runs',['N3R0_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS')) '_' char(java.util.UUID.randomUUID)]);
end
assert(~isfolder(folder),'Refuse to overwrite a component attempt.');mkdir(folder);mkdir(fullfile(folder,'source'));
record=struct('schema',1,'node','N3R0','folder',folder,'status','running','phase','source_snapshot',...
 'matlab_version',version,'process_id',feature('getpid'),'model_loaded',bdIsLoaded('PMSM_FOC_R2026a'),...
 'model_sha256',teach_hash(fullfile(modern,'PMSM_FOC_R2026a.slx')),...
 'source_files',struct('path',{},'sha256',{}),'contracts',struct('path',{},'sha256',{}));
assert(~record.model_loaded);
for file=dir(fullfile(here,'*.m'))'
 record.source_files(end+1)=struct('path',file.name,'sha256',teach_hash(fullfile(here,file.name))); %#ok<AGROW>
 copyfile(fullfile(here,file.name),fullfile(folder,'source',file.name));
end
for name={'contracts/nonideal_v2.json','milestones/N3R0_test_plan.json','milestones/N3R0_test_addendum.json','milestones/N3R0_test_addendum_live_fault.json'}
 record.contracts(end+1)=struct('path',name{1},'sha256',teach_hash(fullfile(root,name{1})));
 target=fullfile(folder,name{1});if ~isfolder(fileparts(target)),mkdir(fileparts(target));end
 copyfile(fullfile(root,name{1}),target);
end
teach_writejson(fullfile(folder,'record.json'),record);raw=struct;metrics=struct;
try
 record.phase='component_tests';teach_writejson(fullfile(folder,'record.json'),record);
 c=sensorless_robust_config;teach_writejson(fullfile(folder,'effective_parameters.json'),c);
 plan=jsondecode(fileread(fullfile(root,'milestones','N3R0_test_plan.json')));
 additional=jsondecode(fileread(fullfile(root,'milestones','N3R0_test_addendum_live_fault.json')));
 plan.publication.cases=[plan.publication.cases(:);additional.publication_cases(:)];
 [metrics,raw]=sensorless_robust_r0_tests(c,plan);
 save(fullfile(folder,'raw.mat'),'raw','-v7.3');
 teach_writejson(fullfile(folder,'metrics.json'),metrics);record.raw_sha256=teach_hash(fullfile(folder,'raw.mat'));
 record.raw_numeric_elements=numeric_elements(raw);record.all_passed=true;
 for name=fieldnames(metrics)',record.all_passed=record.all_passed&&metrics.(name{1}).all_passed;end
 assert(metrics.bridge.cases==4536&&metrics.deadtime.native_samples==4005&&metrics.schedule.total_cases==253&&metrics.publication.cases==21);
 assert(~bdIsLoaded('PMSM_FOC_R2026a'));
 for f=record.source_files(:)',assert(strcmp(f.sha256,teach_hash(fullfile(here,f.path))),'Source changed during R0 execution.');end
 for f=record.contracts(:)',assert(strcmp(f.sha256,teach_hash(fullfile(root,f.path))),'Frozen R0 contract changed.');end
 assert(strcmp(record.model_sha256,teach_hash(fullfile(modern,'PMSM_FOC_R2026a.slx'))));
 record.phase='completed';record.status='passed';if ~record.all_passed,record.status='failed_metrics';end
 teach_writejson(fullfile(folder,'record.json'),record);
 fprintf('N3R0_COMPONENT_STATUS=%s elements=%d folder=%s\n',record.status,record.raw_numeric_elements,folder);
 assert(record.all_passed,'sensorless:R0Failed','Component checks failed; preserve this attempt.');
catch err
 record.status='failed';record.error=getReport(err,'extended','hyperlinks','off');
 save(fullfile(folder,'raw_failed.mat'),'raw','-v7.3');
 teach_writejson(fullfile(folder,'metrics_failed.json'),metrics);teach_writejson(fullfile(folder,'record.json'),record);rethrow(err);
end
end

function n=numeric_elements(value)
n=0;
if isnumeric(value)||islogical(value),n=numel(value);
elseif isstruct(value)
 for k=1:numel(value),for key=fieldnames(value)',n=n+numeric_elements(value(k).(key{1}));end,end
elseif iscell(value)
 for k=1:numel(value),n=n+numeric_elements(value{k});end
end
end
