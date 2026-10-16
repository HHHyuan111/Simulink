function pmsm_plot_style(f)
% Figure policy: short topic titles, necessary labels, no explanatory prose.
for ax=findall(f,'Type','axes')'
 ax.FontName='Microsoft YaHei';ax.FontSize=10;ax.Box='off';ax.TickDir='out';ax.GridAlpha=.16;
 ax.Title.FontWeight='normal';ax.Title.FontSize=12;
end
for leg=findall(f,'Type','legend')'
 leg.Location='northoutside';leg.Orientation='horizontal';leg.Box='off';leg.FontSize=9;
end
end
