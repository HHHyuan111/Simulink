function report=validate_pmsm_presentation
% Representative numeric comparisons plus complete model restoration and GUI checks.
here=fileparts(mfilename('fullpath'));root=fileparts(fileparts(here));
addpath(root,here,fullfile(root,'teaching'),fullfile(root,'framework'));
mdl='PMSM_FOC_R2026a';assert(~bdIsLoaded(mdl),'请在独立MATLAB进程验证，避免影响正在使用的会话。');
load_system(fullfile(root,[mdl '.slx']));pmsm_reference('restore');
before=teach_snapshot(mdl);hash=teach_hash(fullfile(root,[mdl '.slx']));
cleanup=onCleanup(@()close_system(mdl,0));
inputs=cell(1,3);raw=cell(1,3);names={'ideal','sampling_chain','event_sampling'};
for k=1:3
 in=Simulink.SimulationInput(mdl);in=in.setModelParameter('StopTime','.02');
 if k>=2
  for key={'bias_on','gain_on','noise_on','adc_on','filter_on','delay_on','analog_on'},in=in.setBlockParameter([mdl '/采样设置'],key{1},'on');end
 end
 if k==3,in=in.setBlockParameter([mdl '/采样设置'],'delay_on','off');in=in.setBlockParameter([mdl '/时序设置'],'real_on','on');in=in.setModelParameter('StopTime','.005');end
 inputs{k}=in;raw{k}=sim(in);
end
style=pmsm_presentation('apply',mdl);checks=struct('case',{},'signal',{},'time_equal',{},'data_equal',{});
for k=1:3
 out=sim(inputs{k});signals=intersect(raw{k}.who,out.who);
 for j=1:numel(signals)
  a=raw{k}.get(signals{j});b=out.get(signals{j});if ~isa(a,'timeseries'),continue;end
  checks(end+1)=struct('case',names{k},'signal',signals{j},'time_equal',isequaln(a.Time,b.Time),'data_equal',isequaln(a.Data,b.Data));
 end
end
assert(numel(checks)>=30&&all([checks.time_equal])&&all([checks.data_equal]),'布局前后原始信号不一致。');
teach_writejson(fullfile(here,'numeric_checks.json'),checks);
print(['-s' mdl],'-dpng','-r100',fullfile(here,'model.png'));
print(['-s' mdl '/采样设置'],'-dpng','-r100',fullfile(here,'sampling.png'));
for name={'PI观测','角度设置','输出延迟'},print(['-s' mdl '/' name{1}],'-dpng','-r100',fullfile(here,[name{1} '.png']));end
pmsm_presentation('remove',mdl);teach_writejson(fullfile(root,'.build','view_before.json'),before);teach_writejson(fullfile(root,'.build','view_after.json'),teach_snapshot(mdl));assert(isequaln(before,teach_snapshot(mdl)),'还原后模型快照不一致。');pmsm_reference('restore');
% Reference action wrapper must be reversible, including on exceptions.
pmsm_presentation('apply',mdl);pmsm_presented_call(@pmsm_reference,'restore');assert(pmsm_presentation('installed'));
try,pmsm_presented_call(@()error('pmsm:TestFailure','intentional'));catch err,assert(strcmp(err.identifier,'pmsm:TestFailure'));end
assert(pmsm_presentation('installed'));pmsm_presentation('remove');assert(isequaln(before,teach_snapshot(mdl)));
f=open_pmsm_experiments;uiCleanup=onCleanup(@()delete(f));
selector=findobj(f,'Tag','ExperimentSelector');catalog=pmsm_experiment_catalog;
for k=1:numel(catalog)
 selector.Value=k;selector.Callback([],[]);drawnow;
 edits=findall(f,'Style','edit','Visible','on');assert(all([edits.FontSize]>=14));
end
f.Position=[100 80 1300 900];drawnow;assert(all(findall(f,'Tag','ExperimentValue').Position>0));
clear uiCleanup
g=open_pmsm_framework('off');assert(numel(findall(g,'Type','uibutton'))==6);delete(g);
c=open_pmsm_controls('采样设置');ct=findall(c,'Type','uitable');assert(size(ct.Data,1)>=15&&ct.FontSize>=16);delete(c);
latest=jsondecode(fileread(fullfile(root,'framework','latest.json')));verify_pmsm_system_baseline(latest.folder);
report=struct('schema',1,'passed',true,'model_sha256',hash,'model_file_unchanged',strcmp(hash,teach_hash(fullfile(root,[mdl '.slx']))), ...
 'restored_snapshot_equal',true,'fixed_reference_verified',true,'numeric_checks',checks,'presentation',style,'experiment_selectors_checked',numel(catalog));
assert(report.model_file_unchanged);teach_writejson(fullfile(here,'validation.json'),report);disp('PRESENTATION_VALIDATED');
end
