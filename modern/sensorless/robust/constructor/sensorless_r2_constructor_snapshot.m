function record=sensorless_r2_constructor_snapshot(folder)
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));record=sensorless_r2_v8_snapshot(folder);record.execution_version='geometry_bound_constructor';
for f=dir(fullfile(here,'*.m'))'
 relative=['robust/constructor/' f.name];target=fullfile(folder,'source',relative);if ~isfolder(fileparts(target)),mkdir(fileparts(target));end
 copyfile(fullfile(f.folder,f.name),target);record.source_files(end+1)=struct('path',relative,'sha256',teach_hash(fullfile(f.folder,f.name)));
end
for relative={'contracts/nonideal_r2_constructor_geometry_design.json','contracts/nonideal_r2_constructor_reference_addendum.json','contracts/nonideal_r2_port_geometry.json'}
 copyfile(fullfile(base,relative{1}),fullfile(folder,relative{1}));record.contracts(end+1)=struct('path',relative{1},'sha256',teach_hash(fullfile(base,relative{1})));
end
manifest=sensorless_r2_verify_constructor;copyfile(fullfile(here,'derivation.json'),fullfile(folder,'constructor_derivation.json'));record.constructor=manifest;
record.constructor.geometry_report_sha256=teach_hash(fullfile(base,'contracts/nonideal_r2_port_geometry.json'));
record.constructor.reference_restore_no_update=true;
for k=1:numel(manifest.files),copyfile(fullfile(base,manifest.files(k).original),fullfile(folder,['constructor_original_' num2str(k) '.m.txt']));end
teach_writejson(fullfile(folder,'record.json'),record);
end
