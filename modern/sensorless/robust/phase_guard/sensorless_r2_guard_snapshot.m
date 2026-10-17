function record=sensorless_r2_guard_snapshot(folder)
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));record=sensorless_r2_v3_snapshot(folder);record.execution_version='packet_phase_guard_v4';
for directory={'robust/phase_guard','robust/phase_guard/blocks'}
 for f=dir(fullfile(base,directory{1},'*.m'))'
  relative=strrep(fullfile(directory{1},f.name),'\','/');target=fullfile(folder,'source',relative);
  if ~isfolder(fileparts(target)),mkdir(fileparts(target));end
  copyfile(fullfile(f.folder,f.name),target);record.source_files(end+1)=struct('path',relative,'sha256',teach_hash(fullfile(f.folder,f.name)));
 end
end
relative='contracts/nonideal_r2_phase_guard_design.json';copyfile(fullfile(base,relative),fullfile(folder,relative));
record.contracts(end+1)=struct('path',relative,'sha256',teach_hash(fullfile(base,relative)));
teach_writejson(fullfile(folder,'record.json'),record);
end
