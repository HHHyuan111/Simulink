function export_sensorless_n2_review(originalFolder,replayFolder)
% Data-only export for an independent plotting backend; never loads a model.
here=fileparts(mfilename('fullpath'));addpath(fullfile(fileparts(here),'teaching'));
out=fullfile(here,'milestones','N2');if ~isfolder(out),mkdir(out);end
record=jsondecode(fileread(fullfile(originalFolder,'record.json')));
replay=jsondecode(fileread(fullfile(replayFolder,'replay_validation.json')));
assert(strcmp(record.status,'passed')&&replay.all_passed);
for name={'record.json','analysis.json','module_layout.png','smo_layout.png'}
 copyfile(fullfile(originalFolder,name{1}),fullfile(out,name{1}));
end
copyfile(fullfile(replayFolder,'replay_validation.json'),fullfile(out,'replay_validation.json'));
copyfile(fullfile(replayFolder,'record.json'),fullfile(out,'replay_record.json'));
teach_writejson(fullfile(out,'effective_parameters.json'),sensorless_parameters);
sources=struct('case_id',{},'raw_sha256',{},'csv_sha256',{});
for id={'reference_disabled','reference_enabled','events_enabled'}
 for suffix={'graph','rates'}
  name=[id{1} '_' suffix{1} '.json'];copyfile(fullfile(originalFolder,name),fullfile(out,name));
 end
 row=record.cases(strcmp({record.cases.id},id{1}));
 assert(strcmp(row.sha256,teach_hash(fullfile(originalFolder,row.file))));
 raw=load(fullfile(originalFolder,row.file),'signals');s=raw.signals;
 time=s.obs_sless_theta.Time;
 fields={'truth_theta','theta','truth_speed','speed','angle_error','valid','state','pll_saturated',...
  'input_i','i_hat','emf','pll_error','pll_integral','phase_correction'};
 data=time;
 for k=1:numel(fields)
  series=s.(['obs_sless_' fields{k}]);assert(isequaln(series.Time,time));
  data=[data double(teach_values(series))]; %#ok<AGROW>
 end
 names={'time_s','truth_theta_rad','theta_rad','truth_speed_rpm','speed_rpm','angle_error_rad',...
  'valid','state','saturated','current_alpha_A','current_beta_A','estimated_alpha_A','estimated_beta_A',...
  'emf_alpha_V','emf_beta_V','pll_error','pll_integral_rad_s','phase_correction_rad'};
 filename=[id{1} '_plot_data.csv'];writetable(array2table(data,'VariableNames',names),fullfile(out,filename));
 sources(end+1)=struct('case_id',id{1},'raw_sha256',row.sha256,'csv_sha256',teach_hash(fullfile(out,filename))); %#ok<AGROW>
 interval=teach_values(s.obs_sless_voltage_interval);voltage=teach_values(s.obs_sless_input_v);
 native=teach_values(s.obs_sless_voltage_native);complete=find(interval(:,2)>interval(:,1));
 selected=[complete(1:20);complete(end-19:end)];audit=zeros(40,9);
 for k=1:40
  j=selected(k);a=interval(j,1);b=interval(j,2);
  rows=find(native(:,1)>=a-1e-12&native(:,1)<b-1e-12);
  audit(k,:)=[j a b voltage(j,:) numel(rows) native(rows(1),9) native(rows(end),9)...
   native(rows(end),12)-native(rows(1),12)];
 end
 names={'sample_index','interval_start_s','interval_end_s','alpha_weighted_V','beta_weighted_V',...
  'native_pieces','sequence_start','sequence_end','threshold_or_sequence_changes'};
 writetable(array2table(audit,'VariableNames',names),fullfile(out,[id{1} '_first_last20_intervals.csv']));
end
provenance=struct('source_folder',originalFolder,'sources',sources,...
 'exporter_sha256',teach_hash([mfilename('fullpath') '.m']),...
 'data_modified',false,'decimation',false,'csv_purpose','plotting only; raw MAT remains acceptance authority');
teach_writejson(fullfile(out,'figure_provenance.json'),provenance);
fprintf('N2_DATA_EXPORT_DONE %s\n',out);
end
