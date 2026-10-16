function export_sensorless_v2_r1(campaign,destination)
% Offline exports from verified archives; never loads or changes a model.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);
addpath(fullfile(modern,'teaching'));assert(~bdIsLoaded('PMSM_FOC_R2026a'));
v=jsondecode(fileread(fullfile(campaign,'verification.json')));assert(v.all_passed);
m=jsondecode(fileread(fullfile(campaign,'campaign.json')));assert(strcmp(m.status,'passed'));
if ~isfolder(destination),mkdir(destination);end
provenance=struct('schema',1,'campaign',campaign,'verification_sha256',teach_hash(fullfile(campaign,'verification.json')),...
 'exports',struct('path',{},'sha256',{},'raw_sha256',{}));
for id={'combined','rail','window','deadline'}
 j=find(strcmp({m.jobs.label},[id{1} '_formal']));folder=m.jobs(j).completed_folder;
 r=jsondecode(fileread(fullfile(folder,'record.json')));assert(strcmp(r.raw_sha256,teach_hash(fullfile(folder,'signals.mat'))));
 s=load(fullfile(folder,'signals.mat'));t=s.obs_sless_v2_input_i.Time;
 raw=teach_values(s.log_iabc_meas);abc=teach_values(s.obs_sless_v2_current_ABC);
 uncertainty=teach_values(s.obs_sless_v2_voltage_uncertainty);meta=teach_values(s.obs_sless_v2_measurement);
 table=array2table([t raw abc uncertainty meta(:,7:12)],'VariableNames',...
  {'time_s','measured_A_A','measured_B_A','measured_C_A','aligned_A_A','aligned_B_A','aligned_C_A',...
   'path_unc_alpha_V','path_unc_beta_V','rail','window_good','timing_good','has_history','zero_sequence_A','alignment_norm_A'});
 name=[id{1} '_control.csv'];writetable(table,fullfile(destination,name));entry(name,r.raw_sha256);
 qt=s.obs_sless_v2_publication.Time;values=teach_values(s.obs_sless_v2_publication);
 keep=qt>=20e-6&qt<=90e-6;
 p=teach_values(s.obs_sless_v2_control_permit);reason=teach_values(s.obs_sless_v2_deny_reason);
 table=array2table([qt(keep) values(keep,:) p(keep) reason(keep)],'VariableNames',...
  {'time_s','sequence','reference_s','available_s','age_s','theta_sample_rad','theta_now_rad','theta_pwm_rad','raw_speed_rpm',...
   'control_sample_rad','control_pwm_rad','control_speed_rpm','apply_s','present','permit','reason'});
 name=[id{1} '_publication_excerpt.csv'];writetable(table,fullfile(destination,name));entry(name,r.raw_sha256);
 copyfile(fullfile(folder,'record.json'),fullfile(destination,[id{1} '_record.json']));
 copyfile(fullfile(folder,'metrics.json'),fullfile(destination,[id{1} '_metrics.json']));
 copyfile(fullfile(folder,'graph.json'),fullfile(destination,[id{1} '_graph.json']));
 clear s;
end
j=find(strcmp({m.jobs.label},'component_first'));folder=m.jobs(j).completed_folder;
r=jsondecode(fileread(fullfile(folder,'record.json')));assert(strcmp(r.raw_sha256,teach_hash(fullfile(folder,'raw.mat'))));
s=load(fullfile(folder,'raw.mat'));a=s.raw.recovery;
writetable(array2table([a(:,1)*50e-6 a(:,2:end)],'VariableNames',...
 {'time_s','input_good','quality_lock','quality_state','history_count','permit_before_ready','permit_after_ready','reason_before','reason_after'}),fullfile(destination,'component_recovery.csv'));entry('component_recovery.csv',r.raw_sha256);
copyfile(fullfile(folder,'metrics.json'),fullfile(destination,'component_metrics.json'));
for name={'campaign.json','verification.json','frozen_candidate.json'},copyfile(fullfile(campaign,name{1}),fullfile(destination,name{1}));end
teach_writejson(fullfile(destination,'export_provenance.json'),provenance);
 function entry(name,rawhash)
  provenance.exports(end+1)=struct('path',name,'sha256',teach_hash(fullfile(destination,name)),'raw_sha256',rawhash);
 end
end
