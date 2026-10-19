function render_sensorless_direct
% Plot this direct-model run, including startup and the fixed steady window.
base=sensorless_direct_setup;folder=fullfile(base,'runs','SMO_direct_first');
r=jsondecode(fileread(fullfile(folder,'report.json')));assert(strcmp(r.phase,'completed'));
raw=fullfile(folder,'signals.mat');assert(strcmp(teach_hash(raw),r.raw_sha256));
s=load(raw,'obs_sless_v2_theta','obs_sless_v2_truth_theta','obs_sless_v2_speed','obs_sless_v2_truth_speed','obs_sless_direct_completed');
t=s.obs_sless_v2_theta.Time;theta=teach_values(s.obs_sless_v2_theta);truth=teach_values(s.obs_sless_v2_truth_theta);
speed=teach_values(s.obs_sless_v2_speed);actual=teach_values(s.obs_sless_v2_truth_speed);
error=atan2(sin(theta-truth),cos(theta-truth))*180/pi;p=teach_values(s.obs_sless_direct_completed);
output=fullfile(base,'milestones','SMO_direct');if ~isfolder(output),mkdir(output);end
fig=figure('Visible','off','Position',[100 100 1050 850]);cleanup=onCleanup(@()close(fig)); %#ok<NASGU>
tiledlayout(4,1,'TileSpacing','compact');
nexttile;plot(t,actual,'Color',[.35 .35 .35]);hold on;plot(t,speed,'Color',[0 .45 .74]);grid on;ylabel('Speed [rpm]');legend('Plant','SMO/PLL','Location','southeast');xlim([0 .25]);title('Direct local-model SMO: actual new run, startup included');
nexttile;plot(t,error);grid on;ylabel('Angle error [deg]');xlim([0 .25]);
nexttile;use=t>=.162&t<=.25;plot(t(use),error(use));grid on;ylabel('Angle error [deg]');xlim([.162 .25]);title('Fixed steady window: 0.162 to 0.25 s');
nexttile;stairs(s.obs_sless_direct_completed.Time,p(:,14));grid on;ylim([-.1 1.1]);xlim([0 .25]);ylabel('Published permit');xlabel('Time [s]');
exportgraphics(fig,fullfile(output,'convergence.png'),'Resolution',150);
teach_writejson(fullfile(output,'plot_source.json'),struct('raw_sha256',r.raw_sha256,'model_sha256',r.model_sha256,'historical_data',false));
end
