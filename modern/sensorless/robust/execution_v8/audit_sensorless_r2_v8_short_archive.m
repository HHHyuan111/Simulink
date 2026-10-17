function report=audit_sensorless_r2_v8_short_archive(folder)
% Analysis only; retain the original96 output arrays unchanged.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);addpath(base,fullfile(modern,'teaching'));
reference=fullfile(base,'runs/N3R2_fault_final_short_precheck_20261017_141116_c027734c-49b8-4ecd-8e60-81a403609cfc/r1_short_logging_check_attempt_2');
r=jsondecode(fileread(fullfile(folder,'record.json')));assert(strcmp(r.raw_sha256,teach_hash(fullfile(folder,'signals.mat'))));
names=whos('-file',fullfile(reference,'signals.mat'));ordinary=setdiff({names.name},{'obs_dead_gates','obs_dead_requested'});
[same,count,failed]=compare_sensorless_n3_raw(fullfile(reference,'signals.mat'),fullfile(folder,'signals.mat'),ordinary);
report=struct('analysis_only',true,'ordinary_logs',numel(ordinary),'ordinary_elements',count,'ordinary_equal',same,'ordinary_failures',{failed});
for name={'obs_dead_gates','obs_dead_requested'}
 a=load(fullfile(reference,'signals.mat'),name{1});b=load(fullfile(folder,'signals.mat'),name{1});a=a.(name{1});b=b.(name{1});
 cap=4000;tail=getsamples(b,max(1,numel(b.Time)-cap+1):numel(b.Time));h=r.config_vector(1);
 uniform=round(b.Time(1)/h)*h+(0:numel(b.Time)-1)'*h;
 report.(name{1})=struct('reference_samples',numel(a.Time),'api_samples',numel(b.Time),'api_first_time_s',b.Time(1),...
  'api_last_time_s',b.Time(end),'reference_first_time_s',a.Time(1),'reference_last_time_s',a.Time(end),...
  'full_Time_equal',isequaln(a.Time,b.Time),'full_Data_equal',isequaln(a.Data,b.Data),...
  'configured_tail_Time_equal',isequaln(a.Time,tail.Time),'configured_tail_Data_equal',isequaln(a.Data,tail.Data),...
  'uniform_encoding_Time_equal',isequaln(a.Time,uniform),'native_ticks_equal',isequaln(round(a.Time/h),round(b.Time/h)),...
  'max_time_difference_s',max(abs(a.Time-b.Time)),'reference_increment',a.TimeInfo.Increment,'api_increment',b.TimeInfo.Increment);
end
teach_writejson(fullfile(folder,'bounded_log_diagnosis.json'),report);
end
