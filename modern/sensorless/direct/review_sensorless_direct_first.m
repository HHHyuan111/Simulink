function result=review_sensorless_direct_first
% Correct the non-overlapping rolling-log baseline using equal-duration data.
base=sensorless_direct_setup;folder=fullfile(base,'runs','SMO_direct_first');
first=jsondecode(fileread(fullfile(folder,'report.json')));metrics=jsondecode(fileread(fullfile(folder,'metrics.json')));
control=jsondecode(fileread(fullfile(base,'runs','SMO_direct_baseline','report.json')));
assert(control.passed&&strcmp(first.phase,'completed')&&first.metrics_passed&&metrics.passed);
assert(strcmp(control.source_direct_model_sha256,first.model_sha256));
signals=load(fullfile(folder,'signals.mat'));original=check_sensorless_direct_original(signals,.25);
result=struct('analysis_only',true,'simulation_reexecuted',false,...
 'correction','Old 0.8s gate logs retain only final4000 native points and have no overlap with new0.25s; use same0.25s baseline',...
 'original_first_report_sha256',teach_hash(fullfile(folder,'report.json')),...
 'first_raw_sha256',first.raw_sha256,'control_raw_sha256',control.raw_sha256,...
 'model_sha256',first.model_sha256,'original_control_unchanged',original.passed,...
 'metrics_passed',metrics.passed,'passed',metrics.passed&&original.passed);
teach_writejson(fullfile(folder,'original52_equal_duration.json'),original);
teach_writejson(fullfile(folder,'review.json'),result);
end
