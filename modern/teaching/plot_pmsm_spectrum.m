function f=plot_pmsm_spectrum(analyses,labels,visible)
if nargin<3,visible='on';end
f=figure('Name','死区电流频谱','NumberTitle','off','Color','white','Position',[80 60 1280 900], ...
 'Visible',visible,'MenuBar','figure','ToolBar','figure');
set(f,'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei','DefaultTextInterpreter','none');
colors=[.50 .50 .50;.84 .15 .16;0 .447 .741];styles={'--','-','-'};
tiledlayout(f,2,2,'TileSpacing','compact','Padding','compact');
for phase=1:3
 nexttile;hold on;
 for k=1:numel(analyses)
  a=analyses{k};ix=a.display_frequency_Hz<=1000;
  plot(a.display_frequency_Hz(ix),20*log10(max(a.display_fft_peak_A(ix,phase),1e-8)),'Color',colors(k,:),'LineStyle',styles{k},'LineWidth',1.15);
 end
 grid on;xlim([0 1000]);ylim([-110 25]);title(sprintf('%c相电流频谱','A'+phase-1));
 xlabel('频率 [Hz]');ylabel('幅值 [dB re 1 A]');legend(labels);
end
nexttile;values=cellfun(@(a)a.harmonic_percent(2:end,1),analyses,'UniformOutput',false);
b=bar(analyses{1}.harmonic_orders(2:end),[values{:}],'grouped');
for k=1:numel(b),b(k).FaceColor=colors(k,:);b(k).EdgeColor='none';end
grid on;xticks(2:2:analyses{1}.harmonic_orders(end));xlabel('谐波次数');ylabel('相对基波 [%]');title('A相同步谐波');legend(labels);
sgtitle('死区电流频谱','FontSize',14);pmsm_plot_style(f);
end
