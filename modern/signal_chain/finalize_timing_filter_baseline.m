function report=finalize_timing_filter_baseline(folder)
% Seal completed raw runs after the original worker's final restore assertion failed.
% Never modify raw MAT data or an already sealed record.
root=fileparts(fileparts(mfilename('fullpath')));here=fullfile(root,'teaching');addpath(root,here);
assert(~isfile(fullfile(folder,'record.json')));m='PMSM_FOC_R2026a';assert(~bdIsLoaded(m));load_system(fullfile(root,[m '.slx']));guard=onCleanup(@()close_system(m,0));pmsm_reference('restore');
latest=jsondecode(fileread(fullfile(root,'signal_chain','timing_feedback_latest.json')));old=pmsm_experiment_verify(latest.folder);assert(strcmp(latest.record_sha256,teach_hash(fullfile(latest.folder,'record.json'))));
plan=jsondecode(fileread(fullfile(latest.folder,'plan.json')));assert(old.duration_s==.2&&isequal(old.factor_value(:)',[5 10.5 15]));
report=struct('passed',true,'folder',folder,'duration_s',.2,'filter_hz',1500,'model_sha256',teach_hash(fullfile(root,[m '.slx'])),...
 'reference_manifest_sha256',teach_hash(fullfile(here,'reference_v1','manifest.json')),'unfiltered_folder',latest.folder,'unfiltered_record_sha256',latest.record_sha256,...
 'statistics_window_s',[.18 .2],'case_order',{{'fast_off','slow_off','fast_filter','slow_filter'}},'cases',struct([]),'files',struct('path',{},'sha256',{}));
for k=1:2
 index=[1 3];p=plan.cases(index(k));name=sprintf('filtered_%d.mat',k);s=load(fullfile(folder,name),'signals');assert(isequal(sort(fieldnames(s.signals)),sort(old.cases(index(k)).retained_signals)));
 for field=fieldnames(s.signals)',v=s.signals.(field{1});assert(isa(v,'timeseries')&&all(isfinite(v.Data),'all')&&max(v.Time)>.199);end
 c=p.configuration;for setting={'filter_on','on';'filter_hz','1500'}',i=find(strcmp({c.rows.section},'采样设置')&strcmp({c.rows.key},setting{1}));assert(isscalar(i));c.rows(i).value=setting{2};end
 row=struct('compute_us',old.factor_value(index(k)),'configuration',c,'file',name);if k==1,report.cases=row;else,report.cases(k)=row;end
 report.files(end+1)=struct('path',name,'sha256',teach_hash(fullfile(folder,name)));
end
report.numerical_source_file='runtime.m';report.numerical_source_sha256=teach_hash(fullfile(folder,'runtime.m'));report.files(end+1)=struct('path','runtime.m','sha256',report.numerical_source_sha256);
report.finalization_note='Both complete 200ms MAT files were saved before the initial worker failed its post-simulation workspace assertion. That worker exited without saving SLX. This separate finalizer checks file completeness and seals them without rewriting data; independent prefix and equation validation is recorded separately. The reusable runner now restores the reference explicitly.';
report.finalization_source_sha256=teach_hash([mfilename('fullpath') '.m']);
assert(strcmp(old.model_sha256,report.model_sha256));teach_writejson(fullfile(folder,'record.json'),report);
teach_writejson(fullfile(root,'signal_chain','timing_filter','latest.json'),struct('passed',true,'folder',folder,'record_sha256',teach_hash(fullfile(folder,'record.json'))));disp('TIMING_FILTER_DATA_SEALED');
end
