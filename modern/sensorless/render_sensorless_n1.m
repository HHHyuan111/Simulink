function render_sensorless_n1(folder)
% Figures read archived component signals; never simulate or change the model.
here=fileparts(mfilename('fullpath'));addpath(fullfile(fileparts(here),'teaching'));
record=jsondecode(fileread(fullfile(folder,'record.json')));assert(strcmp(record.status,'passed'));
assert(strcmp(record.raw_sha256,teach_hash(fullfile(folder,'raw.mat'))));
metrics=jsondecode(fileread(fullfile(folder,'metrics.json')));load(fullfile(folder,'raw.mat'),'raw');
out=fullfile(here,'milestones','N1');if ~isfolder(out),mkdir(out);end
gray=[.5 .5 .5];blue=[0 .447 .741];red=[.84 .15 .16];
[~,index]=max([metrics.pll.capture_s]);data=raw.pll{index};caseInfo=metrics.pll(index);
t=data(:,1);win=t<=.08;trueAngle=mod(2*pi*caseInfo.frequency_Hz*t,2*pi)*180/pi;
speed=data(:,3)/5*60/(2*pi);target=caseInfo.frequency_Hz/5*60;
f=figure('Visible','off','Color','w','Position',[100 100 1100 680]);
layout=tiledlayout(f,2,2,'TileSpacing','compact','Padding','compact');title(layout,'PLL组件');
nexttile;plot(t(win)*1e3,trueAngle(win),'--','Color',gray,'LineWidth',1.2);hold on;
plot(t(win)*1e3,data(win,2)*180/pi,'Color',blue,'LineWidth',1.2);ylabel('电角度 [°]');title('电角度');legend('输入','估计');grid on;
nexttile;plot(t(win)*1e3,data(win,4),'Color',red,'LineWidth',1.2);ylabel('误差 [°]');title('角度误差');grid on;
nexttile;plot(t(win)*1e3,target*ones(sum(win),1),'--','Color',gray,'LineWidth',1.2);hold on;
plot(t(win)*1e3,speed(win),'Color',blue,'LineWidth',1.2);ylabel('转速 [rpm]');title('转速');legend('输入','估计');grid on;
nexttile;plot(t(win)*1e3,data(win,5),'Color',blue,'LineWidth',1.2);ylabel('电角速度 [rad/s]');title('PLL积分');grid on;
for ax=findall(f,'Type','axes')',xlabel(ax,'时间 [ms]');end
pmsm_plot_style(f);exportgraphics(f,fullfile(out,'pll_component.png'),'Resolution',160);close(f);
data=raw.state.validity_trace;t=data(:,1)*1e3;
f=figure('Visible','off','Color','w','Position',[100 100 1100 680]);
layout=tiledlayout(f,2,2,'TileSpacing','compact','Padding','compact');title(layout,'状态与复位');
nexttile;stairs(t,data(:,2),'Color',blue,'LineWidth',1.3);ylim([-.1 1.1]);ylabel('有效标志');title('有效');grid on;
nexttile;stairs(t,data(:,3),'Color',blue,'LineWidth',1.3);ylim([-.1 3.1]);ylabel('状态编号');title('状态');grid on;
nexttile;stairs(t,data(:,4),'Color',blue,'LineWidth',1.3);hold on;stairs(t,data(:,5),'--','Color',gray,'LineWidth',1.2);ylabel('样本数');title('锁定与历史');legend('连续锁定','历史样本');grid on;
nexttile;plot(t,data(:,6),'Color',blue,'LineWidth',1.3);ylabel('电角速度 [rad/s]');title('PLL积分');grid on;
for ax=findall(f,'Type','axes')',xlabel(ax,'时间 [ms]');end
pmsm_plot_style(f);exportgraphics(f,fullfile(out,'state_semantics.png'),'Resolution',160);close(f);
provenance=struct('source_folder',folder,'raw_sha256',record.raw_sha256,'pll_case',caseInfo,...
 'plot_source_sha256',teach_hash(fullfile(here,'render_sensorless_n1.m')),'data_modified',false);
teach_writejson(fullfile(out,'figure_provenance.json'),provenance);
fprintf('N1_FIGURES_EXPORTED %s\n',out);
end
