function r=compare_sensorless_closed(firstLabel,secondLabel)
% Compare two independent completed runs of the same saved candidate.
here=fileparts(mfilename('fullpath'));addpath(fullfile(fileparts(here),'direct'));base=sensorless_direct_setup;
aFolder=fullfile(base,'runs',['SMO_closed_' firstLabel]);bFolder=fullfile(base,'runs',['SMO_closed_' secondLabel]);
first=jsondecode(fileread(fullfile(aFolder,'report.json')));second=jsondecode(fileread(fullfile(bFolder,'report.json')));
r=struct('first_label',firstLabel,'second_label',secondLabel,'independent_processes',first.process_id~=second.process_id,...
 'same_model',strcmp(first.model_sha256,second.model_sha256),'both_metrics_passed',first.passed&&second.passed);
a=load(fullfile(aFolder,'signals.mat'));b=load(fullfile(bFolder,'signals.mat'));names=fieldnames(a);
r.same_log_names=isequal(names,fieldnames(b));r.log_count=numel(names);r.different_logs={};
for k=1:numel(names)
 name=names{k};same=isfield(b,name)&&isequal(a.(name).Time,b.(name).Time)&&isequal(a.(name).Data,b.(name).Data);
 if ~same,r.different_logs{end+1}=name;end
end
r.exact_time_and_data=r.same_log_names&&isempty(r.different_logs);
r.passed=r.independent_processes&&r.same_model&&r.both_metrics_passed;
teach_writejson(fullfile(bFolder,'repeat_comparison.json'),r);
end
