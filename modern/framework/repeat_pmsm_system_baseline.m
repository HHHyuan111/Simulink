function [r,check]=repeat_pmsm_system_baseline(folder)
here=fileparts(mfilename('fullpath'));root=fileparts(here);addpath(fullfile(root,'teaching'));
old=verify_pmsm_system_baseline(folder);
assert(strcmp(teach_hash(fullfile(root,'PMSM_FOC_R2026a.slx')),old.model_sha256));
for f=old.source_files(:)',assert(strcmp(teach_hash(fullfile(root,f.path)),f.sha256),'源码已变化，不能冒充同版本复跑：%s',f.path);end
plan=pmsm_system_plan(old.value);saved=jsondecode(fileread(fullfile(folder,'plan.json')));
assert(isequaln(jsondecode(jsonencode(plan)),saved),'整机计划已变化。');
[r,outputs]=run_pmsm_system_baseline(old.value);
check=struct('original_folder',folder,'repeated_folder',r.folder,'same_matlab_version',strcmp(old.matlab_version,r.matlab_version),...
 'signals',struct('case_id',{},'name',{},'same_time',{},'same_data',{}),'all_exact',true);
idx=0;for k=1:2,x=load(fullfile(folder,[old.cases(k).id '.mat']),'signals');
 for name=fieldnames(x.signals)',idx=idx+1;a=x.signals.(name{1});b=outputs{k}.(name{1});
  st=isequaln(a.Time,b.Time);sd=isequaln(a.Data,b.Data);
  check.signals(idx)=struct('case_id',old.cases(k).id,'name',name{1},'same_time',st,'same_data',sd);
  check.all_exact=check.all_exact&&st&&sd;
 end
end
out=fullfile(here,'repeat_checks');if ~isfolder(out),mkdir(out);end
teach_writejson(fullfile(out,[r.id '.json']),check);fprintf('SYSTEM_REPEAT_EXACT %d\n',check.all_exact);
end
