function report=validate_pmsm_presentation_ui
% Fast UI regression, independent of the numerical experiment reruns.
here=fileparts(mfilename('fullpath'));root=fileparts(fileparts(here));addpath(root,here,fullfile(root,'teaching'),fullfile(root,'framework'));
load_system(fullfile(root,'PMSM_FOC_R2026a.slx'));
f=open_pmsm_experiments;cleanup=onCleanup(@()delete(f));selector=findobj(f,'Tag','ExperimentSelector');c=pmsm_experiment_catalog;
for k=1:numel(c)
 selector.Value=k;selector.Callback([],[]);f.SizeChangedFcn([],[]);drawnow;
 value=findobj(f,'Tag','ExperimentValue');assert(~isempty(value.String));
end
for sz={[1040 780],[1320 900]}
 f.Position=[100 80 sz{1}];f.SizeChangedFcn([],[]);drawnow;
 assert(findobj(f,'Tag','ExperimentValue').Position(3)>=235);
end
delete(f);clear cleanup
for section={'采样设置','角度设置','功率设置','时序设置'}
 p=open_pmsm_controls(section{1});selector=findall(p,'Type','uidropdown');assert(strcmp(selector.Value,section{1}));t=findall(p,'Type','uitable');assert(~isempty(t.Data)&&t.FontSize>=16);
 sw=findall(p,'Type','uiswitch');assert(isscalar(sw));
 row=find(ismember(t.Data(:,2),{'on','off'}),1);t.CellSelectionCallback(t,struct('Indices',[row 2]));old=t.Data{row,2};
 if strcmp(old,'off'),sw.Value='on';else,sw.Value='off';end
 sw.ValueChangedFcn(sw,[]);assert(strcmp(t.Data{row,2},sw.Value));delete(p);
end
f=open_pmsm_framework('off');assert(numel(findall(f,'Type','uibutton'))==6);delete(f);
report=struct('passed',true,'scenes',numel(c),'sizes_checked',2,'parameter_sections_checked',4, ...
 'experiment_ui_sha256',teach_hash(fullfile(root,'teaching','open_pmsm_experiments.m')), ...
 'framework_ui_sha256',teach_hash(fullfile(root,'framework','open_pmsm_framework.m')), ...
 'controls_ui_sha256',teach_hash(fullfile(here,'open_pmsm_controls.m')));
teach_writejson(fullfile(here,'ui_validation.json'),report);
if isfile(fullfile(here,'validation.json')),r=jsondecode(fileread(fullfile(here,'validation.json')));r.ui_validation=report;teach_writejson(fullfile(here,'validation.json'),r);end
close_system('PMSM_FOC_R2026a',0);disp('PRESENTATION_UI_VALIDATED');
end
