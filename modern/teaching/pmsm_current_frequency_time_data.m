function pack=pmsm_current_frequency_time_data(folder)
% Display exactly the samples that produced the archived Bode measurements.
if nargin<1,folder=[];end
folder=pmsm_current_frequency_folder(folder);record=verify_pmsm_current_frequency(folder);
a=load(fullfile(folder,'analysis.mat'),'p','responses');p=a.p;
assert(numel(p.cases)==2&&strcmp(p.cases(1).id,'reference')&&strcmp(p.cases(2).id,'delay'));
pack=struct('folder',folder,'record_sha256',teach_hash(fullfile(folder,'record.json')),...
 'plan',p,'responses',a.responses,'scope',record.scope,'amplitude_A',p.amplitudes_A(1),'cases',[]);
for c=1:2
 s=load(fullfile(folder,sprintf('%s_1_raw.mat',p.cases(c).id)),'raw');raw=s.raw;
 t=raw.fre_ref.Time;assert(isequal(t,raw.fre_error.Time,raw.fre_feedback.Time,raw.obs_state.Time));
 tick=round(t/p.sample_time_s);assert(all(diff(tick)==1)&&max(abs(t-tick*p.sample_time_s))<1e-10);
 state=teach_values(raw.obs_state);
 data=struct('id',p.cases(c).id,'label',p.cases(c).label,'time_s',t,'ticks',tick,...
  'reference_A',teach_values(raw.fre_ref),'true_A',state(:,1),...
  'feedback_A',teach_values(raw.fre_feedback),'error_A',teach_values(raw.fre_error));
 assert(all(isfinite([data.reference_A data.true_A data.feedback_A data.error_A]),'all'));
 assert(max(abs(data.reference_A-data.feedback_A-data.error_A))<1e-10);
 if c==1,pack.cases=data;else,pack.cases(c)=data;end
end
assert(isequal(pack.cases(1).time_s,pack.cases(2).time_s)&&isequal(pack.cases(1).reference_A,pack.cases(2).reference_A));
end
