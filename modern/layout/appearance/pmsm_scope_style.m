function style=pmsm_scope_style(path,kind)
% Presentation only, using the R2026a native web Scope style message.
% Channel order is global across input ports (column-major displays).
blue=[0 .447 .741];red=[.84 .15 .16];gray=[.5 .5 .5];
switch kind
 case 'deadtime_compensation'
  colors=[blue;gray;gray;blue;blue;blue;red];
  lines={'-','--','--','-','-','--','-'};
 case 'deadtime_effects'
  colors=[blue;red;gray;blue;red;blue;red;blue;red];
  lines={'-','-','--','--','-','--','-','--','-'};
 case 'deadtime'
  colors=[blue;red;blue;blue;red;blue;red];
  lines={'--','-','-','--','-','--','-'};
 case 'control'
  colors=[gray;blue;gray;blue;red;blue;red;gray;blue;red];
  lines={'--','-','--','-','-','-','--','--','-','-'};
 case 'electrical'
  colors=[blue;red;gray;blue;red;blue;red;gray;blue;red];
  lines={'-','-','--','-','--','-','-','--','-','--'};
 case 'pwm'
  colors=[gray;blue;red;blue;red;blue;red;gray;blue;red];
  lines={'--','-','-','-','-','-','-','--','-','-'};
 case 'current_sampling'
  colors=[blue;red;gray;blue;gray;red;blue;red;gray;blue;red];
  lines={'-','-','--','-','--','-','-','-','--','-','-'};
 otherwise
  error('pmsm:ScopeStyle','未知观测页面：%s',kind);
end
style=struct('BackgroundColor',[1 1 1],'AxesColor',[1 1 1], ...
 'LabelsColor',[0 0 0],'LineWidth',1.5,'LineColor',colors,'LineStyle',{lines});
% This is the same native channel used by MATLAB's update_scopestyle.
% LineColor and LineStyle are accepted by the installed R2026a style handler.
viewer=get_param(path,'BlockCOSI');clientID=viewer.ClientID;
msg=struct('action',['setScopeStyleSettings' clientID], ...
 'params',jsonencode(struct('Style',style)));
message.publish(['/webscope' clientID],msg);drawnow;
end
