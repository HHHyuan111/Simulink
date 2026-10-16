function pmsm_current_sampling_fit(path)
% Native Fit to View, keeping the user's time span and binary event scale.
mdl=bdroot(path);dirty=get_param(mdl,'Dirty');c=get_param(path,'ScopeConfiguration');
span=c.TimeSpan;metadata=get_param(path,'UserData');
if ~isstruct(metadata)||~isfield(metadata,'current_sampling_range_initialized')
 ws=get_param(mdl,'ModelWorkspace');bound=max(1,1.5*getVariable(ws,'Iq_limit'));
 for k=1:3,c.ActiveDisplay=num2str(k);c.YLimits=[-bound bound];c.AxesScaling='Auto';end
 set_param(path,'UserData',struct('current_sampling_range_initialized',true));
end
viewer=get_param(path,'BlockCOSI');clientID=viewer.ClientID;
% R2026a's native server handler calls onFitToView; no data modification.
message.publish(['/webscope' clientID],struct('action',['autoScale' clientID],'params',[]));drawnow;
c.TimeSpan=span;c.ActiveDisplay='4';c.AxesScaling='Manual';c.YLimits=[-.1 1.1];c.ActiveDisplay='1';
set_param(mdl,'Dirty',dirty);
end
