function record=sensorless_r2_literal_snapshot(folder)
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));record=sensorless_r2_scenario_snapshot(folder);record.execution_version='literal_binding_v6';
for f=dir(fullfile(here,'*.m'))'
 relative=['robust/literal_plant/' f.name];target=fullfile(folder,'source',relative);if ~isfolder(fileparts(target)),mkdir(fileparts(target));end
 copyfile(fullfile(f.folder,f.name),target);record.source_files(end+1)=struct('path',relative,'sha256',teach_hash(fullfile(f.folder,f.name)));
end
relative='contracts/nonideal_r2_plant_literal_addendum.json';copyfile(fullfile(base,relative),fullfile(folder,relative));record.contracts(end+1)=struct('path',relative,'sha256',teach_hash(fullfile(base,relative)));
teach_writejson(fullfile(folder,'record.json'),record);
end
