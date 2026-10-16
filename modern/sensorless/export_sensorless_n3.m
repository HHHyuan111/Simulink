function export_sensorless_n3(campaignFolder)
% Full control-rate CSV and compact metric reports; no plotting/model loading.
here=fileparts(mfilename('fullpath'));addpath(fullfile(fileparts(here),'teaching'));
campaign=jsondecode(fileread(fullfile(campaignFolder,'campaign.json')));
out=fullfile(here,'milestones','N3');if ~isfolder(out),mkdir(out);end
copyfile(fullfile(campaignFolder,'campaign.json'),fullfile(out,'campaign.json'));
rows=struct([]);sources=struct([]);
for e=campaign.entries(:)'
 if ~strcmp(e.kind,'observer')||isempty(e.completed_folder),continue;end
 record=jsondecode(fileread(fullfile(e.completed_folder,'record.json')));
 metrics=jsondecode(fileread(fullfile(e.completed_folder,'metrics.json')));
 copyfile(fullfile(e.completed_folder,'record.json'),fullfile(out,[e.case_id '_record.json']));
 copyfile(fullfile(e.completed_folder,'metrics.json'),fullfile(out,[e.case_id '_metrics.json']));
 fields={'theta','truth_theta','speed','truth_speed','valid','state','pll_saturated','input_i','i_hat','emf','pll_error','pll_integral','phase_correction','sample_valid','reset'};
 data=[];time=[];
 for k=1:numel(fields)
  name=['obs_sless_' fields{k}];raw=load(fullfile(e.completed_folder,'signals.mat'),name);s=raw.(name);
  if isempty(time),time=s.Time;data=time;else,assert(isequaln(time,s.Time));end
  data=[data double(teach_values(s))]; %#ok<AGROW>
 end
 angle=atan2(sin(data(:,2)-data(:,3)),cos(data(:,2)-data(:,3)));
 data=[data angle];
 names={'time_s','theta_rad','truth_theta_rad','speed_rpm','truth_speed_rpm','valid','state','saturated',...
  'current_alpha_A','current_beta_A','estimated_alpha_A','estimated_beta_A','emf_alpha_V','emf_beta_V',...
  'pll_error','pll_integral_rad_s','phase_correction_rad','sample_valid','reset','angle_error_rad'};
 filename=[e.case_id '_plot_data.csv'];writetable(array2table(data,'VariableNames',names),fullfile(out,filename));
 q=struct('case_id',e.case_id,'raw_sha256',record.raw_sha256,'csv_sha256',teach_hash(fullfile(out,filename)));
 if isempty(sources),sources=q;else,sources(end+1)=q;end %#ok<AGROW>
 q=struct('case_id',e.case_id,'kind',metrics.kind,'passed',metrics.passed,'first_valid_s',metrics.first_valid_s,...
  'false_valid_samples',metrics.false_valid_samples,'false_valid_longest_s',metrics.false_valid_longest_s);
 if isempty(rows),rows=q;else,rows(end+1)=q;end %#ok<AGROW>
end
teach_writejson(fullfile(out,'summary.json'),struct('schema',1,'node','N3','cases',rows,'all_passed',numel(rows)==16&&all([rows.passed])));
teach_writejson(fullfile(out,'figure_provenance.json'),struct('source_folder',campaignFolder,'sources',sources,'full_control_rate',true,'exporter_sha256',teach_hash([mfilename('fullpath') '.m'])));
writetable(struct2table(rows),fullfile(out,'case_metrics.csv'));
end
