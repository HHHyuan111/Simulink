function sensorless_n2_isolated(action,originalFolder,folder,index)
% Process-isolated replay of the SAME frozen cases and comparisons.
here=fileparts(mfilename('fullpath'));root=fileparts(here);
for section={'','sensorless','teaching','control','timing','deadtime','framework','layout/appearance'},addpath(fullfile(root,section{1}));end
original=jsondecode(fileread(fullfile(originalFolder,'record.json')));
assert(strcmp(original.status,'passed')&&original.all_passed);
assert(strcmp(original.matlab_version,version));
for f=original.source_files(:)'
 assert(strcmp(f.sha256,teach_hash(fullfile(here,f.path))),'Source changed: %s',f.path);
end
assert(strcmp(original.plan_sha256,teach_hash(fullfile(here,'milestones','N2_test_plan.json'))));
assert(strcmp(original.model_sha256,teach_hash(fullfile(root,'PMSM_FOC_R2026a.slx'))));
if ~isfolder(folder),mkdir(folder);end
plan=jsondecode(fileread(fullfile(here,'milestones','N2_test_plan.json')));
if strcmp(action,'case')
 build=fullfile(folder,'.build',plan.cases(index).id);
 Simulink.fileGenControl('set','CacheFolder',fullfile(build,'cache'),...
  'CodeGenFolder',fullfile(build,'codegen'),'createDir',true);
 sldiagviewer.diary(fullfile(folder,[plan.cases(index).id '_diagnostics.log']),'UTF-8');
 r=validate_sensorless_n2_case(plan.cases(index),folder);
 r.process_id=feature('getpid');r.matlab_version=version;
 teach_writejson(fullfile(folder,[r.id '_record.json']),r);
 fprintf('N2_ISOLATED_CASE_PASSED %s pid=%d\n',r.id,r.process_id);
 return;
end
assert(strcmp(action,'finish'));
record=original;record.folder=folder;record.status='running';record.cases=struct([]);
record.isolated_driver_sha256=teach_hash([mfilename('fullpath') '.m']);
record.original_folder=originalFolder;
for k=1:numel(plan.cases)
 r=jsondecode(fileread(fullfile(folder,[plan.cases(k).id '_record.json'])));
 assert(strcmp(r.matlab_version,version));
 if k==1,record.cases=r;else,record.cases(k)=r;end
end
assert(numel(unique([record.cases.process_id]))==numel(plan.cases));
teach_writejson(fullfile(folder,'record.json'),record);
analysis=analyse_sensorless_n2(folder);teach_writejson(fullfile(folder,'analysis.json'),analysis);
assert(analysis.all_passed);record.status='passed';record.all_passed=true;
teach_writejson(fullfile(folder,'record.json'),record);
rows=struct('case_id',{},'logs',{},'numeric_elements',{},'identical',{},'failures',{});
for k=1:numel(record.cases)
 a=original.cases(k);b=record.cases(k);
 assert(strcmp(a.sha256,teach_hash(fullfile(originalFolder,a.file))));
 before=load(fullfile(originalFolder,a.file),'signals');after=load(fullfile(folder,b.file),'signals');
 names=fieldnames(before.signals);assert(isequal(names,fieldnames(after.signals)));
 failures={};count=0;
 for j=1:numel(names)
  name=names{j};x=before.signals.(name);y=after.signals.(name);count=count+numel(x.Time)+numel(x.Data);
  if ~isequaln(x.Time,y.Time)||~isequaln(x.Data,y.Data),failures{end+1}=name;end %#ok<AGROW>
 end
 rows(k)=struct('case_id',a.id,'logs',numel(names),'numeric_elements',count,...
  'identical',isempty(failures),'failures',{failures});
end
originalAnalysis=jsondecode(fileread(fullfile(originalFolder,'analysis.json')));
result=struct('schema',1,'node','N2','original_folder',originalFolder,'replay_folder',folder,...
 'process_policy','one fresh MATLAB process per frozen case, then a fresh analysis process',...
 'matlab_version',version,'driver_sha256',record.isolated_driver_sha256,'cases',rows,...
 'analysis_identical',isequaln(originalAnalysis,analysis),...
 'all_passed',all([rows.identical])&&isequaln(originalAnalysis,analysis));
teach_writejson(fullfile(folder,'replay_validation.json'),result);
assert(result.all_passed,'Isolated replay differed.');
fprintf('N2_ISOLATED_REPLAY_PASSED numeric_elements=%d\n',sum([rows.numeric_elements]));
end
