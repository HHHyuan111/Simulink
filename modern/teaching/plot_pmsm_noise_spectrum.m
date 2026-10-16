function f=plot_pmsm_noise_spectrum(a,H,visible)
if nargin<3,visible='on';end
f=figure('Name','噪声与滤波频谱','NumberTitle','off','Color','white','Position',[80 60 1280 900], ...
 'Visible',visible,'MenuBar','figure','ToolBar','figure');
set(f,'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei','DefaultTextInterpreter','none');
tiledlayout(f,2,2,'TileSpacing','compact','Padding','compact');colors=[0 .447 .741;.84 .15 .16];
for phase=1:3
 nexttile;hold on;
 plot(a.display_frequency_Hz,10*log10(max(a.display_input_psd_A2_per_Hz(:,phase),realmin)),'Color',colors(1,:),'LineWidth',1.15);
 plot(a.display_frequency_Hz,10*log10(max(a.display_output_psd_A2_per_Hz(:,phase),realmin)),'Color',colors(2,:),'LineWidth',1.15);
 grid on;xlim([0 a.fs_Hz/2]);xlabel('频率 [Hz]');ylabel('PSD [dB re 1 A²/Hz]');
 title(sprintf('%c相噪声功率谱','A'+phase-1));legend('滤波前噪声','滤波后噪声');
end
nexttile;hold on;plot(a.frequency_Hz,20*log10(abs(H)),'Color',colors(1,:),'LineWidth',1.2);
ix=a.display_input_valid_bins(:,1);plot(a.display_frequency_Hz(ix),20*log10(max(abs(a.display_h1_estimate(ix,1)),realmin)),'--','Color',colors(2,:),'LineWidth',1.15);
grid on;xlim([0 a.fs_Hz/2]);xlabel('频率 [Hz]');ylabel('增益 [dB]');title('一阶滤波幅频');legend('系数解析','A相H1估计');
sgtitle('噪声与滤波频谱','FontSize',14);pmsm_plot_style(f);
end
