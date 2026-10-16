function report=pmsm_sensorless_v2_review(action,mdl)
% Presentation only. The frozen R1 installation and numerical source stay
% unchanged. No sample-time, signal, parameter, chart or workspace writes.
if nargin<1,action='open';end
if nargin<2,mdl='PMSM_FOC_R2026a';end
here=fileparts(mfilename('fullpath'));base=fileparts(here);modern=fileparts(base);
addpath(base,fullfile(base,'robust'),fullfile(base,'robust','integration'),fullfile(modern,'teaching'));
assert(ismember(action,{'open','layout'}));
if strcmp(action,'open'),open_pmsm_sensorless_v2;end
root=[mdl '/无感观测'];assert(bdIsLoaded(mdl)&&strcmp(get_param(mdl,'SimulationStatus'),'stopped'));
assert(strcmp(get_param(root,'MaskType'),'Local sensorless nonideal v2'),'Only the R1 v2 layer can be formatted.');
before=teach_snapshot(mdl);ws=get_param(mdl,'ModelWorkspace');variables=workspace_values(ws);
rows={'参数','发布_SLess_cfg';'方向','发布_SLess_direction';'启用','发布_SLess_enabled';'适配参数','发布_SLessV2_front_cfg'};
for k=1:size(rows,1)
 y=30+80*(k-1);set_param([root '/' rows{k,1}],'Position',[30 y 200 y+30],'FontSize','11');
 set_param([root '/' rows{k,2}],'Position',[250 y 500 y+30],'FontSize','10');
end
modules={'采样输入',600,80;'区间电压',850,80;'执行许可',1100,80;'观测',1350,80;...
 '滑模观测',600,240;'反电动势',850,240;'锁相环',1100,240;'有效判断',1350,240;'发布许可',1350,400};
for k=1:size(modules,1)
 x=modules{k,2};y=modules{k,3};set_param([root '/' modules{k,1}],...
  'Position',[x y x+160 y+65],'FontSize','12','ContentPreviewEnabled','off');
end
tags=find_system(root,'LookUnderMasks','all','SearchDepth',1,'BlockType','GotoTagVisibility');
assert(numel(tags)==47,'sensorless:ReviewTags','Expected all 47 scoped visibility blocks, including masked contents.');
[~,order]=sort(cellfun(@(p)get_param(p,'GotoTag'),tags,'UniformOutput',false));tags=tags(order);
for k=1:numel(tags)
 x=30+330*mod(k-1,5);y=570+45*floor((k-1)/5);
 set_param(tags{k},'Position',[x y x+305 y+28],'FontSize','9','ShowName','off');
end
% Cosmetic changes must preserve the full executable graph and workspace.
after=teach_snapshot(mdl);assert(isequaln(rmfield(before.blocks,'position'),rmfield(after.blocks,'position')),...
 'sensorless:ReviewSemantics','Presentation unexpectedly changed block semantics.');
assert(isequaln(before.scripts,after.scripts)&&isequaln(before.config,after.config)&&isequaln(before.regions,after.regions));
assert(isequaln(variables,workspace_values(ws)));
report=struct('schema',1,'node','N3R1','kind','presentation_only','modules',size(modules,1),...
 'scoped_visibility_tags',numel(tags),'executable_graph_unchanged',true,'workspace_unchanged',true,...
 'source_sha256',teach_hash([mfilename('fullpath') '.m']));
end
function values=workspace_values(ws)
names=whos(ws);values=cell(numel(names),2);
for k=1:numel(names),values(k,:)={names(k).name,getVariable(ws,names(k).name)};end
end
