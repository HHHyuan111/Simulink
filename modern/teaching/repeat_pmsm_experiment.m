function [record,verification]=repeat_pmsm_experiment(folder)
% Repeat an archived fixed experiment and compare retained numeric records.
here=fileparts(mfilename('fullpath'));original=pmsm_experiment_verify(folder);
assert(strcmp(teach_hash(fullfile(here,'reference_v1','manifest.json')),original.baseline_manifest_sha256),'原实验的固定参考版本不同。');
plan=pmsm_experiment_plan(original.scenario.id,original.factor_value,original.duration_s);
assert(numel(plan.cases)==numel(original.cases));
for k=1:numel(plan.cases),assert(isequaln(plan.cases(k).configuration,original.cases(k).configuration),'原实验配置与当前场景定义不符。');end
[record,outputs]=run_pmsm_experiment(original.scenario.id,original.factor_value,original.duration_s);
verification=struct('schema',1,'original_folder',folder,'repeated_folder',record.folder, ...
 'original_record_sha256',teach_hash(fullfile(folder,'record.json')),'repeated_record_sha256',teach_hash(fullfile(record.folder,'record.json')), ...
 'same_matlab_version',strcmp(original.matlab_version,record.matlab_version), ...
 'model_sha256',record.model_sha256,'baseline_manifest_sha256',record.baseline_manifest_sha256, ...
 'comparison','原档案保留的每路信号Time/Data逐点比较；不比较PNG或MAT文件字节。', ...
 'signals',struct('case_id',{},'name',{},'same_time',{},'same_data',{},'max_abs_error',{}),'all_exact',true);
for k=1:numel(original.cases)
 archived=load(fullfile(folder,[original.cases(k).id '.mat']),'signals');names=fieldnames(archived.signals);
 for name=names'
  a=archived.signals.(name{1});b=outputs{k}.(name{1});timeSame=isequaln(a.Time,b.Time);dataSame=isequaln(a.Data,b.Data);error=[];
  if isequal(size(a.Data),size(b.Data)),error=max(abs(double(a.Data(:))-double(b.Data(:))));end
  verification.signals(end+1)=struct('case_id',original.cases(k).id,'name',name{1},'same_time',timeSame,'same_data',dataSame,'max_abs_error',error);
  verification.all_exact=verification.all_exact&&timeSame&&dataSame;
 end
end
out=fullfile(here,'experiments','repeat_checks');if ~isfolder(out),mkdir(out);end
teach_writejson(fullfile(out,[record.id '.json']),verification);
fprintf('REPEAT_EXACT %d | %s\n',verification.all_exact,record.folder);
end
