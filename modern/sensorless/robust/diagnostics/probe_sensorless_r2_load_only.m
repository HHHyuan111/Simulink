function report=probe_sensorless_r2_load_only(id,folder)
% Minimal read-only load: no project paths, observer, compile or simulation.
assert(ismember(id,{'original_path','identical_copy'}));assert(~isfolder(folder));mkdir(folder);
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);mdl='PMSM_FOC_R2026a';
source=fullfile(modern,[mdl '.slx']);assert(~bdIsLoaded(mdl));cleanup=onCleanup(@()close_private(mdl));
report=struct('kind','load_only_isolation','id',id,'phase','source_check','all_passed',false,...
 'process_id',matlabProcessID,'matlab_version',version,'load_starts',0,'simulation_starts',0,...
 'observer_constructed',false,'compile_requested',false,'model_saved',false,'native_retries',0,...
 'load_system_path',which('load_system'),'sim_path',which('sim'),'private_preferences',prefdir);
copyfile([mfilename('fullpath') '.m'],fullfile(folder,'probe_source.m.txt'));report.probe_sha256=hash([mfilename('fullpath') '.m']);
contract=fullfile(base,'contracts/nonideal_r2_load_only_probe.json');copyfile(contract,fullfile(folder,'contract.json'));report.contract_sha256=hash(contract);
report.source_sha256=hash(source);assert(strcmp(report.source_sha256,'a0f7cbae9e7c334c25aa9dcf6e7e88d65fd89bd1888a0fa2ec0cd04f6cce262d'));
target=source;
if strcmp(id,'identical_copy'),target=fullfile(folder,[mdl '.slx']);copyfile(source,target);assert(strcmp(hash(target),report.source_sha256));end
report.target=target;stage('before_load');
try
 report.load_starts=1;stage('load_once');load_system(target);stage('load_returned');
 report.status=get_param(mdl,'SimulationStatus');report.loaded_file=get_param(mdl,'FileName');
 report.blocks=numel(find_system(mdl,'LookUnderMasks','all','Type','Block'));
 ws=get_param(mdl,'ModelWorkspace');entries=whos(ws);report.workspace_names=sort({entries.name});
 report.source_unchanged=strcmp(hash(source),report.source_sha256);report.target_unchanged=strcmp(hash(target),report.source_sha256);
 report.intended_file_loaded=strcmpi(char(java.io.File(target).getCanonicalPath),char(java.io.File(report.loaded_file).getCanonicalPath));
 stage('close_without_save');close_system(mdl,0);report.closed=~bdIsLoaded(mdl);
 report.all_passed=strcmp(report.status,'stopped')&&report.intended_file_loaded&&report.source_unchanged&&report.target_unchanged&&report.blocks>0&&report.closed;
 stage('completed');
catch err
 report.phase_at_error=report.phase;report.phase='diagnostic_error';report.error=getReport(err,'extended','hyperlinks','off');write_report;rethrow(err);
end
 function stage(value),report.phase=value;write_report;fprintf('LOAD_ONLY_PHASE %s %s\n',id,value);end
 function write_report
  fid=fopen(fullfile(folder,'report.json'),'w','n','UTF-8');assert(fid>=0);guard=onCleanup(@()fclose(fid));fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
 end
end
function value=hash(path)
fid=fopen(path,'rb');assert(fid>=0);guard=onCleanup(@()fclose(fid));data=fread(fid,Inf,'*uint8');
digest=java.security.MessageDigest.getInstance('SHA-256');digest.update(data);
value=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
end
function close_private(mdl)
if bdIsLoaded(mdl),close_system(mdl,0);end
end
