function record=sensorless_r2_snapshot_sources(folder)
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));
record=sensorless_v2_snapshot_sources(folder);record.node='N3R2';
for directory={'robust/performance','robust/performance/blocks'}
 for f=dir(fullfile(base,directory{1},'*.m'))'
  relative=strrep(fullfile(directory{1},f.name),'\','/');target=fullfile(folder,'source',relative);
  if ~isfolder(fileparts(target)),mkdir(fileparts(target));end
  copyfile(fullfile(f.folder,f.name),target);
  record.source_files(end+1)=struct('path',relative,'sha256',teach_hash(fullfile(f.folder,f.name))); %#ok<AGROW>
 end
end
name='contracts/nonideal_r2_test_plan.json';copyfile(fullfile(base,name),fullfile(folder,name));
record.contracts(end+1)=struct('path',name,'sha256',teach_hash(fullfile(base,name)));
teach_writejson(fullfile(folder,'record.json'),record);
end
