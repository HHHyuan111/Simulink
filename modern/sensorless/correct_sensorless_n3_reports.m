function report=correct_sensorless_n3_reports(originalFolder,replayFolder,capsuleFolder)
% Repair diagnostic reporting from archived arrays without loading a model.
here=fileparts(mfilename('fullpath'));addpath(fullfile(fileparts(here),'teaching'));
out=fullfile(here,'milestones','N3');
executed=fullfile(capsuleFolder,'analyse_sensorless_n3_case.m');
copyfile(executed,fullfile(out,'analysis_executed.txt'));
campaigns={originalFolder,replayFolder};rows=struct([]);
cases={'low_speed_stop','missing_5_samples','observer_reset'};
names={'obs_sless_theta','obs_sless_truth_theta','obs_sless_speed','obs_sless_truth_speed',...
 'obs_sless_valid','obs_sless_state','obs_sless_pll_saturated','obs_sless_i_residual',...
 'obs_sless_pll_error','obs_sless_emf_magnitude','obs_sless_sample_valid','obs_sless_reset',...
 'obs_sless_history','obs_sless_i_hat','obs_sless_injection','obs_sless_emf',...
 'obs_sless_pll_integral','obs_sless_input_v','obs_sless_omega_e','log_nref','log_TL'};
required={'passed','precision_required','dynamic_required','correct_sign','finite_states',...
 'stimulus','validity','faults','events'};
allowed={'target_rpm','speed_mean_error_relative','speed_error_rms_relative','plant_settled','precision_passed'};
for j=1:numel(cases)
 corrected=cell(1,2);
 for group=1:2
  campaign=jsondecode(fileread(fullfile(campaigns{group},'campaign.json')));
  entry=campaign.entries(strcmp({campaign.entries.kind},'observer')&strcmp({campaign.entries.case_id},cases{j}));
  assert(isscalar(entry));folder=entry.completed_folder;
  record=jsondecode(fileread(fullfile(folder,'record.json')));
  before=jsondecode(fileread(fullfile(folder,'metrics.json')));
  raw=fullfile(folder,'signals.mat');assert(strcmp(teach_hash(raw),record.raw_sha256));
  signals=load(raw,names{:});computed=analyse_sensorless_n3_case(signals,record.effective_case,record.observer_config);
  after=jsondecode(jsonencode(computed)); % Canonical types for comparison only; retain NaN for JSON null on export.
  for k=1:numel(required),key=required{k};assert(isequaln(before.(key),after.(key)),'Required field changed: %s',key);end
  assert(isequaln(rmfield(before,'windows'),rmfield(after,'windows')));
  assert(isequaln(rmfield(before.windows,allowed),rmfield(after.windows,allowed)));
  assert(strcmp(teach_hash(raw),record.raw_sha256));
  label='original';if group==2,label='replay';end
  copyfile(fullfile(folder,'metrics.json'),fullfile(out,[cases{j} '_' label '_metrics_executed.json']));
  corrected{group}=computed;
  q=struct('case_id',cases{j},'group',label,'folder',folder,'raw_sha256',record.raw_sha256,...
   'raw_unchanged',true,'required_flags_identical',true,'diagnostic_fields_allowed',{allowed});
  if isempty(rows),rows=q;else,rows(end+1)=q;end %#ok<AGROW>
 end
 assert(isequaln(corrected{1},corrected{2}),'Corrected reports differ between processes.');
 teach_writejson(fullfile(out,[cases{j} '_metrics.json']),corrected{1});
 teach_writejson(fullfile(out,[cases{j} '_replay_metrics_corrected.json']),corrected{2});
end
report=struct('schema',1,'node','N3','scope','postprocessing_only_no_simulation_or_acceptance_change',...
 'reason','Fault-window target was NaN instead of 3000 rpm; zero-target relative errors now N/A.',...
 'executed_analyzer_sha256',teach_hash(executed),...
 'corrected_analyzer_sha256',teach_hash(fullfile(here,'analyse_sensorless_n3_case.m')),...
 'correction_driver_sha256',teach_hash([mfilename('fullpath') '.m']),...
 'cases',rows,'corrected_replay_metrics_identical',true,'all_required_flags_identical',true);
teach_writejson(fullfile(out,'diagnostic_correction.json'),report);
end
