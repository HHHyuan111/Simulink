function folder=verify_sensorless_n2_archives(earlierFolder,laterFolder)
% Reanalyse two completed, independent-process data sets without rerunning sim.
% The earlier process failed ONLY while appending the analysis report struct.
here=fileparts(mfilename('fullpath'));addpath(here,fullfile(fileparts(here),'teaching'));
a=jsondecode(fileread(fullfile(earlierFolder,'record.json')));
b=jsondecode(fileread(fullfile(laterFolder,'record.json')));
assert(strcmp(a.status,'failed')&&strcmp(b.status,'passed')&&b.all_passed);
assert(numel(a.cases)==5&&numel(b.cases)==5&&all([a.cases.restored])&&all([b.cases.restored]));
assert(strcmp(a.matlab_version,b.matlab_version)&&strcmp(b.matlab_version,version));
assert(strcmp(a.model_sha256,b.model_sha256)&&strcmp(a.plan_sha256,b.plan_sha256));
for r={a,b}
 sourceFolder=r{1}.folder;
 for f=r{1}.source_files(:)'
  assert(strcmp(f.sha256,teach_hash(fullfile(sourceFolder,'source',f.path))));
 end
end
for f=b.source_files(:)'
 assert(strcmp(f.sha256,teach_hash(fullfile(here,f.path))),'Current source changed: %s',f.path);
end
changed={};
for f=a.source_files(:)'
 index=find(strcmp({b.source_files.path},f.path));assert(isscalar(index));
 if ~strcmp(f.sha256,b.source_files(index).sha256),changed{end+1}=f.path;end %#ok<AGROW>
end
assert(isequal(changed,{'analyse_sensorless_n2.m'}));
added=setdiff({b.source_files.path},{a.source_files.path});assert(isequal(added,{'archive_sensorless_n2.m'}));
old=strrep(fileread(fullfile(earlierFolder,'source','analyse_sensorless_n2.m')),sprintf('\r\n'),sprintf('\n'));
new=strrep(fileread(fullfile(laterFolder,'source','analyse_sensorless_n2.m')),sprintf('\r\n'),sprintf('\n'));
assert(strcmp(strrep(old,'report.integration(end+1)=row;',...
 'if isempty(report.integration),report.integration=row;else,report.integration(end+1)=row;end'),new),...
 'The only allowed analysis change is initialization of the report struct.');
folder=fullfile(here,'runs',['N2_archive_verification_' char(datetime('now','Format','yyyyMMdd_HHmmss')) '_' char(java.util.UUID.randomUUID)]);
mkdir(folder);
first=analyse_sensorless_n2(earlierFolder);second=analyse_sensorless_n2(laterFolder);
assert(first.all_passed&&second.all_passed&&isequaln(first,second));
teach_writejson(fullfile(folder,'earlier_reanalysis.json'),first);
teach_writejson(fullfile(folder,'later_reanalysis.json'),second);
rows=struct('case_id',{},'logs',{},'numeric_elements',{},'identical',{},'failures',{});
for k=1:5
 x=a.cases(k);y=b.cases(k);assert(strcmp(x.id,y.id));
 assert(strcmp(x.sha256,teach_hash(fullfile(earlierFolder,x.file))));
 assert(strcmp(y.sha256,teach_hash(fullfile(laterFolder,y.file))));
 firstData=load(fullfile(earlierFolder,x.file),'signals');secondData=load(fullfile(laterFolder,y.file),'signals');
 names=fieldnames(firstData.signals);assert(isequal(names,fieldnames(secondData.signals)));
 count=0;failures={};
 for j=1:numel(names)
  name=names{j};p=firstData.signals.(name);q=secondData.signals.(name);
  assert(all(isfinite(p.Time),'all')&&all(isfinite(p.Data),'all')&&all(isfinite(q.Time),'all')&&all(isfinite(q.Data),'all'));
  count=count+numel(p.Time)+numel(p.Data);
  if ~isequaln(p.Time,q.Time)||~isequaln(p.Data,q.Data),failures{end+1}=name;end %#ok<AGROW>
 end
 rows(k)=struct('case_id',x.id,'logs',numel(names),'numeric_elements',count,...
  'identical',isempty(failures),'failures',{failures});
end
result=struct('schema',1,'node','N2','original_folder',earlierFolder,'replay_folder',laterFolder,...
 'comparison_folder',folder,'matlab_version',version,...
 'process_policy','two separate complete five-case MATLAB batch simulations; archived data compared in a third process',...
 'earlier_run_original_status',a.status,'earlier_error',a.error,...
 'original_failure_record_preserved',true,'production_sources_identical',true,...
 'only_common_source_change',changed{1},'analysis_change','initialize empty report struct before append; no numerical comparison changed',...
 'added_nonexecuted_package_helper',added{1},'driver_sha256',teach_hash([mfilename('fullpath') '.m']),...
 'cases',rows,'analysis_identical',isequaln(first,second),'all_passed',all([rows.identical])&&isequaln(first,second));
teach_writejson(fullfile(folder,'replay_validation.json'),result);
record=struct('schema',1,'node','N2','kind','verification of preserved cross-process archives',...
 'status','passed','all_passed',result.all_passed,'source_records',{{fullfile(earlierFolder,'record.json'),fullfile(laterFolder,'record.json')}},...
 'source_record_sha256',{{teach_hash(fullfile(earlierFolder,'record.json')),teach_hash(fullfile(laterFolder,'record.json'))}},...
 'earlier_status_is_still_failed',true,'driver_sha256',result.driver_sha256);
teach_writejson(fullfile(folder,'record.json'),record);
assert(result.all_passed,'Cross-process data differ.');
fprintf('N2_ARCHIVE_REPLAY_PASSED numeric_elements=%d folder=%s\n',sum([rows.numeric_elements]),folder);
end
