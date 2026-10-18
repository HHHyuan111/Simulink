function report=compare_sensorless_r2_normal_serialized_shorts(first,second,output)
% Cross-process comparison of the same saved, source-bound physical artifact.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);addpath(base,fullfile(modern,'teaching'));
assert(~isfile(output));a=jsondecode(fileread(fullfile(first,'record.json')));b=jsondecode(fileread(fullfile(second,'record.json')));
assert(strcmp(a.status,'passed')&&strcmp(b.status,'passed')&&a.process_id~=b.process_id&&a.builder_process_id==b.builder_process_id);
assert(isequaln(a.source_files,b.source_files)&&isequaln(a.contracts,b.contracts)&&isequaln(a.effective_case,b.effective_case));
assert(isequaln(a.observer_config,b.observer_config)&&isequaln(a.config_vector,b.config_vector));
assert(strcmp(a.exported_parent_sha256,b.exported_parent_sha256)&&strcmp(a.exported_child_sha256,b.exported_child_sha256));
assert(a.native_endpoint_verified&&b.native_endpoint_verified&&a.reference_restored&&b.reference_restored&&a.main_bridge_preserved&&b.main_bridge_preserved);
f=jsondecode(fileread(fullfile(first,'log_format_recovery.json')));s=jsondecode(fileread(fullfile(second,'log_format_recovery.json')));assert(f.all_passed&&s.all_passed);
left=fullfile(first,'log_format','signals.mat');right=fullfile(second,'log_format','signals.mat');
assert(strcmp(f.canonical_sha256,teach_hash(left))&&strcmp(s.canonical_sha256,teach_hash(right)));
names=whos('-file',left);other=whos('-file',right);assert(numel(names)==96&&isequal({names.name},{other.name}));
[same,count,failures]=compare_sensorless_n3_raw(left,right,{names.name});
report=struct('kind','two_independent_normal_serialized_short_comparison','all_passed',same,'logs',96,...
 'numeric_elements',count,'all_Time_Data_class_dimensions_equal',same,'failures',{failures},'analysis_only',true,'simulation_reexecuted',false,...
 'first_process_id',a.process_id,'second_process_id',b.process_id,'builder_process_id',a.builder_process_id,...
 'first_record_sha256',teach_hash(fullfile(first,'record.json')),'second_record_sha256',teach_hash(fullfile(second,'record.json')),...
 'saved_parent_sha256',a.exported_parent_sha256,'saved_child_sha256',a.exported_child_sha256,'R2_passed',false);
teach_writejson(output,report);assert(same,strjoin(failures,','));
end
