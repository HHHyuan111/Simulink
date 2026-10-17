function record=sensorless_r2_v9_snapshot(folder)
% Source-bound diagnostic: existing mathematics plus one optimization setting.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));record=sensorless_r2_v8_snapshot(folder);record.execution_version='block_reduction_off_v9';
for f=dir(fullfile(here,'*.m'))'
 relative=['robust/execution_v9/' f.name];target=fullfile(folder,'source',relative);
 if ~isfolder(fileparts(target)),mkdir(fileparts(target));end
 copyfile(fullfile(f.folder,f.name),target);record.source_files(end+1)=struct('path',relative,'sha256',teach_hash(fullfile(f.folder,f.name)));
end
relative='contracts/nonideal_r2_block_reduction_diagnostic.json';copyfile(fullfile(base,relative),fullfile(folder,relative));record.contracts(end+1)=struct('path',relative,'sha256',teach_hash(fullfile(base,relative)));
teach_writejson(fullfile(folder,'record.json'),record);
end
