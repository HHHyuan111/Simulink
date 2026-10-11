function settings=teach_settings(mdl)
settings=struct('block',{},'parameters',{});
for name={'时序设置','采样设置','角度设置'}
 mask=Simulink.Mask.get([mdl '/' name{1}]);params=struct('name',{},'value',{});
 for j=1:numel(mask.Parameters)
  p=mask.Parameters(j);params(end+1)=struct('name',p.Name,'value',p.Value); %#ok<AGROW>
 end
 settings(end+1)=struct('block',name{1},'parameters',params); %#ok<AGROW>
end
end
