function result=validate_pmsm_power_integration(folder,repeatedFolder)
% Independently rerun the saved configuration, compare all retained samples.
here=fileparts(mfilename('fullpath'));root=fileparts(here);addpath(fullfile(root,'teaching'));
r=jsondecode(fileread(fullfile(folder,'record.json')));
assert(strcmp(r.status,'completed')&&strcmp(r.kind,'power_feedback_integration_v1'));
for f=r.files(:)',assert(strcmp(f.sha256,teach_hash(fullfile(folder,f.path))),'Archive changed: %s',f.path);end
for f=r.source_files(:)',assert(strcmp(f.sha256,teach_hash(fullfile(root,f.path))),'Source changed: %s',f.path);end
assert(strcmp(r.model_sha256,teach_hash(fullfile(root,'PMSM_FOC_R2026a.slx'))));
if nargin<2
 receipt=fullfile(root,'.build',['power_repeat_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS')) '.json']);
 command=sprintf('addpath(''%s'',''%s''); r=run_pmsm_power_integration(%.17g); teach_writejson(''%s'',r);',...
  strrep(here,'''',''''''),strrep(fullfile(root,'teaching'),'''',''''''),r.duration_s,strrep(receipt,'''',''''''));
 [status,log]=system(sprintf('"%s" -batch "%s"',fullfile(matlabroot,'bin','matlab.exe'),command));
 fprintf('%s',log);assert(status==0,'独立复跑失败，原档案保留。');
 again=jsondecode(fileread(receipt));repeatedFolder=again.folder;
end
again=jsondecode(fileread(fullfile(repeatedFolder,'record.json')));
assert(strcmp(again.status,'completed')&&strcmp(again.kind,r.kind));
for f=again.files(:)',assert(strcmp(f.sha256,teach_hash(fullfile(again.folder,f.path))));end
for f=again.source_files(:)',assert(strcmp(f.sha256,teach_hash(fullfile(root,f.path))));end
outputs=cell(1,3);for k=1:3,x=load(fullfile(again.folder,[again.cases(k).id '.mat']),'signals');outputs{k}=x.signals;end
assert(strcmp(r.model_sha256,again.model_sha256)&&strcmp(r.reference_sha256,again.reference_sha256));
plan=jsondecode(fileread(fullfile(folder,'plan.json')));
repeatedPlan=jsondecode(fileread(fullfile(again.folder,'plan.json')));assert(isequaln(plan,repeatedPlan));
count=0;
for k=1:3
 x=load(fullfile(folder,[r.cases(k).id '.mat']),'signals');names=fieldnames(x.signals);
 assert(isequal(names,fieldnames(outputs{k})));
 for n=names'
  a=x.signals.(n{1});b=outputs{k}.(n{1});
  assert(isequal(a.Time,b.Time)&&isequal(a.Data,b.Data),'Repeat mismatch: %s/%s',r.cases(k).id,n{1});
  count=count+1;
 end
end
result=struct('kind',r.kind,'passed',true,'original_folder',folder,'repeated_folder',again.folder,...
 'duration_s',r.duration_s,'signal_count',count,'all_time_data_exact',true,...
 'model_sha256',r.model_sha256,'reference_sha256',r.reference_sha256,...
 'restored_reference',r.restored_reference&&again.restored_reference,...
 'original_structure_preserved',r.original_structure_preserved&&again.original_structure_preserved,...
 'validator_sha256',teach_hash(mfilename('fullpath')+".m"),...
 'boundary','Short startup integration only; no full-run gate, platform or calibrated-hardware claim.');
teach_writejson(fullfile(here,'power_integration_validation.json'),result);
fprintf('POWER_INTEGRATION_VALIDATED %d exact signals\n',count);
end
