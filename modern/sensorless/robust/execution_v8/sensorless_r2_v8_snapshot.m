function record=sensorless_r2_v8_snapshot(folder)
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));record=sensorless_r2_fault_snapshot(folder);record.execution_version='single_init_short_cache_v8r1';
for directory={'robust/execution_v8','robust/scenarios'}
 for f=dir(fullfile(base,directory{1},'*.m'))'
  relative=strrep(fullfile(directory{1},f.name),'\','/');target=fullfile(folder,'source',relative);
  if ~isfolder(fileparts(target)),mkdir(fileparts(target));end
  copyfile(fullfile(f.folder,f.name),target);record.source_files(end+1)=struct('path',relative,'sha256',teach_hash(fullfile(f.folder,f.name)));
 end
end
for relative={'contracts/nonideal_r2_single_initialization_design.json','contracts/nonideal_r2_v8_endpoint_addendum.json','contracts/nonideal_r2_v8_short_cache_addendum.json','contracts/nonideal_r2_basic_scenarios_design.json'}
 copyfile(fullfile(base,relative{1}),fullfile(folder,relative{1}));record.contracts(end+1)=struct('path',relative{1},'sha256',teach_hash(fullfile(base,relative{1})));
end
teach_writejson(fullfile(folder,'record.json'),record);
end
