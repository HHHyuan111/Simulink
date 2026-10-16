function f=pmsm_show_report(folder,names,titleText)
% Large, resizable tabbed reports. Interpretation stays in the documentation.
f=uifigure('Name',titleText,'Position',[100 80 1240 850]);
g=uigridlayout(f,[1 1]);g.Padding=[10 10 10 10];tabs=uitabgroup(g);
for k=1:size(names,1)
 t=uitab(tabs,'Title',names{k,2});tg=uigridlayout(t,[1 1]);tg.Padding=[0 0 0 0];
 im=uiimage(tg,'ImageSource',fullfile(folder,names{k,1}),'ScaleMethod','fit');im.Tooltip=names{k,2};
end
end
