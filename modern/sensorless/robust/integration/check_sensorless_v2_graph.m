function r=check_sensorless_v2_graph(mdl,original)
root=[mdl '/无感观测'];after=teach_snapshot(mdl);preserved=true;
for b=original.blocks(:)'
 i=find(strcmp({after.blocks.path},b.path));preserved=preserved&&isscalar(i)&&isequaln(after.blocks(i),b);
end
scripts_ok=true;
for k=1:size(original.scripts,1)
 i=find(strcmp(after.scripts(:,1),original.scripts{k,1}));scripts_ok=scripts_ok&&isscalar(i)&&strcmp(after.scripts{i,2},original.scripts{k,2});
end
gotos=find_system(root,'LookUnderMasks','all','BlockType','Goto');tags=cell(size(gotos));scoped=true;
for k=1:numel(gotos),tags{k}=get_param(gotos{k},'GotoTag');scoped=scoped&&startsWith(tags{k},'SLessV2_')&&strcmp(get_param(gotos{k},'TagVisibility'),'scoped');end
imports=find_system(root,'LookUnderMasks','all','BlockType','From');truth_only=true;allowed=true;
external={'Iabc_meas','SLessV2ADC','SLessAppliedThreshold','ObsADCTiming','ObsPWMTiming','ObsCarrier','UDC'};
for k=1:numel(imports)
 tag=get_param(imports{k},'GotoTag');
 if ismember(tag,{'theta_e','speed'}),truth_only=truth_only&&startsWith(imports{k},[root '/观测/']);
 elseif ~startsWith(tag,'SLessV2_'),allowed=allowed&&ismember(tag,external);end
end
additions=setdiff({after.blocks.path},{original.blocks.path});parents=cellfun(@(p)get_param(p,'Parent'),additions,'UniformOutput',false);
r=struct('original_blocks_preserved',preserved,'original_algorithms_preserved',scripts_ok,...
 'original_regions_preserved',isequaln(original.regions,after.regions),'single_root',sum(strcmp(parents,mdl))==1,...
 'goto_count',numel(gotos),'all_gotos_scoped',scoped,'unique_tags',numel(unique(tags))==numel(tags),...
 'truth_only_evaluation',truth_only,'external_inputs_whitelisted',allowed,'new_blocks',numel(additions));
scope=get_param([root '/观测/许可与节拍'],'ScopeConfiguration');
r.publication_scope_normalized=isequal(scope.LayoutDimensions,[2 2])&&~scope.FrameBasedProcessing&&~scope.DataLogging;
% Counts are evidence, not boolean conditions.
r.passed=preserved&&scripts_ok&&r.original_regions_preserved&&r.single_root&&scoped&&r.unique_tags&&truth_only&&allowed&&r.publication_scope_normalized;
end
