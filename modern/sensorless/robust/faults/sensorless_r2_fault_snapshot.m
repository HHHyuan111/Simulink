function record=sensorless_r2_fault_snapshot(folder)
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));record=sensorless_r2_guard_snapshot(folder);record.execution_version='fault_ingress_schedule_v7';
for directory={'robust/faults','robust/faults/blocks'}
 for f=dir(fullfile(base,directory{1},'*.m'))'
  relative=strrep(fullfile(directory{1},f.name),'\','/');target=fullfile(folder,'source',relative);
  if ~isfolder(fileparts(target)),mkdir(fileparts(target));end
  copyfile(fullfile(f.folder,f.name),target);record.source_files(end+1)=struct('path',relative,'sha256',teach_hash(fullfile(f.folder,f.name)));
 end
end
relative='contracts/nonideal_r2_fault_adapter_design.json';copyfile(fullfile(base,relative),fullfile(folder,relative));
record.contracts(end+1)=struct('path',relative,'sha256',teach_hash(fullfile(base,relative)));teach_writejson(fullfile(folder,'record.json'),record);
end
