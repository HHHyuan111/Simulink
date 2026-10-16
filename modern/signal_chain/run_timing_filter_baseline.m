function report=run_timing_filter_baseline
root=fileparts(fileparts(mfilename('fullpath')));here=fullfile(root,'teaching');addpath(root,here);
m='PMSM_FOC_R2026a';assert(~bdIsLoaded(m));load_system(fullfile(root,[m '.slx']));guard=onCleanup(@()close_system(m,0));pmsm_reference('restore');
original=pmsm_reference('capture');latest=jsondecode(fileread(fullfile(root,'signal_chain','timing_feedback_latest.json')));
old=pmsm_experiment_verify(latest.folder);assert(strcmp(latest.record_sha256,teach_hash(fullfile(latest.folder,'record.json'))));
assert(old.duration_s==.2&&isequal(old.factor_value(:)',[5 10.5 15]));
plan=jsondecode(fileread(fullfile(latest.folder,'plan.json')));
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));folder=fullfile(root,'signal_chain','timing_filter','runs',stamp);assert(~isfolder(folder));mkdir(folder);copyfile([mfilename('fullpath') '.m'],fullfile(folder,'runtime.m'));
report=struct('passed',false,'folder',folder,'duration_s',.2,'filter_hz',1500,'model_sha256',teach_hash(fullfile(root,[m '.slx'])),...
 'reference_manifest_sha256',teach_hash(fullfile(here,'reference_v1','manifest.json')),'unfiltered_folder',latest.folder,'unfiltered_record_sha256',latest.record_sha256,...
 'statistics_window_s',[.18 .2],'case_order',{{'fast_off','slow_off','fast_filter','slow_filter'}},'cases',struct([]),'files',struct('path',{},'sha256',{}));
for k=1:2
 sourceIndex=[1 3];p=plan.cases(sourceIndex(k));in=Simulink.SimulationInput(m);in=in.setModelParameter('StopTime','.2');
 for change=p.changes(:)',in=in.setBlockParameter([m '/' change.section],change.parameter,change.value);end
 in=in.setBlockParameter([m '/采样设置'],'filter_on','on');in=in.setBlockParameter([m '/采样设置'],'filter_hz','1500');
 for change=plan.logging_overrides(:)'
  blocks=find_system(m,'LookUnderMasks','all','FollowLinks','off','BlockType','ToWorkspace','VariableName',change.signal);assert(isscalar(blocks));
  in=in.setBlockParameter(blocks{1},change.parameter,change.value);
 end
 fprintf('TIMING_FILTER_COMBINED compute=%g us\n',old.factor_value(sourceIndex(k)));o=sim(in);signals=struct;
 for name=old.cases(sourceIndex(k)).retained_signals(:)'
  s=o.get(name{1});assert(isa(s,'timeseries')&&all(isfinite(s.Data),'all'));signals.(name{1})=s;
 end
 clear o;name=sprintf('filtered_%d.mat',k);save(fullfile(folder,name),'signals','-v7.3');clear signals;
 config=p.configuration;config=setcfg(config,'采样设置','filter_on','on');config=setcfg(config,'采样设置','filter_hz','1500');
 row=struct('compute_us',old.factor_value(sourceIndex(k)),'configuration',config,'file',name);
 if k==1,report.cases=row;else,report.cases(k)=row;end
 report.files(end+1)=struct('path',name,'sha256',teach_hash(fullfile(folder,name)));
end
pmsm_reference('restore');assert(isequaln(original,pmsm_reference('capture'))&&strcmp(report.model_sha256,teach_hash(fullfile(root,[m '.slx']))));
report.passed=true;report.numerical_source_sha256=teach_hash(fullfile(folder,'runtime.m'));report.numerical_source_file='runtime.m';
report.files(end+1)=struct('path','runtime.m','sha256',report.numerical_source_sha256);
teach_writejson(fullfile(folder,'record.json'),report);
teach_writejson(fullfile(root,'signal_chain','timing_filter','latest.json'),struct('passed',true,'folder',folder,'record_sha256',teach_hash(fullfile(folder,'record.json'))));
disp('TIMING_FILTER_RUN_COMPLETE');
end
function c=setcfg(c,section,key,value)
i=find(strcmp({c.rows.section},section)&strcmp({c.rows.key},key));assert(isscalar(i));c.rows(i).value=value;
end
