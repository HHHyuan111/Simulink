function report=verify_saved_speed_loop_stage1
% Check a freshly reloaded model and its embedded parameter source.
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);mdl='PMSM_FOC_R2026a';
source=fullfile(root,[mdl '.slx']);record=jsondecode(fileread(fullfile(folder,'speed_loop_stage1_results.json')));
assert(strcmp(filehash(source),record.after_sha256),'Saved model differs from the tested model.');
load_system(source);cleanup=onCleanup(@()close_system(mdl,0));
mw=get_param(mdl,'ModelWorkspace');assert(strcmp(mw.DataSource,'MATLAB Code'));
assert(strcmp(get_param(mdl,'SignalLogging'),'on'));
keys=fieldnames(record.after_parameters);
for k=1:numel(keys)
 assert(isequaln(getVariable(mw,keys{k}),record.after_parameters.(keys{k})), ...
  'Reloaded parameter differs: %s',keys{k});
end
assert(numel(find_system(mdl,'SearchDepth',1,'Type','Block'))==164);
assert(numel(find_system(mdl,'LookUnderMasks','all','FollowLinks','off','Type','Block'))==329);
assert(strcmp(get_param(Simulink.ID.getHandle([mdl ':216']),'Value'),'Ld-Lq'));
set_param(mdl,'SimulationCommand','update');
unresolved=find_system(mdl,'LookUnderMasks','all','FollowLinks','off','LinkStatus','unresolved');
assert(isempty(unresolved));
feval(mdl,[],[],[],'compile');
try
 ids={'190','164','438'};periods=zeros(1,3);
 for k=1:3
  st=get_param(Simulink.ID.getHandle([mdl ':' ids{k}]),'CompiledSampleTime');
  if iscell(st),st=vertcat(st{:});end
  rate=unique(st(isfinite(st(:,1))&st(:,1)>0,1));assert(isscalar(rate));periods(k)=rate;
 end
 assert(all(abs(periods-record.after_parameters.Ts_speed)<1e-12));
catch err
 feval(mdl,[],[],[],'term');rethrow(err);
end
feval(mdl,[],[],[],'term');
report=struct('matlab',version,'model_sha256',filehash(source), ...
 'embedded_parameters_reloaded_correctly',true,'compiled_periods_s',periods, ...
 'top_blocks',164,'total_blocks',329,'unresolved_links',0,'passed',true);
fid=fopen(fullfile(folder,'speed_loop_stage1_reload_check.json'),'w','n','UTF-8');
fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));fclose(fid);
fprintf('SAVED_SPEED_STAGE1_RELOAD_PASSED\n');
end
function result=filehash(path)
fid=fopen(path,'rb');data=fread(fid,Inf,'*uint8');fclose(fid);
md=java.security.MessageDigest.getInstance('SHA-256');md.update(data);
result=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
end
