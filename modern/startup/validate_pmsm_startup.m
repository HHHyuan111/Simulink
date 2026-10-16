function result=validate_pmsm_startup(folder,repeatedFolder)
% Strict independent-process replay; original samples are never modified.
here=fileparts(mfilename('fullpath'));root=fileparts(here);addpath(fullfile(root,'teaching'));
r=verify(folder,root);assert(r.enabled&&~r.window_on);
if nargin<2
 receipt=fullfile(root,'.build',['startup_repeat_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS')) '.json']);
 command=sprintf('addpath(''%s'');r=run_pmsm_startup(%s);addpath(''%s'');teach_writejson(''%s'',r);',...
  strrep(here,'''',''''''),mat2str(r.times_ms),strrep(fullfile(root,'teaching'),'''',''''''),strrep(receipt,'''',''''''));
 [status,log]=system(sprintf('"%s" -batch "%s"',fullfile(matlabroot,'bin','matlab.exe'),command));fprintf('%s',log);assert(status==0);
 x=jsondecode(fileread(receipt));repeatedFolder=x.folder;
end
again=verify(repeatedFolder,root);assert(isequal(r.times_ms,again.times_ms)&&again.enabled&&~again.window_on);
a=load(fullfile(folder,'signals.mat'),'signals');b=load(fullfile(repeatedFolder,'signals.mat'),'signals');
names=fieldnames(a.signals);assert(isequal(names,fieldnames(b.signals)));
for n=names'
 x=a.signals.(n{1});y=b.signals.(n{1});assert(isequal(x.Time,y.Time)&&isequal(x.Data,y.Data),'Strict repeat failed: %s',n{1});
end
analysis=analyse_pmsm_startup(a.signals,r);repeatAnalysis=analyse_pmsm_startup(b.signals,again);assert(isequaln(analysis,repeatAnalysis));
result=struct('passed',true,'kind',r.kind,'original_folder',folder,'repeated_folder',repeatedFolder,...
 'signal_count',numel(names),'all_time_data_exact',true,'analysis',analysis,'model_sha256',r.model_sha256,...
 'structure_and_reference_restored',r.structure_preserved&&r.reference_restored&&again.structure_preserved&&again.reference_restored);
teach_writejson(fullfile(here,'startup_validation.json'),result);fprintf('STARTUP_VALIDATED %d exact signals\n',numel(names));
end
function r=verify(folder,root)
r=jsondecode(fileread(fullfile(folder,'record.json')));assert(strcmp(r.kind,'minimum_startup_v1')&&strcmp(r.status,'completed'));
assert(strcmp(r.model_sha256,teach_hash(fullfile(root,'PMSM_FOC_R2026a.slx'))));
assert(strcmp(r.signals_sha256,teach_hash(fullfile(folder,'signals.mat'))));
for f=r.source_files(:)',assert(strcmp(f.sha256,teach_hash(fullfile(root,f.path))),'Source changed: %s',f.path);end
end
