function record=validate_sensorless_n2
% Frozen N2 integration cases. Same original model, removable observer layer.
here=fileparts(mfilename('fullpath'));root=fileparts(here);mdl='PMSM_FOC_R2026a';
for section={'','sensorless','teaching','control','timing','deadtime','framework','layout/appearance'},addpath(fullfile(root,section{1}));end
assert(~bdIsLoaded(mdl),'请在独立MATLAB进程执行N2。');
id=['N2_' char(datetime('now','TimeZone','Asia/Shanghai','Format','yyyyMMdd_HHmmss_SSS')) '_' char(java.util.UUID.randomUUID)];
folder=fullfile(here,'runs',id);mkdir(folder);mkdir(fullfile(folder,'source'));
sldiagviewer.diary(fullfile(folder,'diagnostics.log'),'UTF-8');
Simulink.fileGenControl('set','CacheFolder',fullfile(here,'.build','n2_cache'),...
 'CodeGenFolder',fullfile(here,'.build','n2_codegen'),'createDir',true);
planFile=fullfile(here,'milestones','N2_test_plan.json');plan=jsondecode(fileread(planFile));
record=struct('schema',1,'node','N2','folder',folder,'status','running','matlab_version',version,...
 'plan_sha256',teach_hash(planFile),'model_sha256',teach_hash(fullfile(root,[mdl '.slx'])),...
 'source_files',struct('path',{},'sha256',{}),'cases',struct('id',{},'file',{},'sha256',{},'installed',{},'restored',{}));
files=[dir(fullfile(here,'*.m'));dir(fullfile(here,'blocks','*.m'))];
for f=files(:)'
 relative=strrep(erase(fullfile(f.folder,f.name),[here filesep]),'\','/');
 record.source_files(end+1)=struct('path',relative,'sha256',teach_hash(fullfile(f.folder,f.name))); %#ok<AGROW>
 target=fullfile(folder,'source',relative);if ~isfolder(fileparts(target)),mkdir(fileparts(target));end
 copyfile(fullfile(f.folder,f.name),target);
end
teach_writejson(fullfile(folder,'record.json'),record);
try
 for k=1:numel(plan.cases)
  record.cases(k)=validate_sensorless_n2_case(plan.cases(k),folder);
  teach_writejson(fullfile(folder,'record.json'),record);
 end
 assert(strcmp(record.model_sha256,teach_hash(fullfile(root,[mdl '.slx']))));
 for f=record.source_files(:)',assert(strcmp(f.sha256,teach_hash(fullfile(here,f.path))),'验收期间源码改变。');end
 analysis=analyse_sensorless_n2(folder);teach_writejson(fullfile(folder,'analysis.json'),analysis);
 record.all_passed=analysis.all_passed;if record.all_passed,record.status='passed';else,record.status='failed';end
 teach_writejson(fullfile(folder,'record.json'),record);
 fprintf('N2_STATUS=%s folder=%s\n',record.status,folder);
 assert(record.all_passed,'sensorless:N2Failed','N2必选检查失败，保留原始数据。');
catch err
 record.status='failed';record.error=err.message;teach_writejson(fullfile(folder,'record.json'),record);rethrow(err);
end
end
