function report=inspect_sensorless_direct_gates
% Inspect two gate logs from completed archives; no model is loaded or run.
base=sensorless_direct_setup;
r=jsondecode(fileread(fullfile(base,'milestones','N3R2','followup_20261017','v4_diagnostic_combined_3000_record.json')));
report=struct('analysis_only',true,'simulation_started',false,'signals',{{}});
for name={'obs_dead_gates','obs_dead_requested'}
 n=load(fullfile(base,'runs','SMO_direct_first','signals.mat'),name{1});a=n.(name{1});
 o=load(fullfile(r.folder,'signals.mat'),name{1});b=o.(name{1});
 use=b.Time<=.25+1e-12;bt=b.Time(use);av=teach_values(a);bv=teach_values(b);bv=bv(use,:);
 at=round(a.Time/62.5e-9);ot=round(bt/62.5e-9);
 q=struct('name',name{1},'new_rows',numel(a.Time),'old_prefix_rows',numel(bt),...
 'new_last_time',a.Time(max(1,end-4):end)','old_last_time',bt(max(1,end-4):end)',...
 'new_last_data',av(max(1,end-4):end,:),'old_last_data',bv(max(1,end-4):end,:),...
 'same_data_class',strcmp(class(a.Data),class(b.Data)),...
 'new_duplicate_ticks',sum(diff(at)==0),'old_duplicate_ticks',sum(diff(ot)==0));
 count=min(numel(at),numel(ot));first=find(at(1:count)~=ot(1:count),1);if isempty(first),first=0;end
 q.first_different_tick_row=first;
 first=find(any(av(1:count,:)~=bv(1:count,:),2),1);if isempty(first),first=0;end;q.first_different_data_row=first;
 if first>0,q.new_first_mismatch=av(first,:);q.old_first_mismatch=bv(first,:);q.new_first_mismatch_time=a.Time(first);q.old_first_mismatch_time=bt(first);end
 [present,index]=ismember(at,ot);q.all_new_ticks_in_old=all(present);
 if all(present),q.data_equal_at_matching_ticks=isequaln(av,bv(index,:));q.maximum_matching_time_delta_s=max(abs(a.Time-bt(index)));end
 report.signals{end+1}=q;
end
teach_writejson(fullfile(base,'runs','SMO_direct_first','gate_prefix_inspection.json'),report);
end
