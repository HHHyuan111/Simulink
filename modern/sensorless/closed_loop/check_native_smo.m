function report = check_native_smo(mdl, outputFile)
% Disposable equation check; no test blocks are installed in the motor model.
base=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(base,'blocks'));
h='SMO_Native_Check';new_system(h);cleanup=onCleanup(@()close_system(h,0)); %#ok<NASGU>
set_param(h,'SolverType','Variable-step','Solver','VariableStepDiscrete','StopTime','.5','ReturnWorkspaceOutputs','on');
source=get_param(mdl,'ModelWorkspace');ws=get_param(h,'ModelWorkspace');
assignin(ws,'sless_cfg',getVariable(source,'sless_cfg'));
period=getVariable(source,'timing_control_sample');assignin(ws,'timing_control_sample',period);
native=[h '/native'];add_block([mdl '/无感观测/滑模观测'],native);
inputTags={'SLessV2_current','SLessV2_voltage_sample','SLessV2_sample_valid','SLessV2_reset'};
readers=find_system(native,'SearchDepth',1,'BlockType','From');
for k=1:numel(readers)
    tag=get_param(readers{k},'GotoTag');index=find(strcmp(inputTags,tag),1);if isempty(index),continue;end
    ph=get_param(readers{k},'PortHandles');ln=get_param(ph.Outport,'Line');dest=get_param(ln,'DstPortHandle');
    name=get_param(readers{k},'Name');position=get_param(readers{k},'Position');delete_line(ln);delete_block(readers{k});
    dims='[2 1]';type='double';if index>2,dims='1';type='boolean';end
    add_block('built-in/Inport',[native '/' name],'Port',num2str(index),'PortDimensions',dims,'OutDataTypeStr',type,'Position',position);
    ph=get_param([native '/' name],'PortHandles');for target=dest(:)',add_line(native,ph.Outport,target);end
end
tags={'SLessV2_i_hat','SLessV2_residual','SLessV2_injection'};
writers=find_system(native,'SearchDepth',1,'BlockType','Goto');
for k=1:numel(writers)
    tag=get_param(writers{k},'GotoTag');index=find(strcmp(tags,tag),1);if isempty(index),continue;end
    set_param(writers{k},'TagVisibility','local');ph=get_param(writers{k},'PortHandles');
    src=get_param(get_param(ph.Inport,'Line'),'SrcPortHandle');name=['output_' num2str(index)];
    add_block('built-in/Outport',[native '/' name],'Port',num2str(index));
    ph=get_param([native '/' name],'PortHandles');add_line(native,src,ph.Inport);
end
reference=[h '/reference'];add_block('simulink/User-Defined Functions/MATLAB Function',reference);
rt=sfroot;chart=rt.find('-isa','Stateflow.EMChart','Path',reference);
chart.Script=fileread(fullfile(base,'blocks','sless_smo_block.m'));
chart.ChartUpdate='DISCRETE';chart.SampleTime='timing_control_sample';chart.VectorOutputs1D=false;
rows={'current','[2 1]';'voltage','[2 1]';'valid','1';'reset','1';'cfg','[1 18]'; ...
    'estimate','[2 1]';'residual','[2 1]';'injection','[2 1]'};
for k=1:size(rows,1)
    d=chart.find('-isa','Stateflow.Data','Name',rows{k,1});d.Props.Array.Size=rows{k,2};d.DataType='double';
    if ismember(rows{k,1},{'valid','reset'}),d.DataType='boolean';end
end
inputs={'current','voltage','valid','reset'};
for k=1:4
    name=inputs{k};add_block('simulink/Sources/From Workspace',[h '/' name], ...
        'VariableName',['input_' name],'SampleTime','timing_control_sample', ...
        'Interpolate','off','OutputAfterFinalValue','Holding final value');
    src=name;
    if k<3
        src=[name '_column'];add_block('simulink/Math Operations/Reshape',[h '/' src],'OutputDimensionality','Column vector (2-D)');
        add_line(h,[name '/1'],[src '/1']);
    end
    add_line(h,[src '/1'],['native/' num2str(k)]);add_line(h,[src '/1'],['reference/' num2str(k)]);
end
add_block('simulink/Sources/Constant',[h '/parameters'],'Value','sless_cfg','VectorParams1D','off');
add_line(h,'parameters/1','reference/5');
for version={'native','reference'}
    for k=1:3
        name=[version{1} '_' num2str(k)];add_block('simulink/Sinks/To Workspace',[h '/' name], ...
            'VariableName',name,'SaveFormat','Timeseries','SampleTime','timing_control_sample','MaxDataPoints','inf');
        add_line(h,[version{1} '/' num2str(k)],[name '/1']);
    end
end
data=load(fullfile(base,'runs','SMO_closed_final_a','signals.mat'));
logs={data.obs_sless_v2_input_i,data.obs_sless_v2_input_v,data.obs_sless_v2_sample_valid,data.obs_sless_v2_reset};
for k=1:4
    values=teach_values(logs{k});if k>2,values=logical(values);end
    assignin(ws,['input_' inputs{k}],timeseries(values,logs{k}.Time));
end
limits=jsondecode(fileread(fullfile(base,'closed_loop','native_smo_acceptance.json')));
nominal=compare(sim(h),limits);
n=(0:999)';t=period(2)+n*period(1);valid=mod(n,31)>4;reset=false(size(n));reset([1 61 901])=true;
values={[8*sin(.2*n) 7*cos(.17*n)],[60*cos(.27*n) 55*sin(.13*n)],valid,reset};
for k=1:4,assignin(ws,['input_' inputs{k}],timeseries(values{k},t));end
set_param(h,'StopTime',num2str(t(end),17));branches=compare(sim(h),limits);
branches.reset_samples=sum(reset);branches.invalid_samples=sum(~valid);
report=struct('passed',nominal.passed&&branches.passed,'nominal',nominal,'reset_invalid',branches);
teach_writejson(outputFile,report);assert(report.passed,'sensorless:NativeSMO','Native SMO differs from the accepted equations.');
end

function result=compare(out,limits)
result=struct('passed',true,'sample_count',0,'outputs',struct);
for k=1:3
    a=out.get(['reference_' num2str(k)]);b=out.get(['native_' num2str(k)]);
    x=teach_values(a);y=teach_values(b);delta=abs(x-y);
    tolerance=limits.core_absolute_tolerance+limits.core_relative_tolerance*abs(x);
    r=struct('time_equal',isequal(a.Time,b.Time),'dimensions_equal',isequal(size(a.Data),size(b.Data)), ...
        'max_abs_difference',max(delta,[],'all'),'exact',isequal(a.Data,b.Data),'passed',false);
    r.passed=r.time_equal&&r.dimensions_equal&&all(isfinite(y),'all')&&all(delta<=tolerance,'all');
    result.outputs.(['output_' num2str(k)])=r;result.passed=result.passed&&r.passed;result.sample_count=numel(a.Time);
end
end
