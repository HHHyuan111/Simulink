function report=export_sensorless_r2_diagnosis(folder)
% Read-only export of complete control-rate traces; no model load/sim call.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));addpath(fullfile(fileparts(base),'teaching'));
record=jsondecode(fileread(fullfile(folder,'record.json')));assert(strcmp(record.phase,'completed'));
raw=fullfile(folder,'signals.mat');assert(strcmp(record.raw_sha256,teach_hash(raw)));
fields={'theta','truth_theta','speed','truth_speed','theta_raw','phase_correction','front_phase','pll_error','emf_magnitude',...
 'valid','sample_valid','adc_valid','timing_valid','deny_reason','input_i','i_hat','i_residual','input_v','voltage_uncertainty','publication'};
names=strcat('obs_sless_v2_',fields);names=[names {'obs_sless_r2_native_events','obs_sless_r2_native_counters'}];
s=load(raw,names{:});t=s.obs_sless_v2_theta.Time;data=struct;
for k=1:numel(fields),data.(fields{k})=teach_values(s.(['obs_sless_v2_' fields{k}]));end
events=teach_values(s.obs_sless_r2_native_events);counters=teach_values(s.obs_sless_r2_native_counters);
[found,index]=ismember(round(s.obs_sless_v2_publication.Time/62.5e-9),round(events(:,1)/62.5e-9));assert(all(found));
emf_theta=mod(data.theta_raw+data.phase_correction+data.front_phase,2*pi);
control=[t data.theta data.truth_theta data.speed data.truth_speed data.theta_raw data.phase_correction data.front_phase emf_theta...
 data.pll_error data.emf_magnitude data.valid data.sample_valid data.adc_valid data.timing_valid data.deny_reason...
 data.input_i data.i_hat data.i_residual data.input_v data.voltage_uncertainty data.publication(:,1:3) events(index,3)];
columns={'time_s','theta_est_rad','theta_true_rad','speed_est_rpm','speed_true_rpm','theta_raw_rad','core_phase_rad','front_phase_rad','theta_emf_corrected_rad',...
 'pll_error','emf_magnitude_V','quality_valid','sample_valid','adc_valid','timing_valid','deny_reason',...
 'i_alpha_A','i_beta_A','i_hat_alpha_A','i_hat_beta_A','residual_alpha_A','residual_beta_A',...
 'u_alpha_V','u_beta_V','conditional_bound_alpha_V','conditional_bound_beta_V','sequence','reference_s','available_s','permit_at_available'};
assert(size(control,2)==numel(columns));destination=fullfile(folder,'review');if ~isfolder(destination),mkdir(destination);end
writetable(array2table(control,'VariableNames',columns),fullfile(destination,'control.csv'));
event_columns={'time_s','false_valid','permit','deny_reason','adc_valid','timing_valid','age_s','angle_error_deg','speed_error_relative',...
 'theta_now_rad','theta_true_rad','speed_raw_rpm','speed_true_rpm','sequence','presented','reset'};
writetable(array2table(events,'VariableNames',event_columns),fullfile(destination,'events.csv'));
writematrix(counters,fullfile(destination,'counters.csv'));
report=struct('source_raw_sha256',record.raw_sha256,'exporter_sha256',teach_hash([mfilename('fullpath') '.m']),...
 'control_rows',size(control,1),'event_rows',size(events,1),'counter_rows',size(counters,1),...
 'no_model_loaded',true,'no_downsampling',true);
for name={'control.csv','events.csv','counters.csv'},report.files.(strrep(name{1},'.csv',''))=teach_hash(fullfile(destination,name{1}));end
teach_writejson(fullfile(destination,'provenance.json'),report);fprintf('R2_DIAGNOSIS_EXPORT_COMPLETED rows=%d events=%d\n',size(control,1),size(events,1));
end
