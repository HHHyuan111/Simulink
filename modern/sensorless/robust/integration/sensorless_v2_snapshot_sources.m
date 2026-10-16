function record=sensorless_v2_snapshot_sources(folder)
% Capture complete executable sensorless sources, excluding archived runs.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);
assert(~isfolder(folder),'Refuse to overwrite an attempt.');mkdir(folder);
record=struct('schema',1,'node','N3R1','folder',folder,'status','running','phase','snapshot',...
 'matlab_version',version,'process_id',feature('getpid'),'model_sha256',teach_hash(fullfile(modern,'PMSM_FOC_R2026a.slx')),...
 'source_files',struct('path',{},'sha256',{}),'contracts',struct('path',{},'sha256',{}));
for directory={'','blocks','robust','robust/integration','robust/integration/blocks'}
 for f=dir(fullfile(base,directory{1},'*.m'))'
  relative=strrep(fullfile(directory{1},f.name),'\','/');target=fullfile(folder,'source',relative);
  if ~isfolder(fileparts(target)),mkdir(fileparts(target));end
  copyfile(fullfile(f.folder,f.name),target);
  record.source_files(end+1)=struct('path',relative,'sha256',teach_hash(fullfile(f.folder,f.name))); %#ok<AGROW>
 end
end
for name={'contracts/nonideal_v2.json','contracts/nonideal_r1_test_plan.json','contracts/nonideal_r1_window_addendum.json',...
 'contracts/acceptance_v1.json','contracts/test_plan_v1.json','contracts/parameters_v1.json','contracts/signals_v1.json',...
 'baseline/n0_inventory.json','baseline/log_schema.json'}
 record.contracts(end+1)=struct('path',name{1},'sha256',teach_hash(fullfile(base,name{1})));
 target=fullfile(folder,name{1});if ~isfolder(fileparts(target)),mkdir(fileparts(target));end
 copyfile(fullfile(base,name{1}),target);
end
teach_writejson(fullfile(folder,'record.json'),record);
end
