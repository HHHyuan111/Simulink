function report=compare_sensorless_r2_estimator_states(reference,guard)
% Full JEOS estimator-state equality across the packet-qualification change.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));addpath(base,fullfile(fileparts(base),'teaching'));
a=jsondecode(fileread(fullfile(reference,'record.json')));b=jsondecode(fileread(fullfile(guard,'record.json')));
assert(strcmp(a.phase,'completed')&&strcmp(b.phase,'completed'));
assert(strcmp(a.raw_sha256,teach_hash(fullfile(reference,'signals.mat')))&&strcmp(b.raw_sha256,teach_hash(fullfile(guard,'signals.mat'))));
assert(isequaln(a.config_vector,b.config_vector)&&isequaln(a.observer_config,b.observer_config));
keys={'theta','speed','omega_e','theta_raw','phase_correction','front_phase','emf','emf_magnitude',...
 'i_hat','i_residual','input_i','input_v','injection','pll_error','pll_integral','valid','sample_valid','history','voltage_native'};
names=strcat('obs_sless_v2_',keys);left=load(fullfile(reference,'signals.mat'),names{:});right=load(fullfile(guard,'signals.mat'),names{:});count=0;
for k=1:numel(names)
 x=left.(names{k});y=right.(names{k});assert(isequaln(x.Time,y.Time)&&isequaln(x.Data,y.Data),'Estimator state changed: %s',names{k});count=count+numel(x.Time)+numel(x.Data);
end
report=struct('kind','estimator_states_unchanged_by_packet_guard','all_passed',true,'logs',numel(names),...
 'numeric_elements',count,'reference_raw_sha256',a.raw_sha256,'guard_raw_sha256',b.raw_sha256,...
 'comparison','strict_isequaln_full_Time_Data','not_original52_long_baseline_regression',true);
teach_writejson(fullfile(guard,'estimator_state_comparison.json'),report);fprintf('R2_ESTIMATOR_STATE_EQUAL logs=%d elements=%d\n',numel(names),count);
end
