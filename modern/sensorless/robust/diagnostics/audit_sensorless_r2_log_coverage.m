function report=audit_sensorless_r2_log_coverage(folder)
% Confirm original52 configured retention, including existing bounded logs.
% This checks coverage, not baseline numerical equivalence (reserved for R3).
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));addpath(fullfile(fileparts(base),'teaching'));
record=jsondecode(fileread(fullfile(folder,'record.json')));assert(strcmp(record.phase,'completed'));
raw=fullfile(folder,'signals.mat');assert(strcmp(record.raw_sha256,teach_hash(raw)));
reference=fullfile(base,'runs/N3R1_formal_20261016_233230_ef2a2a57-ee3e-451c-9850-e101d2101803/combined_formal_attempt_1/signals.mat');
schema=jsondecode(fileread(fullfile(base,'baseline/log_schema.json')));old=matfile(reference);current=matfile(raw);
snapshot=load(fullfile(folder,'restoration.mat'),'original');h=record.config_vector(1);
report=struct('kind','original52_configured_retention_coverage','is_baseline_regression',false,'all_passed',false,...
 'source_raw_sha256',record.raw_sha256,'auditor_sha256',teach_hash([mfilename('fullpath') '.m']));
for k=1:numel(schema)
 name=schema(k).name;a=old.(name);b=current.(name);assert(isa(a,'timeseries')&&isa(b,'timeseries'));
 ta=a.Time(:);t=b.Time(:);assert(numel(ta)>1);
 periodTicks=round((ta(end)-ta(1))/(numel(ta)-1)/h);assert(periodTicks>0);period=periodTicks*h;
 offsetTicks=mod(round(ta(1)/h),periodTicks);endTick=round(record.effective_case.duration_s/h);
 total=floor((endTick-offsetTicks)/periodTicks)+1;cap=NaN;
 for block=snapshot.original.blocks(:)'
  if isfield(block.params,'VariableName')&&strcmp(block.params.VariableName,name),cap=str2double(block.params.MaxDataPoints);end
 end
 assert(cap>=1);expected=min(total,cap);lastTick=offsetTicks+(total-1)*periodTicks;first=(lastTick-(expected-1)*periodTicks)*h;
 assert(numel(t)==expected&&all(isfinite(t))&&all(diff(t)>0),'Incomplete original trace: %s',name);
 error=max(abs(t-(first+(0:expected-1)'*period)));assert(error<1e-12,'Unexpected time grid: %s',name);
 asz=size(a.Data);bsz=size(b.Data);axis=ndims(a.Data);if a.IsTimeFirst,axis=1;end
 asz(axis)=1;bsz(axis)=1;assert(isequaln(asz,bsz)&&a.IsTimeFirst==b.IsTimeFirst);
 report.logs(k)=struct('name',name,'samples',numel(t),'first_s',t(1),'last_s',t(end),...
  'sample_period_s',period,'max_time_grid_error_s',error,'configured_max_points',cap,'full_run_points',total,'bounded',isfinite(cap)&&total>cap);
 clear a b ta t;
end
assert(numel(schema)==52);report.all_passed=true;report.bounded_logs=sum([report.logs.bounded]);teach_writejson(fullfile(folder,'log_coverage.json'),report);
fprintf('R2_ORIGINAL52_LOG_COVERAGE_PASSED count=52\n');
end
