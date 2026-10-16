function pmsm_startup_scope_style(scope)
% Native web Scope applies channel styles reliably after the first data run.
if getSimulinkBlockHandle(scope)<0,return;end
drawnow;blue=[0 .447 .741];red=[.84 .15 .16];gray=[.5 .5 .5];
style=struct('BackgroundColor',[1 1 1],'AxesColor',[1 1 1],'LabelsColor',[0 0 0],...
 'LineWidth',1.5,'LineColor',[blue;blue;red;gray;blue;blue;red],...
 'LineStyle',{{'-','-','-','--','-','-','-'}});
viewer=get_param(scope,'BlockCOSI');id=viewer.ClientID;
message.publish(['/webscope' id],struct('action',['setScopeStyleSettings' id],'params',jsonencode(struct('Style',style))));drawnow;
end
