function info=sensorless_r2_reference_model(action,mdl,folder,child)
% Reversible normal-model boundary around the actual local observer graph.
root=[mdl '/无感观测'];assert(strcmp(get_param(mdl,'SimulationStatus'),'stopped'));
if strcmp(action,'remove')
 backup=get_param(root,'UserData');info=backup.reference_adapter;
 pmsm_sensorless_v2_geometry_model('remove',mdl);
 if bdIsLoaded(info.child_model),close_system(info.child_model,0);end
 set_param(0,'CurrentSystem',mdl);return;
end
assert(strcmp(action,'install')&&nargin==4&&getSimulinkBlockHandle(root)>0);
assert(isempty(get_param(mdl,'InitFcn')),'Trusted stopped initialization must finish before reference conversion.');
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));
toy=jsondecode(fileread(fullfile(base,'runs/N3R2_model_reference_toy_isolation_once/report.json')));assert(toy.all_passed);
backup=get_param(root,'UserData');position=get_param(root,'Position');originalCatalog=catalog(root);originalCharts=charts(root);
parentWs=get_param(mdl,'ModelWorkspace');values=workspace_values(parentWs);assert(numel(values)==86&&getVariable(parentWs,'timing_h')==62.5e-9);
cfg=getVariable(parentWs,'sless_cfg');front=getVariable(parentWs,'sless_v2_cfg');
ports=interface;external=sort(setdiff(tags(root,'From'),tags(root,'Goto')));assert(isequal(external(:),sort({ports.tag})'));
truth=find_system(root,'LookUnderMasks','all','BlockType','From');
for k=1:numel(truth)
 if ismember(get_param(truth{k},'GotoTag'),{'theta_e','speed'}),assert(startsWith(truth{k},[root '/观测/']));end
end
assert(ischar(child)&&~isempty(regexp(child,'^sr2_[0-9a-f]{8}$','once'))&&~bdIsLoaded(child));
modelFolder=fullfile(folder,'model');assert(~isfolder(modelFolder));mkdir(modelFolder);addpath(modelFolder);
childFile=fullfile(modelFolder,[child '.slx']);assert(strlength(childFile)<240);
new_system(child);set_param(child,'SolverType','Fixed-step','Solver','FixedStepDiscrete','FixedStep','timing_h',...
 'SolverMode','SingleTasking','EnableMultiTasking','off','SaveTime','off','SaveOutput','off','SignalLogging','off','ReturnWorkspaceOutputs','on');
childWs=get_param(child,'ModelWorkspace');for k=1:numel(values),assignin(childWs,values(k).name,values(k).value);end
childRoot=[child '/无感观测'];add_block(root,childRoot);
assert(isequaln(originalCatalog,catalog(childRoot))&&isequaln(originalCharts,charts(childRoot)));
assert(isequaln(values,workspace_values(childWs)));
mask=Simulink.Mask.get(childRoot);assert(isempty(mask.Initialization));
parameters=mask.Parameters;for k=1:numel(parameters),parameters(k).Enabled='off';end
blocks=find_system(childRoot,'LookUnderMasks','all','Type','Block');rewrites=repmat(struct('path','','before','','after',''),numel(blocks),1);changed=0;
for k=1:numel(blocks)
 callback=get_param(blocks{k},'OpenFcn');
 if contains(callback,root)
  rewritten=strrep(callback,root,childRoot);set_param(blocks{k},'OpenFcn',rewritten);changed=changed+1;
  rewrites(changed)=struct('path',blocks{k},'before',callback,'after',rewritten);
 end
end
rewrites=rewrites(1:changed);
for k=1:numel(ports)
 y=40+65*(k-1);inputName=['输入_' ports(k).name];gotoName=['发布_' ports(k).tag];
 add_block('built-in/Inport',[child '/' inputName],'Port',num2str(k),'PortDimensions',ports(k).dimensions,'SampleTime','-1','Position',[25 y 55 y+20]);
 add_block('simulink/Signal Routing/Goto',[child '/' gotoName],'GotoTag',ports(k).tag,'TagVisibility','scoped','Position',[120 y 350 y+25]);
 add_block('simulink/Signal Routing/Goto Tag Visibility',[child '/可见域_' ports(k).tag],'GotoTag',ports(k).tag,'ShowName','off','Position',[390 y 620 y+25]);
 add_line(child,[inputName '/1'],[gotoName '/1'],'autorouting','on');
end
assert(isempty(get_param(child,'InitFcn'))&&isempty(get_param(child,'PreSaveFcn'))&&isempty(get_param(child,'StopFcn')));
save_system(child,childFile);
info=struct('kind','normal_model_reference_adapter','child_model',child,'child_file',strrep(childFile,'\','/'),...
 'child_model_sha256',teach_hash(childFile),'child_root',childRoot,'parent_root',root,'interface',ports,...
 'source_blocks',numel(originalCatalog),'source_charts',numel(originalCharts),'clone_catalog_exact',true,'clone_charts_exact',true,...
 'clone_workspace_exact',true,'generated_parameters_read_only',true,'observer_config',cfg,'frontend_config',front,...
 'native_step_s',62.5e-9,'control_sample',getVariable(parentWs,'timing_control_sample'),'no_feedback_output',true,...
 'scope_open_callback_rewrites',rewrites);
delete_block(root);add_block('built-in/SubSystem',root,'Position',position,'BackgroundColor','[0.80 0.89 0.98]');
backup.reference_adapter=info;set_param(root,'UserData',backup);
wrapper=Simulink.Mask.create(root);wrapper.Type='Sensorless R2 normal reference';wrapper.Display="disp('无感观测: SMO + PLL')";
metadata={'R_hat','观测相电阻 [Ω]',cfg(1);'L_hat','观测电感 [H]',cfg(2);'Kslide_V','滑模注入 [V]',cfg(7);...
 'boundary_A','边界层 [A]',cfg(8);'pll_Kp','PLL Kp [1/s]',cfg(11);'pll_Ki','PLL Ki [1/s²]',cfg(12);...
 'sample_s','观测周期 [s]',front(2)};
for k=1:size(metadata,1),wrapper.addParameter('Name',metadata{k,1},'Type','edit','Prompt',metadata{k,2},'Value',num2str(metadata{k,3},17),'Enabled','off','Tunable','off');end
reference=[root '/观测核心'];add_block('simulink/Ports & Subsystems/Model',reference,'ModelName',child,'SimulationMode','Normal','Position',[400 45 640 590]);
for k=1:numel(ports)
 name=['实际输入_' ports(k).name];y=55+60*(k-1);
 add_block('simulink/Signal Routing/From',[root '/' name],'GotoTag',ports(k).tag,'Position',[25 y 290 y+25]);
 add_line(root,[name '/1'],['观测核心/' num2str(k)],'autorouting','on');
end
assert(isequaln(values,workspace_values(parentWs)));set_param(0,'CurrentSystem',mdl);
end
function ports=interface
rows={'SLessAppliedThreshold','生效CCR','3';'ObsCarrier','实际载波','1';'UDC','直流母线','1';...
 'Iabc_meas','滤后电流','[3 1]';'SLessV2ADC','原始ADC','[3 1]';'ObsADCTiming','ADC时序','[1 15]';...
 'ObsPWMTiming','PWM时序','[1 12]';'theta_e','评价角度_仅观测','1';'speed','评价转速_仅观测','1'};
ports=repmat(struct('tag','','name','','dimensions',''),size(rows,1),1);
for k=1:size(rows,1),ports(k)=struct('tag',rows{k,1},'name',rows{k,2},'dimensions',rows{k,3});end
end
function values=workspace_values(ws)
entries=whos(ws);names=sort({entries.name});values=repmat(struct('name','','value',[]),numel(names),1);
for k=1:numel(names),values(k)=struct('name',names{k},'value',getVariable(ws,names{k}));end
end
function result=tags(root,type)
blocks=find_system(root,'LookUnderMasks','all','BlockType',type);result=unique(cellfun(@(b)get_param(b,'GotoTag'),blocks,'UniformOutput',false));
end
function result=catalog(root)
blocks=sort(find_system(root,'LookUnderMasks','all','Type','Block'));result=repmat(struct('relative','','type',''),numel(blocks),1);
for k=1:numel(blocks),result(k)=struct('relative',strrep(blocks{k},root,''),'type',get_param(blocks{k},'BlockType'));end
end
function result=charts(root)
rt=sfroot;allCharts=rt.find('-isa','Stateflow.EMChart');result=repmat(struct('relative','','script',''),numel(allCharts),1);count=0;
for k=1:numel(allCharts)
 if startsWith(allCharts(k).Path,[root '/']),count=count+1;result(count)=struct('relative',strrep(allCharts(k).Path,root,''),'script',allCharts(k).Script);end
end
result=result(1:count);if ~isempty(result),[~,index]=sort({result.relative});result=result(index);end
end
