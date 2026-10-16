function finalize_teaching_reports
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);addpath(fullfile(root,'teaching'));
work=fullfile(root,'.build','deadtime_demo');names={'ideal','dead','comp'};
for k=1:3
 s=load(fullfile(work,[names{k} '.mat']),'o');
 for key=s.o.who',value=s.o.get(key{1});if isa(value,'timeseries'),assert(all(isfinite(value.Data),'all')&&all(isfinite(value.Time)));end,end
end
% Saved data here is the last 300rpm/0.08Nm run; do not rerun or relabel it.
low=jsondecode(fileread(fullfile(folder,'report_low_speed','record.json')));assert(low.rpm==300&&low.load_Nm==.08&&low.dead_us==2);
low.compensation_improved_THD=low.cases.comp.low_order_THD_percent<low.cases.dead.low_order_THD_percent;
low.interpretation='Boundary example: basic polarity compensation worsens low-order THD at this light-load, enlarged-deadtime operating point.';
plot_deadtime_report(work,fullfile(folder,'report_low_speed'),2,300,.08);plot_three_phase_lesson(work,fullfile(folder,'report_low_speed'),2,300,.08);
teach_writejson(fullfile(folder,'report_low_speed','record.json'),low);
normal=jsondecode(fileread(fullfile(folder,'report_teaching','record.json')));assert(normal.rpm==600&&normal.dead_us==2);
normal.compensation_improved_THD=normal.cases.comp.low_order_THD_percent<normal.cases.dead.low_order_THD_percent;teach_writejson(fullfile(folder,'report_teaching','record.json'),normal);
record=struct('all_passed',true,'pi_retuned',false,'model_sha256',teach_hash(fullfile(root,'PMSM_FOC_R2026a.slx')), ...
 'teaching',normal.cases,'low_speed_boundary',low.cases,'low_speed_logs_finite',true,'low_speed_compensation_improved',low.compensation_improved_THD, ...
 'note','Passing checks means demonstration data and settings are valid, not that compensation always improves THD.');
teach_writejson(fullfile(folder,'teaching_reports_results.json'),record);fprintf('TEACHING_REPORT_REVIEW_PASS\n');
end
