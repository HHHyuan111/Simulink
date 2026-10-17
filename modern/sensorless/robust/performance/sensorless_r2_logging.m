function record=sensorless_r2_logging(mdl)
% Explicit R2 long-trace logging policy. Original52 are not touched.
here=fileparts(mfilename('fullpath'));root=[mdl '/无感观测'];p=[root '/观测'];
record=struct('original_logs_changed',false,'scopes_commented',{{}},'changes',struct('variable',{},'before',{},'after',{}));
scopes=find_system(root,'LookUnderMasks','all','BlockType','Scope');
for k=1:numel(scopes),set_param(scopes{k},'Commented','on');end
record.scopes_commented=scopes;
logs=find_system(root,'LookUnderMasks','all','BlockType','ToWorkspace');
for k=1:numel(logs)
 variable=get_param(logs{k},'VariableName');before=get_param(logs{k},'SampleTime');after='timing_control_sample';
 if strcmp(variable,'obs_sless_v2_publication'),after='[dt timing_control_sample(2)+3e-6]';end
 if ~strcmp(before,after)
  set_param(logs{k},'SampleTime',after);
  record.changes(end+1)=struct('variable',variable,'before',before,'after',after); %#ok<AGROW>
 end
end
chartPath=[p '/R2原生评价'];add_block('simulink/User-Defined Functions/MATLAB Function',chartPath,'Position',[2700 50 2900 530]);
rt=sfroot;chart=rt.find('-isa','Stateflow.EMChart','Path',chartPath);
chart.Script=fileread(fullfile(here,'blocks','sless_r2_monitor_block.m'));chart.ChartUpdate='DISCRETE';chart.SampleTime='timing_h';chart.VectorOutputs1D=false;
sizes={'t','1';'pub','[13 1]';'permit','1';'reason','1';'adc_valid','1';'timing_valid','1';'reset','1';'truth_theta','1';'truth_rpm','1';...
 'counters','[12 1]';'event','[16 1]';'changed','1'};
boolean={'permit','adc_valid','timing_valid','reset','changed'};
for k=1:size(sizes,1)
 data=chart.find('-isa','Stateflow.Data','Name',sizes{k,1});data.Props.Array.Size=sizes{k,2};
 data.DataType='double';if ismember(sizes{k,1},boolean),data.DataType='boolean';end
end
tags={'SLessV2_native_time','SLessV2_publication','SLessV2_control_permit','SLessV2_deny_reason','SLessV2_adc_valid',...
 'SLessV2_timing_valid','SLessV2_reset','theta_e','speed'};
for k=1:numel(tags)
 name=['R2评价来源' num2str(k)];add_block('simulink/Signal Routing/From',[p '/' name],...
  'Position',[2480 45+55*(k-1) 2660 70+55*(k-1)],'GotoTag',tags{k});
 add_line(p,[name '/1'],['R2原生评价/' num2str(k)],'autorouting','on');
end
add_block('simulink/Sinks/To Workspace',[p '/R2累计记录'],'Position',[3000 50 3200 80],...
 'VariableName','obs_sless_r2_native_counters','SaveFormat','Timeseries','SampleTime','dt','MaxDataPoints','inf');
add_line(p,'R2原生评价/1','R2累计记录/1','autorouting','on');
e=[p '/R2事件记录'];add_block('built-in/SubSystem',e,'Position',[3000 150 3200 220]);
add_block('built-in/Inport',[e '/事件'],'Position',[25 50 55 70],'PortDimensions','[16 1]');
add_block('built-in/EnablePort',[e '/发生变化'],'Position',[95 10 115 30]);
add_block('simulink/Sinks/To Workspace',[e '/保存'],'Position',[110 45 310 75],...
 'VariableName','obs_sless_r2_native_events','SaveFormat','Timeseries','SampleTime','-1','MaxDataPoints','inf');
add_line(e,'事件/1','保存/1','autorouting','on');
add_line(p,'R2原生评价/2','R2事件记录/1','autorouting','on');
add_line(p,'R2原生评价/3','R2事件记录/Enable','autorouting','on');
end
