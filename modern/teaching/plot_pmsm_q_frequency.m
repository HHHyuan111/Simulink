function fig=plot_pmsm_q_frequency(p,r)
fig=plot_pmsm_current_frequency(p,r);fig.Name='q轴电流环频率响应';
layout=fig.Children;assert(numel(layout)==1&&isa(layout,'matlab.graphics.layout.TiledChartLayout'));
title(layout,'q轴电流环频率响应','FontSize',14,'FontWeight','normal');
end
