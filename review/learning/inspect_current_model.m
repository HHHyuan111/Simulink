function inspect_current_model
% Read-only evidence export for the module handbook. The model is never saved.
folder=fileparts(mfilename('fullpath')); mdl='PMSM_FOC_R2026a';
load_system('D:/simulink/modern/PMSM_FOC_R2026a.slx');
guard=onCleanup(@()close_system(mdl,0));
set_param(mdl,'SimulationCommand','update');
paths=sort(find_system(mdl,'LookUnderMasks','all','FollowLinks','off','Type','Block'));
blocks=struct('path',{},'sid',{},'name',{},'parent',{},'type',{},'position',{}, ...
 'params',{},'inputs',{},'outputs',{},'compiled_sample_time',{});
skip={'GraphicalSettings','MultipleDisplayCache','AttributesFormatString','ContentPreviewEnabled', ...
 'ShowPortLabels','ShowSubsystemReinitializePorts'};
for k=1:numel(paths)
 b=paths{k}; p=struct; dialog=get_param(b,'DialogParameters');
 if ~isempty(dialog)
  keys=fieldnames(dialog);
  for j=1:numel(keys)
   if ~ismember(keys{j},skip)
    try,p.(keys{j})=get_param(b,keys{j});catch,end
   end
  end
 end
 ph=get_param(b,'PortHandles'); ins=struct('port',{},'source',{},'source_port',{});
 for j=1:numel(ph.Inport)
  ln=get_param(ph.Inport(j),'Line');if ln<0,continue;end
  src=get_param(ln,'SrcPortHandle');if src<0,continue;end
  ins(end+1)=struct('port',j,'source',get_param(src,'Parent'),'source_port',get_param(src,'PortNumber')); %#ok<AGROW>
 end
 outs=struct('port',{},'signal',{},'destinations',{});
 for j=1:numel(ph.Outport)
  ln=get_param(ph.Outport(j),'Line');dests={};sig='';
  if ln>=0
   sig=get_param(ln,'Name'); dh=get_param(ln,'DstPortHandle');
   for q=1:numel(dh)
    if dh(q)>=0,dests{end+1}=sprintf('%s#in:%d',get_param(dh(q),'Parent'),get_param(dh(q),'PortNumber'));end %#ok<AGROW>
   end
  end
  outs(end+1)=struct('port',j,'signal',sig,'destinations',{dests}); %#ok<AGROW>
 end
 try,st=get_param(b,'CompiledSampleTime');catch,st=[];end
 blocks(end+1)=struct('path',b,'sid',Simulink.ID.getSID(b),'name',get_param(b,'Name'), ...
  'parent',get_param(b,'Parent'),'type',get_param(b,'BlockType'),'position',get_param(b,'Position'), ...
  'params',p,'inputs',ins,'outputs',outs,'compiled_sample_time',{st}); %#ok<AGROW>
end
mw=get_param(mdl,'ModelWorkspace');vars=whos(mw);values=struct;
for k=1:numel(vars),values.(vars(k).name)=getVariable(mw,vars(k).name);end
root=sfroot;charts=root.find('-isa','Stateflow.EMChart');scripts=struct('path',{},'script',{});
for k=1:numel(charts)
 if startsWith(charts(k).Path,[mdl '/']),scripts(end+1)=struct('path',charts(k).Path,'script',charts(k).Script);end %#ok<AGROW>
end
settings=struct; keys={'SolverType','Solver','FixedStep','StartTime','StopTime','SignalLogging'};
for k=1:numel(keys),settings.(keys{k})=get_param(mdl,keys{k});end
r=struct('source','D:/simulink/modern/PMSM_FOC_R2026a.slx','matlab',version, ...
 'toolboxes',ver,'workspace',values,'workspace_code',mw.MATLABCode,'configuration',settings, ...
 'blocks',blocks,'matlab_functions',scripts);
fid=fopen(fullfile(folder,'current_model_evidence.json'),'w','n','UTF-8');
fprintf(fid,'%s',jsonencode(r,PrettyPrint=true));fclose(fid);
fprintf('READ_ONLY_EXPORT_OK %d blocks\n',numel(blocks));
end
