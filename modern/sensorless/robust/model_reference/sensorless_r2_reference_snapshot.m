function record=sensorless_r2_reference_snapshot(folder)
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));record=sensorless_r2_constructor_snapshot(folder);record.execution_version='normal_model_reference_adapter';
for directory={'robust/model_reference','robust/literal_plant'}
 for file=dir(fullfile(base,directory{1},'*.m'))'
  relative=strrep(fullfile(directory{1},file.name),'\','/');target=fullfile(folder,'source',relative);if ~isfolder(fileparts(target)),mkdir(fileparts(target));end
  copyfile(fullfile(file.folder,file.name),target);record.source_files(end+1)=struct('path',relative,'sha256',teach_hash(fullfile(file.folder,file.name)));
 end
end
for relative={'contracts/nonideal_r2_model_reference_design.json','contracts/nonideal_r2_model_reference_toy.json'}
 copyfile(fullfile(base,relative{1}),fullfile(folder,relative{1}));record.contracts(end+1)=struct('path',relative{1},'sha256',teach_hash(fullfile(base,relative{1})));
end
teach_writejson(fullfile(folder,'record.json'),record);
end
