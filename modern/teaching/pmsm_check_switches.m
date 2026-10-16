function active=pmsm_check_switches(config)
% Preflight switch dependencies before pmsm_config mutates the model.
c=pmsm_switch_catalog;ids=strcat({c.section},'.',{c.key});enabled=false(size(c));
for k=1:numel(c)
 ix=find(strcmp({config.rows.section},c(k).section)&strcmp({config.rows.key},c(k).key));
 assert(isscalar(ix),'开关档案缺失或重复：%s',ids{k});
 value=config.rows(ix).value;assert(ismember(value,{'on','off'}),'开关只能填写on/off：%s',ids{k});enabled(k)=strcmp(value,'on');
end
for k=find(enabled)
 for id=c(k).requires
  ix=find(strcmp(ids,id{1}));assert(isscalar(ix));
  assert(enabled(ix),'pmsm:SwitchDependency','“%s”需要先开启“%s”。',c(k).name,c(ix).name);
 end
 for id=c(k).conflicts
  ix=find(strcmp(ids,id{1}));assert(isscalar(ix));
  assert(~enabled(ix),'pmsm:SwitchConflict','“%s”与“%s”不能同时开启。',c(k).name,c(ix).name);
 end
end
active=ids(enabled);
end
