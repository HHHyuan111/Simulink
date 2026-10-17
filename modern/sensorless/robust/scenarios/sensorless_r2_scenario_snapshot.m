function record=sensorless_r2_scenario_snapshot(folder)
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));record=sensorless_r2_guard_snapshot(folder);record.execution_version='basic_scenarios_v5';
for f=dir(fullfile(here,'*.m'))'
 relative=['robust/scenarios/' f.name];target=fullfile(folder,'source',relative);
 if ~isfolder(fileparts(target)),mkdir(fileparts(target));end
 copyfile(fullfile(f.folder,f.name),target);record.source_files(end+1)=struct('path',relative,'sha256',teach_hash(fullfile(f.folder,f.name)));
end
for name={'contracts/nonideal_r2_plant_adapter_design.json','contracts/nonideal_r2_basic_scenarios_design.json'}
 copyfile(fullfile(base,name{1}),fullfile(folder,name{1}));record.contracts(end+1)=struct('path',name{1},'sha256',teach_hash(fullfile(base,name{1})));
end
teach_writejson(fullfile(folder,'record.json'),record);
end
