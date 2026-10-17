function record=sensorless_r2_v3_snapshot(folder)
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));
record=sensorless_r2_snapshot_sources(folder);record.execution_version='stopped_init_v3';
for f=dir(fullfile(here,'*.m'))'
 relative=['robust/execution_v3/' f.name];target=fullfile(folder,'source',relative);
 if ~isfolder(fileparts(target)),mkdir(fileparts(target));end
 copyfile(fullfile(f.folder,f.name),target);
 record.source_files(end+1)=struct('path',relative,'sha256',teach_hash(fullfile(f.folder,f.name)));
end
teach_writejson(fullfile(folder,'record.json'),record);
end
