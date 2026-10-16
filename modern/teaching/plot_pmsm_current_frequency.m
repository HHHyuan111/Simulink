function fig=plot_pmsm_current_frequency(p,r)
fig=figure('Name','电流环频率响应','NumberTitle','off','Color','white','Units','pixels','Position',[80 60 1120 800]);
t=tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');colors=[0 .447 .741;.84 .15 .16];
titles={'闭环幅频','闭环相频','环路增益','环路相位'};units={'增益 [dB]','相位 [°]','增益 [dB]','相位 [°]'};
for k=1:4
 ax=nexttile(t,k);hold(ax,'on');
 for c=1:numel(r)
  if k<=2,h=r(c).T;else,h=r(c).L;end
  if mod(k,2),y=20*log10(abs(h));else,y=unwrap(angle(h))*180/pi;end
  y(~r(c).valid)=NaN;semilogx(ax,p.frequency_Hz,y,'-o','Color',colors(c,:),'LineWidth',1.4,'MarkerSize',4,'DisplayName',r(c).label);
 end
 if k==1,yline(ax,-3,'--','Color',[.5 .5 .5],'HandleVisibility','off');elseif k==3,yline(ax,0,'--','Color',[.5 .5 .5],'HandleVisibility','off');elseif k==4,yline(ax,-180,'--','Color',[.5 .5 .5],'HandleVisibility','off');end
 ax.XScale='log';ax.Color='white';ax.XColor='black';ax.YColor='black';ax.FontSize=11;grid(ax,'on');title(ax,titles{k});xlabel(ax,'频率 [Hz]');ylabel(ax,units{k});legend(ax,'show','Location','best');
end
end
