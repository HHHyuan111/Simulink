function record=sensorless_r2_observer_codegen_snapshot(folder)
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));record=sensorless_r2_staged_snapshot(folder);
record.execution_version='normal_parent_accelerated_observer';
for file=dir(fullfile(here,'*.m'))'
 relative=['robust/observer_codegen/' file.name];target=fullfile(folder,'source',relative);
 if ~isfolder(fileparts(target)),mkdir(fileparts(target));end
 copyfile(fullfile(file.folder,file.name),target);record.source_files(end+1)=struct('path',relative,'sha256',teach_hash(fullfile(file.folder,file.name)));
end
for relative={'contracts/nonideal_r2_observer_codegen_boundary.json','robust/observer_codegen/derivation.json'}
 target=fullfile(folder,relative{1});if ~isfolder(fileparts(target)),mkdir(fileparts(target));end
 copyfile(fullfile(base,relative{1}),target);record.contracts(end+1)=struct('path',relative{1},'sha256',teach_hash(fullfile(base,relative{1})));
end
file=fullfile(base,'runs/N3R2_accelerated_reference_logging_once/report.json');probe=jsondecode(fileread(file));assert(probe.all_passed);
record.observer_codegen_prerequisite=struct('report_sha256',teach_hash(file),'probe_sha256',probe.probe_sha256,'contract_sha256',probe.contract_sha256);
copyfile(file,fullfile(folder,'observer_codegen_prerequisite.json'));teach_writejson(fullfile(folder,'record.json'),record);
end
