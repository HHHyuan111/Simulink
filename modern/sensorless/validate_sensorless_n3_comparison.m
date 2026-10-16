function report=validate_sensorless_n3_comparison
% Independent whole-array oracle challenges the disk/chunk comparison path.
here=fileparts(mfilename('fullpath'));addpath(fullfile(fileparts(here),'teaching'));
folder=[tempname(fullfile(here,'.build')) '_comparison'];mkdir(folder);
n=2^20+3;t=(0:n-1)'*50e-6;data=[sin(t) cos(t)];data(2,1)=NaN;data(1,1)=0;
a=struct('primary',timeseries(data,t),'flag',timeseries(logical([0;1;0]),[0;1;2]),...
 'single_value',timeseries(single([1;2;3]),[0;1;2]));
first=fullfile(folder,'first.mat');second=fullfile(folder,'second.mat');save(first,'-struct','a','-v7.3');
variants={'equal','time_change','first_value_change','after_chunk_change','flag_change','shape_change','nan_equal','signed_zero_equal'};
rows=struct([]);
for j=1:numel(variants)
 b=struct('primary',timeseries(data,t),'flag',timeseries(logical([0;1;0]),[0;1;2]),...
  'single_value',timeseries(single([1;2;3]),[0;1;2]));
 switch variants{j}
  case 'time_change',b.primary.Time(11)=b.primary.Time(11)+1e-6;
  case 'first_value_change',b.primary.Data(1,1)=1;
  case 'after_chunk_change',b.primary.Data(end,2)=b.primary.Data(end,2)+1;
  case 'flag_change',b.flag.Data(2)=false;
  case 'shape_change',b.primary=timeseries([data zeros(n,1)],t);
  case 'nan_equal',b.primary.Data(2,1)=NaN;
  case 'signed_zero_equal',b.primary.Data(1,1)=-0.0;
 end
 expected=true;elements=0;
 for name=fieldnames(a)'
  x=a.(name{1});y=b.(name{1});expected=expected&&isequaln(x.Time,y.Time)&&isequaln(x.Data,y.Data);
  elements=elements+numel(x.Time)+numel(x.Data);
 end
 save(second,'-struct','b','-v7.3');[actual,count,failures]=compare_sensorless_n3_raw(first,second,{});
 q=struct('variant',variants{j},'expected_equal',expected,'actual_equal',actual,...
  'numeric_elements',count,'failures',{failures},'passed',actual==expected&&count==elements);
 if isempty(rows),rows=q;else,rows(end+1)=q;end %#ok<AGROW>
 assert(q.passed,'Comparison oracle failed: %s',variants{j});
end
report=struct('schema',1,'node','N3','whole_array_oracle','MATLAB isequaln on original in-memory Time/Data',...
 'test_driver_sha256',teach_hash([mfilename('fullpath') '.m']),...
 'comparison_driver_sha256',teach_hash(fullfile(here,'compare_sensorless_n3_raw.m')),...
 'cases',rows,'all_passed',all([rows.passed]));
teach_writejson(fullfile(here,'milestones','N3','comparison_oracle.json'),report);
fprintf('N3_COMPARISON_ORACLE_PASSED=%d cases=%d\n',report.all_passed,numel(rows));
end
