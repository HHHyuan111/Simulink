function pmsm_scope_open(path)
% Apply the same style even when learners double-click an old Scope.
if endsWith(path,'/跟踪观测/总览')&&pmsm_native_scope('installed')
 pmsm_native_scope('open');return;
end
callback=get_param(path,'OpenFcn');dirty=get_param(bdroot(path),'Dirty');set_param(path,'OpenFcn','');
guard=onCleanup(@()restore(path,callback,dirty));open_system(path);pmsm_scope_theme(path);
end
function restore(path,callback,dirty)
if getSimulinkBlockHandle(path)>0,set_param(path,'OpenFcn',callback);set_param(bdroot(path),'Dirty',dirty);end
end
