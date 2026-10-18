function report=analyse_sensorless_r2_codegen_archive(folder,destination)
% Read-only attribution of a failed exact qualification; never simulates.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);addpath(fullfile(modern,'teaching'));
assert(~isfolder(destination));mkdir(destination);r=jsondecode(fileread(fullfile(folder,'record.json')));
rawFile=fullfile(folder,'signals.mat');assert(strcmp(r.raw_sha256,teach_hash(rawFile))&&strcmp(r.phase,'completed'));
canonicalFile=fullfile(folder,'log_format','signals.mat');canonicalRecord=jsondecode(fileread(fullfile(folder,'log_format','record.json')));
assert(strcmp(canonicalRecord.raw_sha256,teach_hash(canonicalFile)));
reference=fullfile(base,'runs/N3R2_fault_final_short_precheck_20261017_141116_c027734c-49b8-4ecd-8e60-81a403609cfc/r1_short_logging_check_attempt_2');
expected=jsondecode(fileread(fullfile(reference,'record.json')));goldFile=fullfile(reference,'signals.mat');assert(strcmp(expected.raw_sha256,teach_hash(goldFile)));
report=struct('kind','analysis_only_codegen_archive_differences','analysis_only',true,'simulation_reexecuted',false,...
 'models_loaded',false,'R2_passed',false,'original_qualification_remains_failed',true,...
 'process_id',matlabProcessID,'source_folder',folder,'source_record_sha256',teach_hash(fullfile(folder,'record.json')),...
 'raw_sha256',r.raw_sha256,'canonical_sha256',canonicalRecord.raw_sha256,'reference_sha256',expected.raw_sha256,...
 'legacy_verifier_requires_missing_initialized_once_field',~isfield(r.execution,'initialized_once'));
copyfile([mfilename('fullpath') '.m'],fullfile(destination,'analysis_source.m.txt'));report.analysis_source_sha256=teach_hash([mfilename('fullpath') '.m']);
a=load(goldFile);b=load(rawFile);c=load(canonicalFile);names=fieldnames(a);assert(numel(names)==96&&isequal(names,fieldnames(b))&&isequal(names,fieldnames(c)));
rows=struct;
for k=1:numel(names)
 name=names{k};x=a.(name);y=b.(name);z=c.(name);assert(isa(x,'timeseries')&&isa(y,'timeseries')&&isa(z,'timeseries'));
 rows.(name)=struct('raw_Time',differences(x.Time,y.Time),'canonical_Time',differences(x.Time,z.Time),...
  'raw_Data',differences(x.Data,y.Data),'canonical_Data',differences(x.Data,z.Data),...
  'normalization_Data_unchanged',isequaln(y.Data,z.Data));
end
report.logs=rows;report.log_count=96;report.raw_Data_equal_logs=sum(structfun(@(x)x.raw_Data.exact,rows));
report.canonical_Data_equal_logs=sum(structfun(@(x)x.canonical_Data.exact,rows));report.canonical_Time_equal_logs=sum(structfun(@(x)x.canonical_Time.exact,rows));
report.all_canonical_Time_Data_equal=all(structfun(@(x)x.canonical_Time.exact&&x.canonical_Data.exact,rows));
report.raw_archive_unchanged=strcmp(r.raw_sha256,teach_hash(rawFile));assert(report.raw_archive_unchanged);
teach_writejson(fullfile(destination,'report.json'),report);
fprintf('ARCHIVE_ANALYSIS Data_equal=%d Time_equal=%d logs=96\n',report.canonical_Data_equal_logs,report.canonical_Time_equal_logs);
end
function result=differences(x,y)
result=struct('exact',isequaln(x,y),'class_equal',strcmp(class(x),class(y)),'dimensions_equal',isequal(size(x),size(y)),...
 'expected_dimensions',size(x),'actual_dimensions',size(y),'different_elements',[],'max_abs_delta',[],'first_linear_index',[],'expected_first',[],'actual_first',[]);
if ~result.class_equal||~result.dimensions_equal,return;end
mask=~((x==y)|(isnan(x)&isnan(y)));result.different_elements=nnz(mask);result.max_abs_delta=max(abs(double(x(:))-double(y(:))));
if any(mask,'all'),index=find(mask,1);result.first_linear_index=index;result.expected_first=double(x(index));result.actual_first=double(y(index));end
end
