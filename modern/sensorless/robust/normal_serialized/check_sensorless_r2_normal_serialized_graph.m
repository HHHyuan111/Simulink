function result=check_sensorless_r2_normal_serialized_graph(mdl,original,info)
% Verify stopped graph; declared ports are not reported as compiled dimensions.
after=teach_snapshot(mdl);preserved=true;
for block=original.blocks(:)'
 index=find(strcmp({after.blocks.path},block.path));preserved=preserved&&isscalar(index)&&isequaln(after.blocks(index),block);
end
scripts=true;
for k=1:size(original.scripts,1)
 index=find(strcmp(after.scripts(:,1),original.scripts{k,1}));scripts=scripts&&isscalar(index)&&strcmp(after.scripts{index,2},original.scripts{k,2});
end
reference=[info.parent_root '/观测核心'];handles=get_param(reference,'PortHandles');assert(numel(handles.Inport)==9&&isempty(handles.Outport));
inputs=repmat(struct('tag','','dimensions',[],'data_type','','width_matches',false),9,1);
for k=1:9
 input=[info.child_model '/输入_' info.interface(k).name];
 dimensions=str2num(get_param(input,'PortDimensions'));type=get_param(input,'OutDataTypeStr'); %#ok<ST2NM>
 declared=str2num(info.interface(k).dimensions); %#ok<ST2NM>
 inputs(k)=struct('tag',info.interface(k).tag,'dimensions',dimensions,'data_type',type,'width_matches',prod(dimensions)==prod(declared)&&strcmp(type,'double'));
end
imports=find_system(info.child_root,'LookUnderMasks','all','BlockType','From');truthOnly=true;
for k=1:numel(imports)
 if ismember(get_param(imports{k},'GotoTag'),{'theta_e','speed'}),truthOnly=truthOnly&&startsWith(imports{k},[info.child_root '/观测/']);end
end
result=struct('original_blocks_preserved',preserved,'original_algorithms_preserved',scripts,...
 'original_regions_preserved',isequaln(original.regions,after.regions),'declared_interface_not_runtime_compiled_port_query',true,'normal_reference',strcmpi(get_param(reference,'SimulationMode'),'normal')&&strcmp(get_param(info.child_model,'ModelReferenceNumInstancesAllowed'),'Single'),...
 'nine_inputs_no_feedback_output',numel(handles.Inport)==9&&isempty(handles.Outport),'inputs',inputs,'truth_only_evaluation',truthOnly,...
 'clone_catalog_exact',info.clone_catalog_exact,'clone_charts_exact',info.clone_charts_exact,'clone_workspace_exact',info.clone_workspace_exact);
result.passed=preserved&&scripts&&result.original_regions_preserved&&result.normal_reference&&result.nine_inputs_no_feedback_output&&all([inputs.width_matches])&&truthOnly&&info.clone_catalog_exact&&info.clone_charts_exact&&info.clone_workspace_exact;
end
