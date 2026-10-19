function report=build_sensorless_direct
% Build a standalone, directly connected adaptation of the local motor model.
base=sensorless_direct_setup;modern=fileparts(base);mdl='PMSM_FOC_R2026a';
folder=fullfile(base,'models','direct');assert(~isfolder(folder),'Direct model already built.');mkdir(folder);
report=struct('phase','load','passed',false,'simulation_started',false,'process_id',matlabProcessID);
cleanup=onCleanup(@()close_system(mdl,0)); %#ok<NASGU>
modelFile=fullfile(folder,[mdl '.slx']);source=fullfile(modern,[mdl '.slx']);copyfile(source,modelFile);
report.original_model_sha256=teach_hash(source);load_system(modelFile);set_param(0,'CurrentSystem',mdl);
profile=struct('window_on',false,'interference_s',0,'adc_span_A',20);
sensorless_v2_stimulus(mdl,profile);sensorless_r2_initialize_stopped(mdl);
report.phase='install_direct_subsystem';write_report;
pmsm_sensorless_v2_geometry_model('install',mdl,0);root=[mdl '/无感观测'];
sensorless_r2_phase_guard_model(mdl);
rt=sfroot;chart=rt.find('-isa','Stateflow.EMChart','Path',[root '/区间电压/非理想累计']);
chart.Script=fileread(fullfile(base,'direct','sless_direct_voltage_block.m'));
data=chart.find('-isa','Stateflow.Data','Name','adc_valid');data.Props.Array.Size='1';data.DataType='boolean';
add_block('simulink/Signal Routing/From',[root '/区间电压/ADC锚点有效'],...
 'GotoTag','SLessV2_adc_valid','Position',[20 1110 190 1135]);
add_line([root '/区间电压'],'ADC锚点有效/1','非理想累计/11','autorouting','on');
chart=rt.find('-isa','Stateflow.EMChart','Path',[root '/发布许可/完成后发布']);
chart.Script=fileread(fullfile(base,'direct','sless_direct_queue_block.m'));
% Keep the actual publication event, at 20 kHz, rather than a native evaluator.
p=[root '/观测'];event=[p '/完成数据'];add_block('built-in/SubSystem',event,'Position',[2700 130 2880 190]);
add_block('built-in/Inport',[event '/数据'],'PortDimensions','[15 1]','Position',[25 50 55 70]);
add_block('built-in/EnablePort',[event '/完成'],'Position',[95 10 115 30]);
add_block('simulink/Sinks/To Workspace',[event '/保存'],'VariableName','obs_sless_direct_completed',...
 'SaveFormat','Timeseries','SampleTime','-1','MaxDataPoints','inf','Position',[110 45 310 75]);
add_line(event,'数据/1','保存/1');
add_block('simulink/Signal Routing/From',[p '/完成数据来源'],'GotoTag','SLessV2_publication','Position',[2100 150 2300 175]);
add_block('simulink/User-Defined Functions/Fcn',[p '/完成事件'],'Expr','u(13)','Position',[2380 210 2500 240]);
add_block('simulink/Signal Routing/From',[p '/完成许可'],'GotoTag','SLessV2_control_permit','Position',[2100 270 2300 295]);
add_block('simulink/Signal Attributes/Data Type Conversion',[p '/许可数值'],'OutDataTypeStr','double','Position',[2350 270 2400 295]);
add_block('simulink/Signal Routing/From',[p '/完成原因'],'GotoTag','SLessV2_deny_reason','Position',[2100 330 2300 355]);
add_block('simulink/Signal Routing/Mux',[p '/完成记录合并'],'Inputs','3','Position',[2540 130 2550 350]);
add_line(p,'完成数据来源/1','完成记录合并/1','autorouting','on');
add_line(p,'完成许可/1','许可数值/1');add_line(p,'许可数值/1','完成记录合并/2','autorouting','on');
add_line(p,'完成原因/1','完成记录合并/3','autorouting','on');add_line(p,'完成记录合并/1','完成数据/1','autorouting','on');
add_line(p,'完成数据来源/1','完成事件/1','autorouting','on');
add_line(p,'完成事件/1','完成数据/Enable','autorouting','on');
% All ordinary observation and Scope data use the control sampling period.
logs=find_system(root,'LookUnderMasks','all','BlockType','ToWorkspace');
for k=1:numel(logs)
 if ~startsWith(logs{k},[event '/']),set_param(logs{k},'SampleTime','timing_control_sample');end
end
scopes=find_system(root,'LookUnderMasks','all','BlockType','Scope');
for k=1:numel(scopes),set_param(scopes{k},'SampleTime','timing_control_sample');end
% No truth monitor, model reference, fault planner or injection blocks installed.
assert(isempty(find_system(mdl,'LookUnderMasks','all','BlockType','ModelReference')));
blocks=find_system(root,'LookUnderMasks','all','Type','Block');
assert(~any(contains(blocks,{'R2原生评价','故障计划','故障时刻','R2累计记录','R2事件记录'})));
report.initialization=sensorless_r2_initialize_stopped(mdl);ws=get_param(mdl,'ModelWorkspace');entries=whos(ws);
values=struct('name',{},'value',{});for k=1:numel(entries),values(k)=struct('name',entries(k).name,'value',getVariable(ws,entries(k).name));end
% Save only the new adaptation. The source model's callbacks are untouched.
ws.DataSource='Model File';clear(ws);for k=1:numel(values),assignin(ws,values(k).name,values(k).value);end
set_param(root,'UserData',[]);set_param(mdl,'PreSaveFcn','','InitFcn','pmsm_sensorless_v2_init(bdroot);','StopTime','0.25');
save_system(mdl,modelFile);report.model_sha256=teach_hash(modelFile);report.workspace_variables=numel(values);
report.observer_config=getVariable(ws,'sless_cfg');report.frontend_config=getVariable(ws,'sless_v2_cfg');
report.step_s=getVariable(ws,'timing_h');report.observer_period_s=getVariable(ws,'timing_control_sample');
report.observer_blocks=numel(blocks);report.observer_scoped_gotos=numel(find_system(root,'LookUnderMasks','all','BlockType','Goto'));
report.phase='completed';report.passed=true;write_report;
assert(strcmp(teach_hash(source),report.original_model_sha256));
 function write_report,teach_writejson(fullfile(folder,'build.json'),report);end
end
