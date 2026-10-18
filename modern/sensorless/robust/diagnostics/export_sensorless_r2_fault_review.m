function provenance=export_sensorless_r2_fault_review(folder)
% Read-only fault export; missing captures stay missing in publication data.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));addpath(fullfile(fileparts(base),'teaching'));
record=jsondecode(fileread(fullfile(folder,'record.json')));assert(strcmp(record.phase,'completed')&&record.reference_restored);
raw=fullfile(folder,'signals.mat');assert(strcmp(teach_hash(raw),record.raw_sha256));
names={'theta','truth_theta','speed','truth_speed','emf_magnitude','valid','sample_valid','adc_valid'};
fields=strcat('obs_sless_v2_',names);fields=[fields {'obs_sless_r2_phase_guard','obs_sless_r2_fault_queue','obs_sless_r2_actual_publications','obs_sless_r2_native_events','obs_sless_r2_native_counters'}];
signals=load(raw,fields{:});t=signals.obs_sless_v2_theta.Time;data=zeros(numel(t),1+numel(names));data(:,1)=t;
for k=1:numel(names),series=signals.(['obs_sless_v2_' names{k}]);assert(isequaln(series.Time,t));data(:,k+1)=teach_values(series);end
guard=teach_values(signals.obs_sless_r2_phase_guard);queue=teach_values(signals.obs_sless_r2_fault_queue);
data=[data guard(:,8) queue(:,2:3)];
columns={'time_s','theta_est_rad','theta_true_rad','speed_est_rpm','speed_true_rpm','emf_magnitude_V','history_valid','sample_valid','adc_valid','packet_valid','missing','reset'};
events=teach_values(signals.obs_sless_r2_native_events);counters=teach_values(signals.obs_sless_r2_native_counters);
publication=teach_values(signals.obs_sless_r2_actual_publications);pt=signals.obs_sless_r2_actual_publications.Time;
[found,index]=ismember(round(pt/62.5e-9),round(events(:,1)/62.5e-9));assert(all(found));
publication=[pt publication events(index,3)];
publicationColumns={'time_s','sequence','reference_s','available_s','age_s','theta_sample_rad','theta_now_rad','theta_pwm_rad','raw_speed_rpm','control_theta_sample_rad','control_theta_pwm_rad','control_speed_rpm','apply_s','present','permit'};
eventColumns={'time_s','false_valid','permit','deny_reason','adc_valid','timing_valid','age_s','angle_error_deg','speed_error_relative','theta_now_rad','theta_true_rad','speed_raw_rpm','speed_true_rpm','sequence','presented','reset'};
destination=fullfile(folder,'fault_review');assert(~isfolder(destination));mkdir(destination);
writetable(array2table(data,'VariableNames',columns),fullfile(destination,'control.csv'));
writetable(array2table(publication,'VariableNames',publicationColumns),fullfile(destination,'publications.csv'));
writetable(array2table(events,'VariableNames',eventColumns),fullfile(destination,'events.csv'));
writematrix(counters,fullfile(destination,'counters.csv'));
provenance=struct('analysis_only',true,'simulation_reexecuted',false,'source_raw_sha256',record.raw_sha256,...
 'exporter_sha256',teach_hash([mfilename('fullpath') '.m']),'control_rows',size(data,1),'publication_rows',size(publication,1),'event_rows',size(events,1),'files',struct);
for name={'control','publications','events','counters'},provenance.files.(name{1})=teach_hash(fullfile(destination,[name{1} '.csv']));end
teach_writejson(fullfile(destination,'provenance.json'),provenance);fprintf('FAULT_REVIEW_EXPORT_COMPLETE rows=%d publications=%d\n',size(data,1),size(publication,1));
end
