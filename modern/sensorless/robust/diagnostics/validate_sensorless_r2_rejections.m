function report=validate_sensorless_r2_rejections(folder)
% Prevent unsupported physical cases from receiving generic pass results.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));
addpath(fullfile(base,'robust','performance'),fullfile(fileparts(base),'teaching'));
assert(~isfolder(folder));mkdir(folder);assert(~bdIsLoaded('PMSM_FOC_R2026a'));
cases={'adc_clipping','combined_dynamic','hot_R1p2_L0p8','deadtime_2us','missing_five','reset_one','deadline_jitter','low_speed_stop'};
report=struct('kind','unsupported_case_rejection_check','pmsm_loaded',false,...
 'simulation_called',false,'all_passed',false,'source_sha256',teach_hash(fullfile(base,'robust','performance','validate_sensorless_r2_case.m')));
for k=1:numel(cases)
 rejected=false;message='';
 try
  validate_sensorless_r2_case(cases{k},fullfile(folder,cases{k}));
 catch err
  message=err.message;
  rejected=contains(message,'R2 diagnostic worker only supports')||contains(message,'R2 first diagnostic worker has no fault/plant-variation adapter yet.');
 end
 assert(rejected&&~bdIsLoaded('PMSM_FOC_R2026a'),'Unsupported case was not rejected before model load.');
 report.cases(k)=struct('id',cases{k},'rejected_before_load',true,'message',message);
end
report.all_passed=true;teach_writejson(fullfile(folder,'report.json'),report);
fprintf('R2_UNSUPPORTED_CASES_REJECTED count=%d no_model_load=1\n',numel(cases));
end
