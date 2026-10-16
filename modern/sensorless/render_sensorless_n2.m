function render_sensorless_n2(folder)
% Read archived full-rate data. Plot reductions never enter acceptance checks.
here=fileparts(mfilename('fullpath'));addpath(fullfile(fileparts(here),'teaching'));
record=jsondecode(fileread(fullfile(folder,'record.json')));
assert(strcmp(record.status,'passed'),'Only render an accepted numerical run.');
for id={'reference_enabled','events_enabled'}
 row=record.cases(strcmp({record.cases.id},id{1}));
 assert(strcmp(row.sha256,teach_hash(fullfile(folder,row.file))));
 raw=load(fullfile(folder,row.file),'signals');s=raw.signals;
 t=s.obs_sless_theta.Time*1000;theta=teach_values(s.obs_sless_theta)*180/pi;
 truth=teach_values(s.obs_sless_truth_theta)*180/pi;
 fig=figure('Visible','off','Color','w','Position',[100 100 1400 900]);
 cleanup=onCleanup(@()close(fig));tl=tiledlayout(2,2,'TileSpacing','compact');
 title(tl,[strrep(id{1},'_',' ') ' | N2 integration, not N3 accuracy acceptance']);
 nexttile;plot(t,truth,'--','Color',[.5 .5 .5]);hold on;plot(t,theta,'Color',[0 .447 .741]);
 ylabel('Electrical angle (deg)');legend('Truth: evaluation only','SMO + PLL','Location','best');grid on;
 nexttile;plot(t,teach_values(s.obs_sless_truth_speed),'--','Color',[.5 .5 .5]);hold on;
 plot(t,teach_values(s.obs_sless_speed),'Color',[0 .447 .741]);ylabel('Speed (rpm)');grid on;
 nexttile;plot(t,teach_values(s.obs_sless_angle_error)*180/pi,'Color',[.84 .15 .16]);
 ylabel('Wrapped angle error (deg)');xlabel('Time (ms)');grid on;
 nexttile;stairs(t,teach_values(s.obs_sless_valid),'Color',[0 .447 .741]);hold on;
 stairs(t,teach_values(s.obs_sless_state),'Color',[.5 .5 .5]);
 stairs(t,teach_values(s.obs_sless_pll_saturated),'Color',[.84 .15 .16]);
 legend('Valid','State','PLL saturated','Location','best');xlabel('Time (ms)');grid on;
 exportgraphics(fig,fullfile(folder,[id{1} '_overview.png']),'Resolution',140);
 clear cleanup;
 fig=figure('Visible','off','Color','w','Position',[100 100 1400 1050]);
 cleanup=onCleanup(@()close(fig));tl=tiledlayout(3,2,'TileSpacing','compact');
 title(tl,[strrep(id{1},'_',' ') ' | archived observer internals']);
 measured=teach_values(s.obs_sless_input_i);estimated=teach_values(s.obs_sless_i_hat);
 for channel=1:2
  nexttile;plot(t,measured(:,channel),'--','Color',[.5 .5 .5]);hold on;
  plot(t,estimated(:,channel),'Color',[0 .447 .741]);ylabel(sprintf('i_%d (A)',channel));grid on;
 end
 nexttile;plot(t,teach_values(s.obs_sless_emf));ylabel('EMF alpha/beta (V)');grid on;
 nexttile;plot(t,teach_values(s.obs_sless_pll_error),'Color',[.84 .15 .16]);ylabel('PLL phase detector');grid on;
 nexttile;plot(t,teach_values(s.obs_sless_pll_integral),'Color',[0 .447 .741]);ylabel('PLL integral (rad/s)');xlabel('Time (ms)');grid on;
 nexttile;plot(t,teach_values(s.obs_sless_phase_correction)*180/pi,'Color',[0 .447 .741]);ylabel('Phase correction (deg)');xlabel('Time (ms)');grid on;
 exportgraphics(fig,fullfile(folder,[id{1} '_internal.png']),'Resolution',140);
 clear cleanup;
end
end
