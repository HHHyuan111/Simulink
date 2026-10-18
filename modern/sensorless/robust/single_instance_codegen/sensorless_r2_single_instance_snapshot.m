function record=sensorless_r2_single_instance_snapshot(folder)
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));record=sensorless_r2_continuous_snapshot(folder);
record.execution_version='single_instance_continuous_codegen_adapter';
for file=dir(fullfile(here,'*.m'))'
 relative=['robust/single_instance_codegen/' file.name];target=fullfile(folder,'source',relative);
 if ~isfolder(fileparts(target)),mkdir(fileparts(target));end
 copyfile(fullfile(file.folder,file.name),target);record.source_files(end+1)=struct('path',relative,'sha256',teach_hash(fullfile(file.folder,file.name)));
end
for relative={'contracts/nonideal_r2_single_instance_codegen_adaptation.json','robust/single_instance_codegen/derivation.json'}
 target=fullfile(folder,relative{1});if ~isfolder(fileparts(target)),mkdir(fileparts(target));end
 copyfile(fullfile(base,relative{1}),target);record.contracts(end+1)=struct('path',relative{1},'sha256',teach_hash(fullfile(base,relative{1})));
end
probeFile=fullfile(base,'runs/N3R2_single_reference_logging_once/report.json');probe=jsondecode(fileread(probeFile));
assert(probe.all_passed&&probe.comparison.all_passed&&strcmp(probe.allowed_references,'Single')&&probe.actual_references==1);
record.single_instance_prerequisite=struct('report_sha256',teach_hash(probeFile),'probe_sha256',probe.probe_sha256,'contract_sha256',probe.contract_sha256);
copyfile(probeFile,fullfile(folder,'single_instance_prerequisite.json'));teach_writejson(fullfile(folder,'record.json'),record);
end
