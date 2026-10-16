function archive_sensorless_n2(originalFolder,replayFolder)
% Export a small review package; original native-rate MAT files stay in runs/.
here=fileparts(mfilename('fullpath'));addpath(here,fullfile(fileparts(here),'teaching'));
out=fullfile(here,'milestones','N2');if ~isfolder(out),mkdir(out);end
record=jsondecode(fileread(fullfile(originalFolder,'record.json')));
replay=jsondecode(fileread(fullfile(replayFolder,'replay_validation.json')));
assert(strcmp(record.status,'passed')&&replay.all_passed);
render_sensorless_n2(originalFolder);
for name={'record.json','analysis.json','module_layout.png','smo_layout.png',...
 'reference_enabled_overview.png','reference_enabled_internal.png','events_enabled_overview.png','events_enabled_internal.png'}
 copyfile(fullfile(originalFolder,name{1}),fullfile(out,name{1}));
end
copyfile(fullfile(replayFolder,'replay_validation.json'),fullfile(out,'replay_validation.json'));
copyfile(fullfile(replayFolder,'record.json'),fullfile(out,'replay_record.json'));
c=sensorless_parameters;teach_writejson(fullfile(out,'effective_parameters.json'),c);
for id={'reference_disabled','reference_enabled','events_enabled'}
 for suffix={'graph','rates'}
  name=[id{1} '_' suffix{1} '.json'];copyfile(fullfile(originalFolder,name),fullfile(out,name));
 end
 row=record.cases(strcmp({record.cases.id},id{1}));
 loaded=load(fullfile(originalFolder,row.file),'signals');s=loaded.signals;
 interval=teach_values(s.obs_sless_voltage_interval);voltage=teach_values(s.obs_sless_input_v);
 native=teach_values(s.obs_sless_voltage_native);complete=find(interval(:,2)>interval(:,1));
 selected=[complete(1:20);complete(end-19:end)];data=zeros(40,11);
 for k=1:40
  j=selected(k);a=interval(j,1);b=interval(j,2);
  rows=find(native(:,1)>=a-1e-12&native(:,1)<b-1e-12);
  data(k,:)=[j a b voltage(j,:) numel(rows) native(rows(1),9) native(rows(end),9)...
   native(rows(end),12)-native(rows(1),12) native(rows(1),10) native(rows(1),11)];
 end
 table=array2table(data,'VariableNames',{'sample_index','interval_start_s','interval_end_s',...
  'alpha_weighted_V','beta_weighted_V','native_pieces','sequence_start','sequence_end',...
  'threshold_or_sequence_changes','start_boundary','ready_at_start'});
 writetable(table,fullfile(out,[id{1} '_first_last20_intervals.csv']));
end
files=dir(out);manifest=struct('schema',1,'node','N2','files',struct('path',{},'sha256',{}));
for f=files(:)'
 if f.isdir||strcmp(f.name,'artifact_manifest.json'),continue;end
 manifest.files(end+1)=struct('path',f.name,'sha256',teach_hash(fullfile(out,f.name))); %#ok<AGROW>
end
teach_writejson(fullfile(out,'artifact_manifest.json'),manifest);
fprintf('N2_REVIEW_PACKAGE %s\n',out);
end
