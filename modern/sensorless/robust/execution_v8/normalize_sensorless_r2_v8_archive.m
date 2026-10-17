function report=normalize_sensorless_r2_v8_archive(folder)
% Representation adaptation only. Raw archive and all data remain intact.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);addpath(base,fullfile(modern,'teaching'));
r=jsondecode(fileread(fullfile(folder,'record.json')));assert(strcmp(r.phase,'completed')&&r.reference_restored&&r.native_endpoint_verified);
raw=fullfile(folder,'signals.mat');assert(strcmp(r.raw_sha256,teach_hash(raw)));destination=fullfile(folder,'log_format');assert(~isfolder(destination));mkdir(destination);
contract=fullfile(base,'contracts/nonideal_r2_v8_uniform_log_format.json');snapshot=load(fullfile(folder,'restoration.mat'),'original');h=r.config_vector(1);replacement=struct;
report=struct('kind','analysis_only_uniform_timestamp_encoding','all_passed',false,'simulation_reexecuted',false,...
 'raw_archive_unchanged',true,'raw_sha256',r.raw_sha256,'source_folder',folder,'destination',destination,...
 'adapter_sha256',teach_hash([mfilename('fullpath') '.m']),'contract_sha256',teach_hash(contract));
names={'obs_dead_gates','obs_dead_requested'};
for k=1:numel(names)
 name=names{k};cap=NaN;
 for block=snapshot.original.blocks(:)'
  if isfield(block.params,'VariableName')&&strcmp(block.params.VariableName,name),cap=str2double(block.params.MaxDataPoints);end
 end
 assert(cap==4000);value=load(raw,name);value=value.(name);assert(numel(value.Time)==cap);
 ticks=round(value.Time/h);assert(all(diff(ticks)==1));uniform=ticks(1)*h+(0:numel(ticks)-1)'*h;
 delta=max(abs(value.Time-uniform));assert(isequaln(ticks,round(uniform/h))&&delta<=4*eps(max(abs(value.Time))));
 data=value.Data;value.Time=uniform;assert(isequaln(data,value.Data));replacement.(name)=value;
 report.logs(k)=struct('name',name,'samples',numel(ticks),'native_ticks_unchanged',true,'Data_unchanged',true,...
  'first_tick',ticks(1),'last_tick',ticks(end),'max_time_encoding_delta_s',delta);
end
copyfile(raw,fullfile(destination,'signals.mat'));save(fullfile(destination,'signals.mat'),'-struct','replacement','-append');
report.canonical_sha256=teach_hash(fullfile(destination,'signals.mat'));copyfile(contract,fullfile(destination,'format_contract.json'));
copyfile([mfilename('fullpath') '.m'],fullfile(destination,'normalizer_source.m.txt'));
derived=r;derived.folder=strrep(destination,'\','/');derived.raw_sha256=report.canonical_sha256;derived.analysis_only=true;derived.original_record_sha256=teach_hash(fullfile(folder,'record.json'));
derived.raw_api_archive_sha256=r.raw_sha256;teach_writejson(fullfile(destination,'record.json'),derived);
if strcmp(r.case_id,'r1_short_logging_check')
 verify_sensorless_r2_logging(destination);verify_sensorless_r2_v8_short(destination);report.strict96_and_R1_81_comparisons_passed=true;
end
assert(strcmp(r.raw_sha256,teach_hash(raw)));report.all_passed=true;teach_writejson(fullfile(folder,'log_format_recovery.json'),report);
end
