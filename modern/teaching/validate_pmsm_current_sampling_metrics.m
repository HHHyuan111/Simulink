function report=validate_pmsm_current_sampling_metrics
teach=fileparts(mfilename('fullpath'));root=fileparts(teach);addpath(teach);
h=1e-6;t=(0:2000)'*h;tick=(0:2000)';phase=mod(tick,50);truth=[t -2*t 3*t]*1000;
feedback=truth+[.1 -.2 .3];hold=truth(:,1)-.05;
a=zeros(numel(t),15);a(:,1)=phase*h;
offsets=[5 7 9 11 13];for k=1:5,a(:,k+1)=phase==offsets(k);end
a(:,7:9)=1;
out=fixture(truth,hold,feedback,a,t);window=[.0005 .001];r=pmsm_current_sampling_metrics(out,window);
assert(r.sample_count==501&&max(abs(r.feedback_minus_truth.rms_A-[.1 .2 .3]))<1e-12);
assert(max(abs(r.feedback_minus_truth.mean_A-[.1 -.2 .3]))<1e-12);
assert(abs(r.hold_minus_truth_A.rms_A-.05)<1e-12&&abs(r.hold_minus_truth_A.mean_A+.05)<1e-12);
assert(abs(r.feedback_minus_hold_A.rms_A-.15)<1e-12);
assert(max(abs(r.truth_window_peak_to_peak_ABC_A-[.5 1 1.5]))<1e-12);
keys={'trigger_to_JEOS','A_end_to_JEOS','B_end_to_JEOS','C_end_to_JEOS'};expected=[8 2 4 6];
for k=1:4,s=r.adc.intervals.(keys{k});assert(s.paired_count==10&&s.missing_count==0&&s.ambiguous_count==0&&abs(s.mean_us-expected(k))<1e-9);end
assert(isequal(r.adc.window_validity.valid_fraction_ABC,[1 1 1]));
zero=a;zero(:,2:6)=0;r0=pmsm_current_sampling_metrics(fixture(truth,hold,feedback,zero,t),window);
assert(~r0.adc.intervals.trigger_to_JEOS.available&&isempty(r0.adc.intervals.trigger_to_JEOS.mean_us));
missing=a;missing(tick==505,2)=0;rm=pmsm_current_sampling_metrics(fixture(truth,hold,feedback,missing,t),window);
assert(rm.adc.intervals.trigger_to_JEOS.paired_count==9&&rm.adc.intervals.trigger_to_JEOS.missing_count==1);
duplicate=a;duplicate(tick==507,2)=1;rd=pmsm_current_sampling_metrics(fixture(truth,hold,feedback,duplicate,t),window);
assert(rd.adc.intervals.trigger_to_JEOS.paired_count==9&&rd.adc.intervals.trigger_to_JEOS.ambiguous_count==1);
reject(@()pmsm_current_sampling_metrics(out,[-.001 .001]));
reject(@()pmsm_current_sampling_metrics(out,[.0005011 .0005012]));
broken=out;broken.obs_adc_timing=timeseries(a(1:2:end,:),t(1:2:end));reject(@()pmsm_current_sampling_metrics(broken,window));
% Reanalyse the existing desktop demonstration; no new simulation is needed.
source=fullfile(root,'.build','current_sampling_preview.mat');assert(isfile(source));hash=teach_hash(source);
data=load(source,'outSamplingDemo','provenanceSamplingDemo');real=pmsm_current_sampling_metrics(data.outSamplingDemo);
again=pmsm_current_sampling_metrics(data.outSamplingDemo);assert(isequaln(real,again)&&strcmp(hash,teach_hash(source)));
assert(real.adc.JEOS_count>0&&real.adc.intervals.trigger_to_JEOS.available);
f=open_pmsm_sampling_metrics(real,data.provenanceSamplingDemo);
assert(isscalar(findall(f,'Tag','sampling_error_metrics'))&&isscalar(findall(f,'Tag','sampling_timing_metrics')));delete(f);
f=open_pmsm_teaching('off');assert(isscalar(findall(f,'Type','uimenu','Text','最近演示统计')));delete(f);
report=struct('passed',true,'synthetic_known_errors_and_intervals',true,'missing_events_not_zero',true, ...
 'missing_and_ambiguous_cycles_not_mispaired',true,'invalid_windows_and_grids_rejected',true, ...
 'repeat_exact',true,'source_unchanged',true,'source_sha256',hash,'actual_preview_metrics',real, ...
 'scope','Read-only statistics, synthetic calibration and existing 20ms startup preview; no new control algorithm or hardware calibration.');
teach_writejson(fullfile(teach,'current_sampling_metrics_validation.json'),report);disp('CURRENT_SAMPLING_METRICS_VALIDATED');
 function reject(fun)
  rejected=false;try,fun();catch,rejected=true;end;assert(rejected,'无效输入未被拒绝');
 end
end
function out=fixture(truth,hold,feedback,a,t)
ds=Simulink.SimulationData.Dataset;v={truth,[truth(:,1) hold feedback(:,1)],feedback,a(:,[2 6])};
for k=1:4
 sig=Simulink.SimulationData.Signal;sig.Name=sprintf('display%d',k);sig.Values=timeseries(v{k},t);ds=ds.addElement(sig);
end
out=struct('native_current_sampling_scope',ds,'obs_adc_timing',timeseries(a,t));
end
