function report=audit_sensorless_r2_port_geometry(folder)
% Inspect original-model port geometry in a disposable compile-only process.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);mdl='PMSM_FOC_R2026a';
for d={'','sensorless','sensorless/robust','sensorless/robust/integration','sensorless/robust/execution_v3','sensorless/robust/constructor','teaching','control','timing','deadtime','framework','layout/appearance'},addpath(fullfile(modern,d{1}));end
assert(~isfolder(folder)&&~bdIsLoaded(mdl));mkdir(folder);modelFile=fullfile(modern,[mdl '.slx']);
report=struct('kind','compile_only_port_geometry','all_passed',false,'phase','load','plant_stepped',false,'process_id',feature('getpid'),...
 'matlab_version',version,'model_sha256',teach_hash(modelFile));
contract=fullfile(base,'contracts/nonideal_r2_constructor_geometry_design.json');copyfile(contract,fullfile(folder,'contract.json'));report.contract_sha256=teach_hash(contract);
copyfile([mfilename('fullpath') '.m'],fullfile(folder,'audit_source.m.txt'));report.audit_sha256=teach_hash([mfilename('fullpath') '.m']);
cleanup=onCleanup(@()close_private(mdl));
try
 load_system(modelFile);pmsm_reference_geometry('restore');original=teach_snapshot(mdl);fixed=pmsm_reference('capture');originalInit=get_param(mdl,'InitFcn');
 backup=sensorless_v2_stimulus(mdl,struct('window_on',false,'interference_s',0,'adc_span_A',20));report.initialization=sensorless_r2_initialize_stopped(mdl);
 report.phase='compile_original_once';teach_writejson(fullfile(folder,'report.json'),report);feval(mdl,[],[],[],'compile');
 rows={'applied','输出延迟/记录_log_Tcm_applied';'current','采样设置/测量电流';'adc','采样设置/记录_log_iabc_adc'};
 for k=1:size(rows,1)
  sink=[mdl '/' rows{k,2}];ports=get_param(sink,'PortHandles');source=get_param(get_param(ports.Inport(1),'Line'),'SrcPortHandle');parent=get_param(source,'Parent');
  report.geometry.(rows{k,1})=struct('sink_relative',rows{k,2},'source_relative',extractAfter(parent,[mdl '/']),...
   'source_sid',Simulink.ID.getSID(parent),'source_port',get_param(source,'PortNumber'),...
   'compiled_dimensions',get_param(source,'CompiledPortDimensions'),'compiled_type',get_param(source,'CompiledPortDataType'));
 end
 feval(mdl,[],[],[],'term');assert(isequal(report.geometry.current.compiled_dimensions,report.geometry.adc.compiled_dimensions));
 set_param(mdl,'InitFcn',originalInit);sensorless_n3_restore(mdl,backup);
 report.restoration=isequaln(original,teach_snapshot(mdl))&&isequaln(fixed,pmsm_reference('capture'));assert(report.restoration);
 assert(strcmp(report.model_sha256,teach_hash(modelFile)));report.phase='completed';report.all_passed=true;
 teach_writejson(fullfile(folder,'report.json'),report);fprintf('PORT_GEOMETRY_COMPLETE\n');
catch err
 report.phase_at_error=report.phase;report.phase='diagnostic_error';report.error=getReport(err,'extended','hyperlinks','off');teach_writejson(fullfile(folder,'report.json'),report);
 try,feval(mdl,[],[],[],'term');catch,end,rethrow(err);
end
end
function close_private(mdl)
if bdIsLoaded(mdl),close_system(mdl,0);end
end
