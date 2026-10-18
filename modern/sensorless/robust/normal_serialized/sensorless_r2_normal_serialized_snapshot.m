function record=sensorless_r2_normal_serialized_snapshot(folder)
% Bind the same Normal implementation for both shorts and later formal cases.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));record=sensorless_r2_staged_snapshot(folder);
record.execution_version='normal_serialized_parent_and_observer';
for file=dir(fullfile(here,'*.m'))'
 relative=['robust/normal_serialized/' file.name];target=fullfile(folder,'source',relative);
 if ~isfolder(fileparts(target)),mkdir(fileparts(target));end
 copyfile(fullfile(file.folder,file.name),target);record.source_files(end+1)=struct('path',relative,'sha256',teach_hash(fullfile(file.folder,file.name)));
end
for relative={'contracts/nonideal_r2_normal_serialized_acceptance.json','robust/normal_serialized/derivation.json'}
 target=fullfile(folder,relative{1});if ~isfolder(fileparts(target)),mkdir(fileparts(target));end
 copyfile(fullfile(base,relative{1}),target);record.contracts(end+1)=struct('path',relative{1},'sha256',teach_hash(fullfile(base,relative{1})));
end
record.normal_policy=struct('parent','Normal','child','Normal','explicit_generated_target_builds',0,...
 'private_compiler_setup',false,'native_root_cause_resolved',false,'no_feedback_takeover',true);
teach_writejson(fullfile(folder,'record.json'),record);
end
