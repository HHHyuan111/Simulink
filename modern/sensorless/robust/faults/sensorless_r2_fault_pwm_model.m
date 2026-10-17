function backup=sensorless_r2_fault_pwm_model(mdl,program)
% Physical timing fixture only. Original controller and PI remain unchanged.
here=fileparts(mfilename('fullpath'));rt=sfroot;charts=rt.find('-isa','Stateflow.EMChart');match={};
for k=1:numel(charts)
 if startsWith(charts(k).Path,[mdl '/'])&&contains(charts(k).Script,'= timing_pwm('),match{end+1}=charts(k);end %#ok<AGROW>
end
assert(numel(match)==1);c=match{1};p=get_param(c.Path,'Parent');name='R2计算调度计划';
backup=struct('path',c.Path,'script',c.Script,'constant',[p '/' name]);
paths=find_system(c.Path,'LookUnderMasks','all','FollowLinks','off','Type','Block');
backup.layout=struct('path',{},'position',{});
for k=1:numel(paths),backup.layout(k)=struct('path',paths{k},'position',get_param(paths{k},'Position'));end
c.Script=fileread(fullfile(here,'blocks/sless_r2_pwm_block.m'));data=c.find('-isa','Stateflow.Data','Name','program');data.Props.Array.Size='[1 22]';data.DataType='double';
add_block('simulink/Sources/Constant',backup.constant,'Value',mat2str(program,17),'VectorParams1D','off','Position',[20 470 230 500]);
add_line(p,[name '/1'],[get_param(c.Path,'Name') '/4'],'autorouting','on');
end
