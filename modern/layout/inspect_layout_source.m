function inspect_layout_source
folder=fileparts(mfilename('fullpath'));cd(folder);
mdl='PMSM_FOC_R2026a';load_system(fullfile(fileparts(folder),[mdl '.slx']));
blocks=find_system(mdl,'SearchDepth',1,'Type','Block');
r=struct('name',{},'type',{},'position',{},'orientation',{},'params',{},'inputs',{});
for k=1:numel(blocks)
 b=blocks{k};v=struct('name',get_param(b,'Name'),'type',get_param(b,'BlockType'), ...
 'position',get_param(b,'Position'),'orientation',get_param(b,'Orientation'),'params',struct,'inputs',[]);
 pp=get_param(b,'DialogParameters');if ~isempty(pp)
  ff=fieldnames(pp);for j=1:numel(ff)
   try,v.params.(ff{j})=get_param(b,ff{j});catch,end
  end
 end
 ph=get_param(b,'PortHandles');ins=struct('port',{},'source',{},'sourceport',{});
 for j=1:numel(ph.Inport)
  line=get_param(ph.Inport(j),'Line');if line<0,continue;end
  src=get_param(line,'SrcPortHandle');if src<0,continue;end
  ins(end+1)=struct('port',j,'source',get_param(get_param(src,'Parent'),'Name'),'sourceport',get_param(src,'PortNumber')); %#ok<AGROW>
 end
 v.inputs=ins;r(end+1)=v; %#ok<AGROW>
end
fid=fopen(fullfile(folder,'source_inventory.json'),'w','n','UTF-8');fprintf(fid,'%s',jsonencode(r,PrettyPrint=true));fclose(fid);
print(['-s' mdl],'-dpng','-r100',fullfile(folder,'before.png'));
fprintf('INSPECT_OK %d TOP_BLOCKS\n',numel(blocks));close_system(mdl,0);
end
