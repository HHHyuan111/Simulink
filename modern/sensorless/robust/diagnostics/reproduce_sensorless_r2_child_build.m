function report=reproduce_sensorless_r2_child_build(folder)
% Build-only standalone reproduction: no parent loading and no sim call.
package=fileparts(mfilename('fullpath'));manifest=jsondecode(fileread(fullfile(package,'manifest.json')));
assert(~isfolder(folder));mkdir(folder);child=manifest.child_model;parent='PMSM_FOC_R2026a';
assert(~bdIsLoaded(parent)&&~bdIsLoaded(child));cleanup=onCleanup(@()close_child(child));
report=struct('kind','standalone_child_only_build','phase','verify_package','all_passed',false,'process_id',matlabProcessID,...
 'matlab_version',version,'simulation_starts',0,'target_builds',0,'parent_ever_loaded',false,'R2_passed',false);
report.manifest_sha256=hash(fullfile(package,'manifest.json'));
try
 for file=manifest.files(:)',assert(strcmp(file.sha256,hash(fullfile(package,file.path))),'Package file changed: %s',file.path);end
 addpath(genpath(fullfile(package,'source')));model=fullfile(package,manifest.model_file);
 stage('load_child_only');load_system(model);set_param(0,'CurrentSystem',child);assert(~bdIsLoaded(parent));
 assert(strcmp(get_param(child,'FileName'),model));ws=get_param(child,'ModelWorkspace');entries=whos(ws);
 report.workspace_count=numel(entries);assert(report.workspace_count==86&&strcmp(ws.DataSource,'Model File'));
 observer=getVariable(ws,'sless_cfg');frontend=getVariable(ws,'sless_v2_cfg');
 report.configuration_exact=isequal(observer,manifest.observer_config)&&isequal(frontend,manifest.frontend_config);
 % JSON vectors are columns; retain actual stored orientation and compare their values.
 report.configuration_values_exact=isequal(observer(:),manifest.observer_config(:))&&isequal(frontend(:),manifest.frontend_config(:));
 assert(report.configuration_values_exact);assert(strcmp(get_param(child,'ModelReferenceNumInstancesAllowed'),'Single'));
 assert(isempty(get_param(child,'InitFcn'))&&isempty(get_param(child,'PreSaveFcn'))&&isempty(get_param(child,'StopFcn')));
 assert(isempty(find_system(child,'BlockType','ModelReference')));
 ports=find_system(child,'SearchDepth',1,'BlockType','Inport');assert(numel(ports)==9&&isempty(find_system(child,'SearchDepth',1,'BlockType','Outport')));
 for k=1:numel(ports),assert(strcmp(get_param(ports{k},'OutDataTypeStr'),'double'));end
 generation=fullfile(folder,'generation');Simulink.fileGenControl('set','CacheFolder',fullfile(generation,'c'),'CodeGenFolder',fullfile(generation,'g'),'createDir',true);
 report.target_builds=1;stage('build_child_target_once');slbuild(child,'ModelReferenceSimTarget');
 files=dir(fullfile(generation,'**','*.mexw64'));assert(~isempty(files));report.generated_targets=struct('path',{},'sha256',{});
 for k=1:numel(files),file=fullfile(files(k).folder,files(k).name);report.generated_targets(end+1)=struct('path',file,'sha256',hash(file));end %#ok<AGROW>
 report.source_model_unchanged=strcmp(hash(model),manifest.model_sha256);assert(report.source_model_unchanged&&~bdIsLoaded(parent));
 report.all_passed=true;stage('completed');
catch err
 report.phase_at_error=report.phase;report.phase='failed';report.error_identifier=err.identifier;stage('failed');rethrow(err);
end
 function stage(label)
  report.phase=label;fid=fopen(fullfile(folder,'report.json'),'w','n','UTF-8');assert(fid>=0);fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
  fprintf('CHILD_ONLY_BUILD %s\n',label);
 end
end
function digest=hash(file)
fid=fopen(file,'r');assert(fid>=0);bytes=fread(fid,inf,'*uint8');fclose(fid);md=java.security.MessageDigest.getInstance('SHA-256');md.update(bytes);digest=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
end
function close_child(child)
if bdIsLoaded(child),close_system(child,0);end
end
