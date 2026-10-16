function pmsm_scope_theme(path,afterRun)
% A common window and native web style for OLD and new Scope blocks.
if nargin<2,afterRun=false;end
if getSimulinkBlockHandle(path)<0,return;end
if afterRun
 try,if ~strcmp(get_param(path,'Open'),'on'),return;end;catch,return;end
end
c=get_param(path,'ScopeConfiguration');c.Position=[80 60 1120 800];
tag=get_param(path,'Tag');kind='';
switch tag
 case 'PMSMNativeDeadtimeCompScope',kind='deadtime_compensation';
 case 'PMSMNativeDeadtimeEffectsScope',kind='deadtime_effects';
 case 'PMSMNativeDeadtimeScope',kind='deadtime';
 case 'PMSMNativeControlScope',kind='control';
 case 'PMSMNativeElectricalScope',kind='electrical';
 case 'PMSMNativePWMScope',kind='pwm';
 case 'PMSMNativeCurrentSamplingScope',kind='current_sampling';
end
if ~isempty(kind),pmsm_scope_style(path,kind);return;end
if endsWith(path,'/启停/启停观测'),pmsm_startup_scope_style(path);return;end
% Extra palette entries permit vector signals whose widths are known only
% after the first run. Native Scope uses the entries for existing channels.
blue=[0 .447 .741];red=[.84 .15 .16];gray=[.5 .5 .5];
colors=repmat([blue;red;gray],32,1);lines=repmat({'-','-','--'},1,32);
style=struct('BackgroundColor',[1 1 1],'AxesColor',[1 1 1],'LabelsColor',[0 0 0],...
 'LineWidth',1.5,'LineColor',colors,'LineStyle',{lines});
drawnow;viewer=get_param(path,'BlockCOSI');id=viewer.ClientID;
message.publish(['/webscope' id],struct('action',['setScopeStyleSettings' id],'params',jsonencode(struct('Style',style))));drawnow;
end
