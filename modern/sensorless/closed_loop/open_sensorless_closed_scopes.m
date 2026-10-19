function open_sensorless_closed_scopes(mdl)
% Presentation of actual native Scope buffers; no replacement plots/data.
if nargin<1,mdl='PMSM_SMO_ClosedLoop';end
dirty=get_param(mdl,'Dirty');restore=onCleanup(@()set_param(mdl,'Dirty',dirty)); %#ok<NASGU>
names={'闭环稳态','闭环全过程'};
blue=[0 .447 .741];red=[.84 .15 .16];gray=[.35 .35 .35];green=[0 .55 .25];
style=struct('BackgroundColor',[1 1 1],'AxesColor',[1 1 1],'LabelsColor',[0 0 0],...
 'LineWidth',1.3,'LineColor',[gray;blue;red;blue;green;red;blue;red;green],...
 'LineStyle',{{'-','--',':','-','--','-','-','-','-'}});
for k=1:numel(names)
 path=[mdl '/闭环结果观测/' names{k}];open_system(path);drawnow;
 config=get_param(path,'ScopeConfiguration');config.Position=[80 60 1360 900];
 config.DataLoggingLimitDataPoints=false;config.DataLoggingDecimateData=false;
 config.TimeUnits='Seconds';config.TimeDisplayOffset='0';config.MaximizeAxes='Off';
 for a=1:4,config.ActiveDisplay=num2str(a);config.AxesScaling='Auto';end
 config.ActiveDisplay='1';
 viewer=get_param(path,'BlockCOSI');client=viewer.ClientID;
 message.publish(['/webscope' client],struct('action',['setScopeStyleSettings' client],...
  'params',jsonencode(struct('Style',style))));drawnow;
end
end
