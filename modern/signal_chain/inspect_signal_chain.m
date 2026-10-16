function report=inspect_signal_chain
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'teaching'));
m='PMSM_FOC_R2026a';assert(~bdIsLoaded(m));load_system(fullfile(root,[m '.slx']));guard=onCleanup(@()close_system(m,0));
folder=fullfile(root,'.build','signal_chain');if ~isfolder(folder),mkdir(folder);end
report=struct('model_sha256',teach_hash(fullfile(root,[m '.slx'])),'systems',{{}});
for name={'采样设置','输出延迟','时序设置'}
 parent=[m '/' name{1}];mask=Simulink.Mask.get(parent);blocks=find_system(parent,'SearchDepth',1,'LookUnderMasks','all','Type','Block');rows={};
 for k=1:numel(blocks)
  b=blocks{k};if strcmp(b,parent),continue;end
  ph=get_param(b,'PortHandles');inputs=cell(1,numel(ph.Inport));
  for j=1:numel(inputs)
   ln=get_param(ph.Inport(j),'Line');if ln<0,inputs{j}='';else,sp=get_param(ln,'SrcPortHandle');inputs{j}=sprintf('%s:%d',get_param(sp,'Parent'),get_param(sp,'PortNumber'));end
  end
  pp=get_param(b,'DialogParameters');params=struct;for key=fieldnames(pp)'
   if ismember(key{1},{'Position','NamePlacement','PortDimensions','OutMin','OutMax'}),continue;end
   params.(key{1})=get_param(b,key{1});
  end
  rows{end+1}=struct('name',get_param(b,'Name'),'sid',Simulink.ID.getSID(b),'type',get_param(b,'BlockType'),...
   'inputs',{inputs},'params',params,'position',get_param(b,'Position')); %#ok<AGROW>
 end
 report.systems{end+1}=struct('name',name{1},'mask_names',{get_param(parent,'MaskNames')},'mask_values',{get_param(parent,'MaskValues')},...
  'mask_init',mask.Initialization,'description',mask.Description,'blocks',{rows}); %#ok<AGROW>
end
rt=sfroot;charts=rt.find('-isa','Stateflow.EMChart');
for c=charts(:)'
 if startsWith(c.Path,[m '/采样设置/'])||startsWith(c.Path,[m '/输出延迟/'])
  file=fullfile(folder,[get_param(c.Path,'Name') '.m']);fid=fopen(file,'w','n','UTF-8');fprintf(fid,'%s',c.Script);fclose(fid);
 end
end
fid=fopen(fullfile(folder,'model_init.m'),'w','n','UTF-8');fprintf(fid,'%s',get_param(m,'InitFcn'));fclose(fid);
teach_writejson(fullfile(folder,'inventory.json'),report);disp('SIGNAL_CHAIN_INSPECTED');
end
