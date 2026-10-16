function info=sensorless_n3_faults(mdl,testcase)
% Observer-only sampled faults. Never modify measurement/feedback in the plant.
root=[mdl '/无感观测'];info=struct('noise_samples',0,'noise_empirical_rms_ABC_A',[],...
 'missing_ticks',[],'reset_tick',[]);
if isfield(testcase,'noise')
 p=[root '/采样输入'];ws=get_param(mdl,'ModelWorkspace');Ts=50e-6;
 ticks=(0:round(testcase.duration_s/Ts))';stream=RandStream('mt19937ar','Seed',testcase.noise.seed);
 noise=testcase.noise.rms_A*randn(stream,3,numel(ticks))';
 assignin(ws,'sless_n3_noise',[ticks*Ts noise]);
 add_block('simulink/Sources/From Workspace',[p '/N3_ABC噪声'],'Position',[25 370 180 400],...
  'VariableName','sless_n3_noise','SampleTime','timing_control_sample','Interpolate','off','OutputAfterFinalValue','Holding final value');
 add_block('simulink/Math Operations/Reshape',[p '/N3_噪声列'],'Position',[215 365 300 405],...
  'OutputDimensionality','Column vector (2-D)');
 add_block('simulink/Math Operations/Sum',[p '/N3_测量扰动'],'Position',[160 30 185 85],'Inputs','++');
 delete_line(p,'三相电流/1','原电流尺寸/1');
 add_line(p,'三相电流/1','N3_测量扰动/1','autorouting','on');
 add_line(p,'N3_ABC噪声/1','N3_噪声列/1','autorouting','on');add_line(p,'N3_噪声列/1','N3_测量扰动/2','autorouting','on');
 add_line(p,'N3_测量扰动/1','原电流尺寸/1','autorouting','on');
 add_block('simulink/Sinks/To Workspace',[p '/N3_噪声记录'],'Position',[360 370 560 400],...
  'VariableName','obs_sless_noise_abc','SaveFormat','Timeseries','SampleTime','timing_control_sample','MaxDataPoints','inf');
 add_line(p,'N3_噪声列/1','N3_噪声记录/1','autorouting','on');
 info.noise_samples=numel(ticks);info.noise_empirical_rms_ABC_A=sqrt(mean(noise.^2));
end
if isfield(testcase,'invalid_interval_s')
 p=[root '/采样输入'];insert_gate(p,'有效样本','SLess_sample_valid','AND',...
  '!(floor(u/0.00005+0.5)>=12000 && floor(u/0.00005+0.5)<12005)');
 info.missing_ticks=[12000 12004];
end
if isfield(testcase,'reset_time_s')
 p=[root '/执行许可'];insert_gate(p,'复位','SLess_reset','OR','floor(u/0.00005+0.5)==12000');info.reset_tick=12000;
end
end
function insert_gate(p,source,tag,op,expr)
add_block('simulink/Signal Routing/From',[p '/N3_任务时刻'],'Position',[20 400 175 425],'GotoTag','SLess_time');
add_block('simulink/User-Defined Functions/Fcn',[p '/N3_故障窗口'],'Position',[220 395 450 430],'Expr',expr);
add_block('simulink/Logic and Bit Operations/Logical Operator',[p '/N3_故障门'],'Position',[470 160 520 210],'Operator',op,'Inputs','2');
delete_line(p,[source '/1'],['发布_' tag '/1']);
add_line(p,[source '/1'],'N3_故障门/1','autorouting','on');add_line(p,'N3_任务时刻/1','N3_故障窗口/1','autorouting','on');
add_line(p,'N3_故障窗口/1','N3_故障门/2','autorouting','on');add_line(p,'N3_故障门/1',['发布_' tag '/1'],'autorouting','on');
end
