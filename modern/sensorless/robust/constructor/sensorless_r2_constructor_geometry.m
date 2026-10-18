function geometry=sensorless_r2_constructor_geometry(mdl)
% Use separately audited original ports; never compile while installing.
base=fileparts(fileparts(fileparts(mfilename('fullpath'))));
report=jsondecode(fileread(fullfile(base,'contracts/nonideal_r2_port_geometry.json')));
assert(report.all_passed&&report.restoration&&~report.plant_stepped);
assert(strcmp(get_param(mdl,'SimulationStatus'),'stopped'));
assert(strcmp(teach_hash(get_param(mdl,'FileName')),report.model_sha256),'Original model differs from audited geometry.');
geometry=report.geometry;names=fieldnames(geometry);
for k=1:numel(names)
 entry=geometry.(names{k});sink=[mdl '/' entry.sink_relative];ports=get_param(sink,'PortHandles');
 source=get_param(get_param(ports.Inport(1),'Line'),'SrcPortHandle');parent=get_param(source,'Parent');
 assert(strcmp(parent,[mdl '/' entry.source_relative])&&strcmp(Simulink.ID.getSID(parent),entry.source_sid)&&...
  get_param(source,'PortNumber')==entry.source_port,'Source identity differs from audited geometry.');
 dimensions=reshape(entry.compiled_dimensions,1,[]);assert(dimensions(1)==numel(dimensions)-1&&strcmp(entry.compiled_type,'double'));
 geometry.(names{k}).compiled_dimensions=dimensions;
end
assert(isequal(geometry.current.compiled_dimensions,geometry.adc.compiled_dimensions));
end
