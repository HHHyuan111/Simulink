function proof=render_sensorless_archived_short(output)
% Historical completed data only; never represent it as the new short run.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));addpath(base,fullfile(fileparts(base),'teaching'));
assert(~isfolder(output));mkdir(output);
recordPath=fullfile(base,'milestones/N3R2/followup_20261017/v4_diagnostic_combined_3000_record.json');r=jsondecode(fileread(recordPath));
raw=fullfile(r.folder,'signals.mat');assert(strcmp(teach_hash(raw),r.raw_sha256));
s=load(raw,'obs_sless_v2_theta','obs_sless_v2_truth_theta','obs_sless_v2_speed','obs_sless_v2_truth_speed','obs_sless_r2_native_events');
t=s.obs_sless_v2_theta.Time;theta=teach_values(s.obs_sless_v2_theta);truth=teach_values(s.obs_sless_v2_truth_theta);
speed=teach_values(s.obs_sless_v2_speed);actual=teach_values(s.obs_sless_v2_truth_speed);angle=atan2(sin(theta-truth),cos(theta-truth))*180/pi;
events=teach_values(s.obs_sless_r2_native_events);prefix=t<=.25;steady=t>=.162&t<=.25;ev=events(:,1)<=.25;
csv=table(t(prefix),actual(prefix),speed(prefix),angle(prefix),'VariableNames',{'reference_time_s','true_speed_rpm','estimated_speed_rpm','angle_error_deg'});writetable(csv,fullfile(output,'historical_prefix.csv'));
fig=figure('Visible','off','Position',[100 100 1050 900]);cleanup=onCleanup(@()close(fig));tiledlayout(4,1,'TileSpacing','compact');
nexttile;plot(t(prefix),actual(prefix),'Color',[.35 .35 .35]);hold on;plot(t(prefix),speed(prefix),'Color',[0 .45 .74]);ylabel('Speed [rpm]');legend('Plant','SMO/PLL','Location','southeast');grid on;xlim([0 .25]);
title('HISTORICAL completed run: first 0.25 s (NOT the new failed run)');
nexttile;plot(t(prefix),angle(prefix),'Color',[0 .45 .74]);hold on;yline(8,':');yline(-8,':');ylabel('Angle error [deg]');grid on;xlim([0 .25]);title('Full startup retained');
nexttile;plot(t(steady),angle(steady),'Color',[0 .45 .74]);ylabel('Angle error [deg]');grid on;xlim([.162 .25]);title('Historical fixed steady window: 0.162 to 0.25 s');
nexttile;stairs(events(ev,1),events(ev,3),'Color',[.1 .55 .25]);ylim([-.1 1.1]);ylabel('Permit');xlabel('Physical time [s]');grid on;xlim([0 .25]);
exportgraphics(fig,fullfile(output,'historical_convergence.png'),'Resolution',150);
proof=struct('analysis_only',true,'simulation_started',false,'historical_data_only',true,'new_short_test_passed',false,...
 'source_record_sha256',teach_hash(recordPath),'raw_sha256',r.raw_sha256,'prefix_s',[0 .25],'fixed_window_s',[.162 .25],...
 'png_sha256',teach_hash(fullfile(output,'historical_convergence.png')),'csv_sha256',teach_hash(fullfile(output,'historical_prefix.csv')),...
 'renderer_sha256',teach_hash([mfilename('fullpath') '.m']));
teach_writejson(fullfile(output,'historical_figure_provenance.json'),proof);
end
