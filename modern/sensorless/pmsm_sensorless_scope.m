function result=pmsm_sensorless_scope(action,scope)
% Native observation only; does not select feedback or run a simulation.
if nargin<1,action='open';end
if nargin<2,scope='PMSM_FOC_R2026a/无感观测/观测/角度与速度';end
assert(getSimulinkBlockHandle(scope)>0,'先打开无感观测。');
result=scope;
if strcmp(action,'open')
 callback=get_param(scope,'OpenFcn');dirty=get_param(bdroot(scope),'Dirty');
 set_param(scope,'OpenFcn','');guard=onCleanup(@()restore(scope,callback,dirty));
 open_system(scope);drawnow;
end
blue=[0 .447 .741];red=[.84 .15 .16];gray=[.5 .5 .5];
if endsWith(scope,'/角度与速度')
 colors=[gray;blue;gray;blue;red;blue;gray;red];
 lines={'--','-','--','-','-','-','-','-'};
else
 colors=[gray;blue;gray;blue;blue;red;red;blue;blue];
 lines={'--','-','--','-','-','-','-','-','-'};
end
style=struct('BackgroundColor',[1 1 1],'AxesColor',[1 1 1],'LabelsColor',[0 0 0],...
 'LineWidth',1.5,'LineColor',colors,'LineStyle',{lines});
viewer=get_param(scope,'BlockCOSI');client=viewer.ClientID;
message.publish(['/webscope' client],struct('action',['setScopeStyleSettings' client],...
 'params',jsonencode(struct('Style',style))));drawnow;
end
function restore(scope,callback,dirty)
if getSimulinkBlockHandle(scope)>0,set_param(scope,'OpenFcn',callback);set_param(bdroot(scope),'Dirty',dirty);end
end
