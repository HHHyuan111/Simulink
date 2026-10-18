function record=sensorless_r2_staged_snapshot(folder)
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));record=sensorless_r2_reference_snapshot(folder);record.execution_version='portable_staged_execution';
for directory={'robust/portable_model','robust/generated_backend','robust/portable_execution'}
 for file=dir(fullfile(base,directory{1},'*.m'))'
  relative=strrep(fullfile(directory{1},file.name),'\','/');target=fullfile(folder,'source',relative);if ~isfolder(fileparts(target)),mkdir(fileparts(target));end
  copyfile(fullfile(file.folder,file.name),target);record.source_files(end+1)=struct('path',relative,'sha256',teach_hash(fullfile(file.folder,file.name)));
 end
end
for relative={'contracts/nonideal_r2_portable_model_design.json','contracts/nonideal_r2_workspace_persistence_probe.json','contracts/nonideal_r2_portable_execution_design.json'}
 copyfile(fullfile(base,relative{1}),fullfile(folder,relative{1}));record.contracts(end+1)=struct('path',relative{1},'sha256',teach_hash(fullfile(base,relative{1})));
end
persistence=jsondecode(fileread(fullfile(base,'runs/N3R2_workspace_persistence_once/report.json')));assert(persistence.all_passed);
probe=jsondecode(fileread(fullfile(base,'runs/N3R2_rapid_process_once/report.json')));assert(probe.all_passed&&probe.rapid_pid_is_distinct);
record.backend_prerequisites=struct('process_probe_sha256',teach_hash(fullfile(base,'runs/N3R2_rapid_process_once/report.json')),...
 'dependency_sha256',teach_hash(fullfile(base,'milestones/N3R2/isolated_compiler_20261018.json')),'actual_process_boundary_separately_measured',true);
copyfile(fullfile(base,'runs/N3R2_rapid_process_once/report.json'),fullfile(folder,'process_probe_prerequisite.json'));
copyfile(fullfile(base,'milestones/N3R2/isolated_compiler_20261018.json'),fullfile(folder,'compiler_dependency.json'));
teach_writejson(fullfile(folder,'record.json'),record);
end
