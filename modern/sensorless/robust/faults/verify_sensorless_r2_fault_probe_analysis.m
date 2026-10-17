function report=verify_sensorless_r2_fault_probe_analysis(folder)
% Analysis-only negative control: a1ms trace cannot prove a600ms fault.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);
addpath(base,fileparts(here),here,fullfile(modern,'teaching'),fullfile(base,'robust/performance'));
record=jsondecode(fileread(fullfile(folder,'record.json')));assert(strcmp(record.case_id,'deadline_jitter'));
assert(strcmp(record.raw_sha256,teach_hash(fullfile(folder,'signals.mat'))));
plan=jsondecode(fileread(fullfile(base,'contracts/nonideal_r2_test_plan.json')));cases=plan.cases;if ~iscell(cases),cases=num2cell(cases);end
testcase=cases{find(cellfun(@(x)strcmp(x.id,'deadline_jitter'),cases))};s=load(fullfile(folder,'signals.mat'));
m=analyse_sensorless_r2_fault(s,testcase);assert(~m.all_passed&&~m.checks.first_native_veto&&~m.checks.recovered&&~m.checks.jitter_applied);
assert(m.checks.event_counter_audit&&m.checks.packet_reference_and_completion&&m.checks.all_frames_captured);
assert(m.pwm.checks.exact_write_ticks&&m.pwm.checks.exact_update_ticks&&m.pwm.checks.all_uev_observed);
report=struct('all_passed',true,'analysis_only',true,'negative_control',true,'full_fault_claim_rejected',true,'metrics',m);
teach_writejson(fullfile(folder,'short_negative_control.json'),report);
end
