function pmsm_startup_mode(mdl)
% Compile-time bypass: avoid even an inactive reset port in the native PI.
path=[mdl '/启停'];if getSimulinkBlockHandle(path)<0,return;end
on=strcmp(get_param(path,'enabled'),'on');b=get_param(path,'UserData');
for j=1:numel(b.rewires)
 r=b.rewires(j);target=r.source;if on,target=r.newsource;end
 line=get_param(r.destination,'Line');current=-1;if line>=0,current=get_param(line,'SrcPortHandle');end
 if current~=target
  if line>=0,delete_line(r.parent,current,r.destination);end
  add_line(r.parent,target,r.destination,'autorouting','on');
 end
end
for j=1:numel(b.integrators)
 int=b.integrators(j).path;reset='none';if on,reset='level';end
 if ~strcmp(get_param(int,'ExternalReset'),reset),set_param(int,'ExternalReset',reset);end
 parent=get_param(int,'Parent');src=get_param([parent '/保持复位'],'PortHandles');term=get_param([parent '/复位观测'],'PortHandles');
 line=get_param(src.Outport,'Line');if line>=0,delete_line(line);end
 add_line(parent,src.Outport,term.Inport,'autorouting','on');
 if on
  ph=get_param(int,'PortHandles');add_line(parent,src.Outport,ph.Inport(2),'autorouting','on');
 end
end
end
