function r=check_sensorless_graph(mdl,original)
% Inspect actual installed graph and scope configuration, not source strings.
path=[mdl '/无感观测'];after=teach_snapshot(mdl);old=original.blocks;
preserved=true;
for k=1:numel(old)
 index=find(strcmp({after.blocks.path},old(k).path));
 preserved=preserved&&isscalar(index)&&isequaln(after.blocks(index),old(k));
end
gotos=find_system(path,'LookUnderMasks','all','BlockType','Goto');tags=cell(size(gotos));scoped=true;
for k=1:numel(gotos)
 tags{k}=get_param(gotos{k},'GotoTag');scoped=scoped&&strcmp(get_param(gotos{k},'TagVisibility'),'scoped')&&startsWith(tags{k},'SLess_');
end
unique_tags=numel(unique(tags))==numel(tags);truth_only=true;
scripts_ok=true;
for k=1:size(original.scripts,1)
 index=find(strcmp(after.scripts(:,1),original.scripts{k,1}));
 scripts_ok=scripts_ok&&isscalar(index)&&strcmp(after.scripts{index,2},original.scripts{k,2});
end
imports=find_system(path,'LookUnderMasks','all','BlockType','From');
for k=1:numel(imports)
 tag=get_param(imports{k},'GotoTag');
 if ismember(tag,{'theta_e','speed'}),truth_only=truth_only&&startsWith(imports{k},[path '/观测/']);end
end
root_additions=setdiff({after.blocks.path},{old.path});
root_owners=cellfun(@(p)get_param(p,'Parent'),root_additions,'UniformOutput',false);
one_root=sum(strcmp(root_owners,mdl))==1;
scope_paths={[path '/观测/角度与速度'],[path '/观测/观测器内部']};layouts={[2 2],[3 2]};scope_ok=true;
scopes=struct('path',{},'layout',{},'inputs',{},'frame_based',{},'data_logging',{});
for k=1:2
 c=get_param(scope_paths{k},'ScopeConfiguration');
 scopes(k)=struct('path',scope_paths{k},'layout',c.LayoutDimensions,'inputs',str2double(get_param(scope_paths{k},'NumInputPorts')),...
  'frame_based',c.FrameBasedProcessing,'data_logging',c.DataLogging);
 scope_ok=scope_ok&&isequal(c.LayoutDimensions,layouts{k})&&~c.FrameBasedProcessing&&~c.DataLogging;
end
r=struct('original_blocks_preserved_while_installed',preserved,'original_regions_preserved',isequaln(original.regions,after.regions),...
 'original_algorithms_preserved',scripts_ok,...
 'original_block_count',numel(old),'new_block_count',numel(after.blocks)-numel(old),'only_one_new_root_block',one_root,...
 'goto_count',numel(gotos),'all_tags_scoped',scoped,'tags_unique',unique_tags,'truth_imports_only_evaluation',truth_only,...
 'scopes',scopes,'scope_configuration_passed',scope_ok,...
 'passed',preserved&&scripts_ok&&isequaln(original.regions,after.regions)&&one_root&&scoped&&unique_tags&&truth_only&&scope_ok);
end
