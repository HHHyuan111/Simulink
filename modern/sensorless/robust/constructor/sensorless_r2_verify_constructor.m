function manifest=sensorless_r2_verify_constructor
% Reject any change beyond the registered, separately checked derivation.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));manifest=jsondecode(fileread(fullfile(here,'derivation.json')));
assert(manifest.explicit_preinstall_compile_removed&&~manifest.algorithm_equations_changed);
for k=1:numel(manifest.files)
 f=manifest.files(k);assert(strcmp(teach_hash(fullfile(base,f.original)),f.original_sha256));
 assert(strcmp(teach_hash(fullfile(here,f.generated)),f.generated_sha256));
end
geometry=jsondecode(fileread(fullfile(base,'contracts/nonideal_r2_port_geometry.json')));assert(geometry.all_passed&&geometry.restoration&&~geometry.plant_stepped);
end
