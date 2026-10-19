function report = check_sensorless_modules(mdl, baselineFile, outputFile)
% Compare ordinary blocks with the accepted MATLAB Function equations offline.
% This temporary discrete check is never installed in the physical model.
base=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(base,'blocks'));
h='SMO_Core_Check';
assert(strcmp(teach_hash(baselineFile),'2672fa64eaf986d1f81f0f8f478e3a7c2b6705a50c985fddb786fd4f9f31eba1'));
new_system(h);cleanup=onCleanup(@()close_system(h,0)); %#ok<NASGU>
set_param(h,'SolverType','Variable-step','Solver','VariableStepDiscrete','StopTime','.5','ReturnWorkspaceOutputs','on');
ws=get_param(mdl,'ModelWorkspace');hw=get_param(h,'ModelWorkspace');
for key={'sless_cfg','sless_v2_cfg','sless_direction','sless_enabled','timing_control_sample'}
    assignin(hw,key{1},getVariable(ws,key{1}));
end
data=load(fullfile(base,'runs','SMO_closed_final_a','signals.mat'));
names=fieldnames(data);assert(numel(names)==100);
sources={...
 'current',data.obs_sless_v2_input_i; ...
 'voltage',data.obs_sless_v2_input_v; ...
 'valid',data.obs_sless_v2_sample_valid; ...
 'reset',data.obs_sless_v2_reset; ...
 'injection',data.obs_sless_v2_injection; ...
 'vector',data.obs_sless_v2_emf; ...
 'phase_vector',[]; ...
 'magnitude',data.obs_sless_v2_emf_magnitude};
% Reconstruct the actual compensated vector from the accepted phase chain.
c=getVariable(ws,'sless_cfg');f=getVariable(ws,'sless_v2_cfg');
old=teach_values(data.obs_sless_v2_omega_e);omega=old;omega(2:end)=old(1:end-1);omega(1)=0;
raw=timeseries(omega,data.obs_sless_v2_omega_e.Time);sources(end+1,:)={'omega_previous',raw};
v=data.obs_sless_v2_emf;values=teach_values(v);vd=zeros(numel(v.Time),2);angle=teach_values(data.obs_sless_v2_phase_correction);
for k=1:numel(v.Time)
    front=sensorless_v2_front_phase(omega(k),sensorless_v2_config_rt(f));
    a=angle(k);e=reshape(values(k,:),2,1);r=[cos(a) -sin(a);sin(a) cos(a)];
    q=r*[e(2);-e(1)];r=[cos(front) -sin(front);sin(front) cos(front)];vd(k,:)=(r*q)';
end
sources{7,2}=timeseries(vd,v.Time);
for k=1:size(sources,1)
    key=sources{k,1};value=sources{k,2};values=teach_values(value);
    if ismember(key,{'valid','reset'}),values=logical(values);end
    value=timeseries(values,value.Time);
    assignin(hw,['input_' key],value);
    add_block('simulink/Sources/From Workspace',[h '/' key], ...
        'VariableName',['input_' key],'SampleTime','timing_control_sample','Interpolate','off', ...
        'OutputAfterFinalValue','Holding final value');
    if ismember(key,{'current','voltage','injection','vector','phase_vector'})
        add_block('simulink/Math Operations/Reshape',[h '/' key '_column'],'OutputDimensionality','Column vector (2-D)');
        add_line(h,[key '/1'],[key '_column/1']);
    end
end
for row={'cfg','sless_cfg';'front','sless_v2_cfg';'direction','sless_direction';'enabled','sless_enabled'}'
    add_block('simulink/Sources/Constant',[h '/' row{1}],'Value',row{2},'VectorParams1D','off');
end
spec={...
 'smo','滑模观测/隐式校正',{'current_column','voltage_column','valid','reset','cfg'},3; ...
 'emf','反电动势/滤波校正',{'injection_column','omega_previous','direction','valid','reset','cfg','front'},6; ...
 'pll','锁相环/归一化PLL',{'phase_vector_column','magnitude','direction','valid','reset','enabled','cfg'},6};
for s=1:size(spec,1)
    for version={'reference','modules'}
        key=[spec{s,1} '_' version{1}];
        if strcmp(version{1},'reference'),reference_chart(h,key,s,base);
        else,add_block([mdl '/无感观测/' spec{s,2}],[h '/' key]);end
        inputs=spec{s,3};for k=1:numel(inputs),add_line(h,[inputs{k} '/1'],[key '/' num2str(k)]);end
        for k=1:spec{s,4}
            sink=[key '_' num2str(k)];add_block('simulink/Sinks/To Workspace',[h '/' sink], ...
                'VariableName',sink,'SaveFormat','Timeseries','SampleTime','timing_control_sample','MaxDataPoints','inf');
            add_line(h,[key '/' num2str(k)],[sink '/1']);
        end
    end
end
out=sim(h);limits=jsondecode(fileread(fullfile(base,'closed_loop','modules_acceptance.json')));
nominal=compare_outputs(out,spec,limits);
% Explicit state-transition inputs are confined to this disposable equation check.
period=getVariable(ws,'timing_control_sample');t=period(2)+(0:999)'*period(1);n=(0:999)';
valid=mod(n,31)>4;reset=false(size(n));reset([1 61 901])=true;
test=struct('current',[8*sin(.2*n) .3+7*cos(.17*n)], ...
    'voltage',[14*cos(.27*n) 12*sin(.13*n)],'valid',valid,'reset',reset, ...
    'injection',[14*tanh(6*sin(.1*n)) 14*tanh(6*cos(.11*n))], ...
    'vector',[3*cos(.01*n) 3*sin(.01*n)],'phase_vector',[3*cos(.01*n) 3*sin(.01*n)], ...
    'magnitude',3+zeros(size(n)),'omega_previous',4000*sin(.03*n));
for key=fieldnames(test)',assignin(hw,['input_' key{1}],timeseries(test.(key{1}),t));end
testCfg=c;testCfg(13)=40;assignin(hw,'sless_cfg',testCfg);
set_param(h,'StopTime',num2str(t(end),17));out=sim(h);branches=compare_outputs(out,spec,limits);
sat=out.get('pll_reference_5');branches.coverage=struct('reset_samples',sum(reset), ...
    'invalid_samples',sum(~valid),'saturated_samples',nnz(sat.Data));
branches.passed=branches.passed&&branches.coverage.saturated_samples>0;
assignin(hw,'sless_direction',0);assignin(hw,'sless_enabled',0);out=sim(h);disabled=compare_outputs(out,spec,limits);
report=struct('passed',nominal.passed&&branches.passed&&disabled.passed,'source_run','SMO_closed_final_a', ...
    'nominal',nominal,'reset_invalid_limit',branches,'disabled_direction_zero',disabled);
teach_writejson(outputFile,report);assert(report.passed,'sensorless:ModuleEquivalence','Core equations differ from accepted implementation.');
end

function report=compare_outputs(out,spec,limits)
report=struct('passed',true,'sample_count',0,'outputs',struct);
for s=1:size(spec,1)
    for k=1:spec{s,4}
        key=[spec{s,1} '_' num2str(k)];a=out.get([spec{s,1} '_reference_' num2str(k)]);b=out.get([spec{s,1} '_modules_' num2str(k)]);
        x=teach_values(a);y=teach_values(b);delta=abs(x-y);tol=limits.core_isolation.absolute_tolerance+limits.core_isolation.relative_tolerance*abs(x);
        item=struct('time_equal',isequal(a.Time,b.Time),'dimensions_equal',isequal(size(a.Data),size(b.Data)), ...
            'max_abs_difference',max(delta(:)),'finite',all(isfinite(y(:))),'passed',false);
        item.passed=item.time_equal&&item.dimensions_equal&&item.finite&&all(delta(:)<=tol(:));
        report.outputs.(key)=item;report.passed=report.passed&&item.passed;report.sample_count=numel(a.Time);
    end
end
end

function reference_chart(h,key,index,base)
files={fullfile(base,'blocks','sless_smo_block.m'), ...
    fullfile(base,'robust','integration','blocks','sless_v2_emf_block.m'), ...
    fullfile(base,'blocks','sless_pll_block.m')};
add_block('simulink/User-Defined Functions/MATLAB Function',[h '/' key]);
rt=sfroot;chart=rt.find('-isa','Stateflow.EMChart','Path',[h '/' key]);chart.Script=fileread(files{index});
chart.ChartUpdate='DISCRETE';chart.SampleTime='timing_control_sample';chart.VectorOutputs1D=false;
data=chart.find('-isa','Stateflow.Data');
vectors={{'current','voltage','estimate','residual','injection'}, {'injection','emf','vector'}, {'vector'}};
for k=1:numel(data)
    n=data(k).Name;data(k).Props.Array.Size='1';data(k).DataType='double';
    if ismember(n,vectors{index}),data(k).Props.Array.Size='[2 1]';end
    if strcmp(n,'cfg'),data(k).Props.Array.Size='[1 18]';end
    if strcmp(n,'front_cfg'),data(k).Props.Array.Size='[1 35]';end
    if ismember(n,{'valid','reset','saturated'}),data(k).DataType='boolean';end
end
end
