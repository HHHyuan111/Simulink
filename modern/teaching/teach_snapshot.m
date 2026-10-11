function s=teach_snapshot(mdl)
paths=sort(find_system(mdl,'LookUnderMasks','all','FollowLinks','off','Type','Block'));
blocks=struct('path',{},'sid',{},'type',{},'position',{},'orientation',{},'params',{},'inputs',{},'mask',{});
for k=1:numel(paths)
 b=paths{k};typ=get_param(b,'BlockType');pp=get_param(b,'DialogParameters');params=struct;
 if ~isempty(pp)&&~strcmp(typ,'Scope')
  keys=sort(fieldnames(pp));for j=1:numel(keys),params.(keys{j})=get_param(b,keys{j});end
 end
 if strcmp(typ,'Record')&&isfield(params,'SignalIDs'),params=rmfield(params,'SignalIDs');end
 ph=get_param(b,'PortHandles');inputs=cell(numel(ph.Inport),1);
 for j=1:numel(inputs)
  line=get_param(ph.Inport(j),'Line');inputs{j}=[];
  if line>=0,src=get_param(line,'SrcPortHandle');if src>=0,inputs{j}={get_param(src,'Parent'),get_param(src,'PortNumber')};end,end
 end
 mask=struct;for key={'MaskType','MaskDisplay','MaskInitialization','MaskNames','MaskValues'},mask.(key{1})=get_param(b,key{1});end
 blocks(end+1)=struct('path',b,'sid',Simulink.ID.getSID(b),'type',typ, ...
  'position',get_param(b,'Position'),'orientation',get_param(b,'Orientation'),'params',params,'inputs',{inputs},'mask',mask); %#ok<AGROW>
end
annotations=find_system(mdl,'FindAll','on','SearchDepth',1,'Type','annotation');regions=struct('name',{},'position',{},'color',{});
for h=annotations(:)'
 a=get_param(h,'Object');if strcmp(a.Tag,'FlatTidyRegion')
  regions(end+1)=struct('name',a.Name,'position',a.Position,'color',a.BackgroundColor); %#ok<AGROW>
 end
end
[~,idx]=sort({regions.name});regions=regions(idx);
rt=sfroot;charts=rt.find('-isa','Stateflow.EMChart');scripts={};
for k=1:numel(charts),if startsWith(charts(k).Path,[mdl '/']),scripts(end+1,:)={charts(k).Path,charts(k).Script};end,end %#ok<AGROW>
config=struct;for key={'Solver','FixedStep','StopTime','SolverType'},config.(key{1})=get_param(mdl,key{1});end
s=struct('blocks',blocks,'regions',regions,'scripts',{scripts},'config',config);
end
