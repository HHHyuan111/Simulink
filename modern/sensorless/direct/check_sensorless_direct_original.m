function result=check_sensorless_direct_original(signals,duration)
% Compare original control signals against the completed nonideal baseline.
base=fileparts(fileparts(mfilename('fullpath')));
r=jsondecode(fileread(fullfile(base,'runs','SMO_direct_baseline','report.json')));
raw=fullfile(base,'runs','SMO_direct_baseline','signals.mat');assert(r.passed&&strcmp(teach_hash(raw),r.raw_sha256));
old=load(raw);
schema=jsondecode(fileread(fullfile(base,'baseline','log_schema.json')));
result=struct('reference_raw_sha256',r.raw_sha256,'signals',struct('name',{},'data_exact',{},'time_accepted',{}),'passed',false);
for k=1:numel(schema)
 name=schema(k).name;b=old.(name);a=signals.(name);
 use=b.Time<=duration+1e-12;bt=b.Time(use);bv=teach_values(b);av=teach_values(a);bv=bv(use,:);
 exact=isequaln(a.Time,bt);encoding=false;
 if ismember(name,{'obs_dead_gates','obs_dead_requested'})&&isequal(size(a.Time),size(bt))
  encoding=isequal(round(a.Time/62.5e-9),round(bt/62.5e-9))&&max(abs(a.Time-bt))<=4*eps(max(abs(bt)));
 end
 result.signals(k)=struct('name',name,'data_exact',isequaln(av,bv)&&strcmp(class(a.Data),class(b.Data)),...
  'time_accepted',exact||encoding);
end
result.passed=all([result.signals.data_exact]&[result.signals.time_accepted]);
end
