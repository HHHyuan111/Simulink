function fig=plot_pmsm_speed_probe(p,responses)
fig=figure('Name','速度环频响试测','Color','white','Position',[80 60 1120 800]);
g=tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');title(g,'速度环频响试测');
T=[responses(1).fits.T_true];L=[responses(1).fits.loop];
Th=[responses(2).fits.T_true];Lh=[responses(2).fits.loop];
ys={20*log10(abs(T)),angle(T)*180/pi,20*log10(abs(L)),angle(L)*180/pi};
yh={20*log10(abs(Th)),angle(Th)*180/pi,20*log10(abs(Lh)),angle(Lh)*180/pi};
names={'闭环幅值','闭环相位','环路幅值','环路相位'};units={'dB','°','dB','°'};
for k=1:4
 ax=nexttile(g);semilogx(ax,p.frequency_Hz,ys{k},'o','Color',[0 .447 .741]);hold(ax,'on');
 semilogx(ax,p.frequency_Hz,yh{k},'x','Color',[.85 .325 .098]);grid(ax,'on');set(ax,'Color','white','FontSize',12);
 title(ax,names{k});xlabel(ax,'频率 [Hz]');ylabel(ax,units{k});legend(ax,'10 rpm','5 rpm','Location','best');
end
end
