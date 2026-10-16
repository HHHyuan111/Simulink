function report=validate_pmsm_experiment_reproducibility
% Replay all completed default experiments in an isolated process.
here=fileparts(mfilename('fullpath'));root=fileparts(here);mdl='PMSM_FOC_R2026a';assert(~bdIsLoaded(mdl));
work=fullfile(root,'.build',['repeat_check_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);mkdir(work);
old=pwd;cg=onCleanup(@()cd(old));cd(work);addpath(here);candidate=fullfile(work,[mdl '.slx']);copyfile(fullfile(root,[mdl '.slx']),candidate);
load_system(candidate);mg=onCleanup(@()close_system(mdl,0));pmsm_reference('restore');before=pmsm_reference('capture');geometry=teach_snapshot(mdl);
sources=jsondecode(fileread(fullfile(here,'experiment_stage2_validation.json')));assert(sources.all_passed);
pairFile=fullfile(here,'experiment_paired_deadtime_validation.json');assert(isfile(pairFile),'先完成死区配对验证。');
pair=jsondecode(fileread(pairFile));assert(pair.all_passed);sources.run_folders.gate_deadtime_pair=pair.run_folders.default_pair;
low=jsondecode(fileread(fullfile(here,'experiment_low_speed_comp_validation.json')));assert(low.all_passed);sources.run_folders.low_speed_compensation=low.run_folders.default_three;
noise=jsondecode(fileread(fullfile(here,'experiment_noise_filter_validation.json')));assert(noise.all_passed);sources.run_folders.noise_filter=noise.run_folders.default_three;
timing=jsondecode(fileread(fullfile(here,'experiment_timing_events_validation.json')));assert(timing.all_passed);sources.run_folders.timing_events=timing.run_folders.default_pair;
deadline=jsondecode(fileread(fullfile(here,'experiment_timing_deadline_validation.json')));assert(deadline.all_passed);sources.run_folders.timing_deadline=deadline.run_folders.default_three;
window=jsondecode(fileread(fullfile(here,'experiment_sampling_window_validation.json')));assert(window.all_passed);sources.run_folders.sampling_window=window.run_folders.default_three;
encoder=jsondecode(fileread(fullfile(here,'experiment_encoder_validation.json')));assert(encoder.all_passed);sources.run_folders.encoder_angle=encoder.run_folders.default_three;
speed=jsondecode(fileread(fullfile(here,'experiment_encoder_speed_validation.json')));assert(speed.all_passed);sources.run_folders.encoder_speed=speed.run_folders.default_parallel;
feedback=jsondecode(fileread(fullfile(here,'experiment_speed_feedback_validation.json')));assert(feedback.all_passed);sources.run_folders.speed_feedback=feedback.run_folders.default_three;
speedFilter=jsondecode(fileread(fullfile(here,'experiment_speed_filter_validation.json')));assert(speedFilter.all_passed);sources.run_folders.speed_filter=speedFilter.run_folders.default_pair;
report=struct('all_passed',false,'matlab_version',version,'model_sha256',teach_hash(fullfile(root,[mdl '.slx'])), ...
 'reference_manifest_sha256',teach_hash(fullfile(here,'reference_v1','manifest.json')), ...
 'scope','当前默认实验按原档案重跑；逐点比较每组实际保留的Time/Data。', ...
 'run_folders',struct,'results',struct);
for scenario=pmsm_experiment_catalog
 fprintf('REPRODUCIBILITY %s\n',scenario.id);
 [r,v]=repeat_pmsm_experiment(sources.run_folders.(scenario.id));
 report.run_folders.(scenario.id)=r.folder;report.results.(scenario.id)=v;
 assert(v.same_matlab_version&&v.all_exact,'实验未逐点复现：%s',scenario.id);
end
assert(isequaln(before,pmsm_reference('capture'))&&isequaln(geometry,teach_snapshot(mdl)));
pmsm_reference('verify');assert(strcmp(report.model_sha256,teach_hash(fullfile(root,[mdl '.slx']))));
report.main_reference_pi_and_layout_unchanged=true;report.all_passed=true;
teach_writejson(fullfile(here,'experiment_reproducibility_validation.json'),report);
fprintf('ALL_CURRENT_EXPERIMENTS_EXACT\n');
end
