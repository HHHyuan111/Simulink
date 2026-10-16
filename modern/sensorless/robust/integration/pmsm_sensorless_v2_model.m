function result=pmsm_sensorless_v2_model(action,mdl,interference_s)
% Build a removable local adaptation of the accepted N2 observer layer.
% No reference-model copying, original block edits, or SLX saving.
if nargin<2,mdl='PMSM_FOC_R2026a';end
if nargin<3,interference_s=0;end
if strcmp(action,'remove'),result=pmsm_sensorless_model('remove',mdl);return;end
assert(strcmp(action,'install'));
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));
addpath(base,fileparts(here),here);
pmsm_sensorless_model('install',mdl);root=[mdl '/无感观测'];
try
 % Reuse the established eight-part local layout, pure equations and Scopes.
 % Namespace every new internal signal, including visibility and Scope taps.
 for type={'Goto','From','GotoTagVisibility'}
  blocks=find_system(root,'LookUnderMasks','all','BlockType',type{1});
  for k=1:numel(blocks)
   tag=get_param(blocks{k},'GotoTag');
   if startsWith(tag,'SLess_'),set_param(blocks{k},'GotoTag',strrep(tag,'SLess_','SLessV2_'));end
  end
 end
 logs=find_system(root,'LookUnderMasks','all','BlockType','ToWorkspace');
 for k=1:numel(logs),set_param(logs{k},'VariableName',strrep(get_param(logs{k},'VariableName'),'obs_sless_','obs_sless_v2_'));end
 mask=Simulink.Mask.get(root);mask.Type='Local sensorless nonideal v2';
 mask.Display="disp('非理想无感旁路')";
 fields={'analog_hat_hz','估计模拟低通 [Hz]','4500';'digital_hat_hz','数字低通 [Hz]','2000';...
  'deadtime_hat_us','估计死区 [μs]','.4375';'ron_hat_ohm','估计导通电阻 [Ω]','.012';...
  'vf_hat_V','估计二极管压降 [V]','.6';'observer_budget_us','观测计算预算 [μs]','3';...
  'foc_budget_us','FOC计算预算 [μs]','5';'guard_us','截止期裕量 [μs]','2'};
 fields=[fields;{'gain_hat_ABC','观测标定增益 ABC','[1.008 .994 1.002]';...
  'bias_hat_ABC_A','观测标定零偏 ABC [A]','[.04 -.02 .005]';...
  'adc_span_A','已配置ADC正负量程 [A]',get_param([mdl '/采样设置'],'adc_span');...
  'adc_bits','已配置ADC位数',get_param([mdl '/采样设置'],'adc_bits')}];
 for k=1:size(fields,1),mask.addParameter('Name',fields{k,1},'Prompt',fields{k,2},'Value',fields{k,3},'Type','edit','Enabled','off','Tunable','off');end
 olddims=get_param([root '/区间电压/原阈值尺寸'],'Dimensions');
 currentdims=get_param([root '/采样输入/原电流尺寸'],'Dimensions');
 % Tap the actual configured ADC current before the digital filter.
 tap=[mdl '/采样设置/无感ADC原始'];
 p=get_param([mdl '/采样设置/记录_log_iabc_adc'],'PortHandles');src=get_param(get_param(p.Inport,'Line'),'SrcPortHandle');
 add_block('simulink/Signal Routing/Goto',tap,'Position',[800 405 1010 430],...
  'GotoTag','SLessV2ADC','TagVisibility','global');
 p=get_param(tap,'PortHandles');add_line([mdl '/采样设置'],src,p.Inport,'autorouting','on');
 backup=get_param(root,'UserData');backup.external_blocks{end+1}=tap;set_param(root,'UserData',backup);
 ws=get_param(mdl,'ModelWorkspace');assignin(ws,'sless_v2_interference_s',interference_s);
 constant(root,'适配参数','sless_v2_cfg','SLessV2_front_cfg',[25 220 130 245]);

 p=[root '/采样输入'];Simulink.SubSystem.deleteContents(p);
 inputs={'任务时刻','SLessV2_time';'滤后测量','Iabc_meas';'原始ADC','SLessV2ADC';...
  'ADC状态','ObsADCTiming';'适配参数','SLessV2_front_cfg'};
 clock(p,'任务时钟','timing_control_sample',[20 350 130 375]);route(p,'任务时钟',1,'SLessV2_time',[160 350 330 375]);
 feed(p,inputs,'校准对齐','sless_v2_measure_block.m','timing_control_sample',...
  {'t','1';'measured','[3 1]';'adc','[3 1]';'diag','[1 15]';'cfg','[1 35]';'current','[2 1]';...
   'calibrated','[3 1]';'valid','1';'adc_valid','1';'timing_valid','1';'meta','[12 1]'},...
  {'valid','adc_valid','timing_valid'});
 % Keep the original dimensions fixed before reshaping either measurement.
 for j=2:3
  src=inputs{j,1};ln=get_param(get_param([p '/校准对齐'],'PortHandles').Inport(j),'Line');delete_line(ln);
  part(p,'simulink/Signal Attributes/Signal Specification',[src '_原尺寸'],[170 25+70*j 210 60+70*j],'Dimensions',currentdims);
  part(p,'simulink/Math Operations/Reshape',[src '_列向量'],[225 25+70*j 270 60+70*j],'OutputDimensionality','Column vector (2-D)');
  wire(p,src,1,[src '_原尺寸'],1);wire(p,[src '_原尺寸'],1,[src '_列向量'],1);wire(p,[src '_列向量'],1,'校准对齐',j);
 end
 tags={'SLessV2_current','SLessV2_current_ABC','SLessV2_sample_valid','SLessV2_adc_valid','SLessV2_timing_valid','SLessV2_measure_meta'};
 for k=1:numel(tags),route(p,'校准对齐',k,tags{k},[510 30+55*k 725 55+55*k]);end

 p=[root '/区间电压'];Simulink.SubSystem.deleteContents(p);
 clock(p,'原生时钟','timing_h',[20 610 130 635]);route(p,'原生时钟',1,'SLessV2_native_time',[160 610 330 635]);
 inputs={'原生时刻','SLessV2_native_time';'生效阈值','SLessAppliedThreshold';'实际载波','ObsCarrier';'控制母线','UDC';...
  'CCR状态','ObsPWMTiming';'校准电流','SLessV2_current_ABC';'历史反电势','SLessV2_vector_previous';...
  '历史速度','SLessV2_omega_previous';'方向','SLessV2_direction';'适配参数','SLessV2_front_cfg'};
 feed(p,inputs,'非理想累计','sless_v2_voltage_block.m','timing_h',...
  {'t','1';'threshold','[1 3]';'carrier','1';'bus','1';'diag','[1 12]';'current','[3 1]';...
   'vector_previous','[2 1]';'omega_previous','1';'direction','1';'cfg','[1 35]';...
   'weighted','[2 1]';'interval','[2 1]';'ready','1';'native','[36 1]';'uncertainty','[2 1]'}, {'ready'});
 pch=get_param([p '/非理想累计'],'PortHandles');delete_line(get_param(pch.Inport(2),'Line'));
 part(p,'simulink/Signal Attributes/Signal Specification','原阈值尺寸',[170 120 215 150],'Dimensions',olddims);
 part(p,'simulink/Math Operations/Reshape','阈值行向量',[225 120 270 150],'OutputDimensionality','Row vector (2-D)');
 wire(p,'生效阈值',1,'原阈值尺寸',1);wire(p,'原阈值尺寸',1,'阈值行向量',1);wire(p,'阈值行向量',1,'非理想累计',2);
 tags={'SLessV2_voltage','SLessV2_interval','SLessV2_ready','SLessV2_native','SLessV2_voltage_uncertainty'};
 for k=1:numel(tags),route(p,'非理想累计',k,tags{k},[530 30+55*k 750 55+55*k]);end
 for k=1:3
  source=['累计' num2str(k)];hold=['任务发布' num2str(k)];from(p,source,tags{k},[20 700+55*k 175 725+55*k]);
  part(p,'simulink/Discrete/Zero-Order Hold',hold,[230 695+55*k 325 735+55*k],'SampleTime','timing_control_sample');
  wire(p,source,1,hold,1);route(p,hold,1,[tags{k} '_sample'],[380 700+55*k 610 725+55*k]);
 end
 from(p,'CCR序号','ObsPWMTiming',[20 950 175 975]);
 part(p,'simulink/User-Defined Functions/Fcn','生效序号',[230 945 325 980],'Expr','u(7)');
 wire(p,'CCR序号',1,'生效序号',1);route(p,'生效序号',1,'SLessV2_sequence',[380 950 610 975]);

 p=[root '/反电动势'];ch=sfroot;ch=ch.find('-isa','Stateflow.EMChart','Path',[p '/滤波校正']);
 ch.Script=fileread(fullfile(here,'blocks','sless_v2_emf_block.m'));
 data=ch.find('-isa','Stateflow.Data','Name','front_cfg');data.Props.Array.Size='[1 35]';data.DataType='double';
 data=ch.find('-isa','Stateflow.Data','Name','front_phase');data.Props.Array.Size='1';data.DataType='double';
 from(p,'前端滤波参数','SLessV2_front_cfg',[20 420 165 445]);wire(p,'前端滤波参数',1,'滤波校正',7);
 route(p,'滤波校正',6,'SLessV2_front_phase',[410 405 600 430]);
 from(p,'校正反电势','SLessV2_vector',[20 500 165 525]);
 part(p,'simulink/Discrete/Unit Delay','反电势历史',[215 495 325 535],'SampleTime','timing_control_sample','InitialCondition','[0;0]');
 wire(p,'校正反电势',1,'反电势历史',1);route(p,'反电势历史',1,'SLessV2_vector_previous',[380 500 610 525]);

 p=[root '/发布许可'];part(root,'built-in/SubSystem','发布许可',[990 300 1140 360]);
 feed(p,{'原生时刻','SLessV2_native_time';'采样角度','SLessV2_theta';'电角速度','SLessV2_omega';...
  '观测锁定','SLessV2_valid';'ADC有效','SLessV2_adc_valid';'时序许可','SLessV2_timing_valid';...
  '适配参数','SLessV2_front_cfg'},'完成后发布','sless_v2_queue_block.m','timing_h',...
  {'t','1';'theta','1';'omega','1';'observer_valid','1';'input_valid','1';'timing_valid','1';'cfg','[1 35]';...
   'values','[13 1]';'permit','1';'reason','1'},{'observer_valid','input_valid','timing_valid','permit'});
 for row={1,'SLessV2_publication';2,'SLessV2_control_permit';3,'SLessV2_deny_reason'}'
  route(p,'完成后发布',row{1},row{2},[530 65*row{1} 760 25+65*row{1}]);
 end
 % Native diagnostics and front-end phase are separate from quality validity.
 p=[root '/观测'];extra={'current_ABC','SLessV2_current_ABC','timing_control_sample';...
  'measurement','SLessV2_measure_meta','timing_control_sample';'front_phase','SLessV2_front_phase','timing_control_sample';...
  'voltage_uncertainty','SLessV2_voltage_uncertainty','timing_control_sample';...
  'publication','SLessV2_publication','timing_h';'control_permit','SLessV2_control_permit','timing_h';...
  'deny_reason','SLessV2_deny_reason','timing_h';'adc_valid','SLessV2_adc_valid','timing_h';'timing_valid','SLessV2_timing_valid','timing_h'};
 for k=1:size(extra,1)
  n=['V2_' extra{k,1}];from(p,n,extra{k,2},[1900 50+55*k 2110 75+55*k]);
  part(p,'simulink/Sinks/To Workspace',['记录_' n],[2180 50+55*k 2430 75+55*k],...
   'VariableName',['obs_sless_v2_' extra{k,1}],'SaveFormat','Timeseries','SampleTime',extra{k,3},'MaxDataPoints','inf');
  wire(p,n,1,['记录_' n],1);
 end
 % Keep quality lock distinct from the asynchronous control permit in UI.
 ph=get_param([p '/角度与速度_信号4/通道1'],'PortHandles');set_param(get_param(ph.Outport,'Line'),'Name','观测锁定');
 scope=[p '/许可与节拍'];part(p,[mdl '/跟踪观测/总览'],'许可与节拍',[1300 350 1440 420],...
  'NumInputPorts','4','SampleTime','timing_h','OpenFcn','','StopFcn','');
 scopeRows={'SLessV2_control_permit','u(1)','控制许可','';...
  'SLessV2_deny_reason','u(1)','禁止原因位','';'SLessV2_publication','u(4)*1e6','数据年龄','μs';...
  'SLessV2_publication','(u(3)-u(2))*1e6','已发布包计算延迟','μs'};
 for k=1:4
  source=['许可来源' num2str(k)];convert=['许可数值' num2str(k)];pick=['许可量' num2str(k)];
  from(p,source,scopeRows{k,1},[1900 700+60*k 2100 725+60*k]);
  part(p,'simulink/Signal Attributes/Data Type Conversion',convert,[2140 700+60*k 2180 725+60*k],'OutDataTypeStr','double');
  part(p,'simulink/User-Defined Functions/Fcn',pick,[2220 700+60*k 2420 725+60*k],'Expr',scopeRows{k,2});
  wire(p,source,1,convert,1);wire(p,convert,1,pick,1);wire(p,pick,1,'许可与节拍',k);
 end
 sc=get_param(scope,'ScopeConfiguration');sc.LayoutDimensions=[2 2];sc.FrameBasedProcessing=false;
 sc.OpenAtSimulationStart=false;sc.DataLogging=false;sc.ShowLegend=true;sc.TimeSpan='0.005';
 for k=1:4,sc.ActiveDisplay=num2str(k);sc.Title=scopeRows{k,3};sc.YLabel=scopeRows{k,4};sc.ShowGrid=true;end
 sc.ActiveDisplay='1';
 % All internal Gotos have an explicit visibility inside this single layer.
 gotos=find_system(root,'LookUnderMasks','all','BlockType','Goto');
 visible=find_system(root,'LookUnderMasks','all','BlockType','GotoTagVisibility');
 existing=cellfun(@(b)get_param(b,'GotoTag'),visible,'UniformOutput',false);
 for k=1:numel(gotos)
  tag=get_param(gotos{k},'GotoTag');if ismember(tag,existing),continue;end
  part(root,'simulink/Signal Routing/Goto Tag Visibility',['可见域_' tag],...
   [25+240*mod(k-1,5) 750+35*floor((k-1)/5) 245+240*mod(k-1,5) 775+35*floor((k-1)/5)],'GotoTag',tag,'ShowName','off');
 end
 set_param(mdl,'InitFcn',strrep(get_param(mdl,'InitFcn'),'pmsm_sensorless_init(bdroot);','pmsm_sensorless_v2_init(bdroot);'));
 pmsm_sensorless_v2_init(mdl);result=root;
catch err
 try,pmsm_sensorless_model('remove',mdl);catch rollback,err=addCause(err,rollback);end
 rethrow(err);
end

 function feed(parent,rows,name,source,period,sizes,boolean)
  part(parent,'simulink/User-Defined Functions/MATLAB Function',name,[300 45 460 85+45*size(rows,1)]);
  rt=sfroot;chart=rt.find('-isa','Stateflow.EMChart','Path',[parent '/' name]);
  chart.Script=fileread(fullfile(here,'blocks',source));chart.ChartUpdate='DISCRETE';chart.SampleTime=period;chart.VectorOutputs1D=false;
  for j=1:size(sizes,1)
   data=chart.find('-isa','Stateflow.Data','Name',sizes{j,1});data.Props.Array.Size=sizes{j,2};
   data.DataType='double';if ismember(sizes{j,1},boolean),data.DataType='boolean';end
  end
  for j=1:size(rows,1),from(parent,rows{j,1},rows{j,2},[20 40+55*(j-1) 165 65+55*(j-1)]);wire(parent,rows{j,1},1,name,j);end
 end
end
function part(p,lib,n,pos,varargin)
if strcmp(lib,'simulink/Sources/Constant'),varargin=[varargin {'VectorParams1D','off'}];end
add_block(lib,[p '/' n],'Position',pos,varargin{:});
end
function wire(p,a,ap,b,bp),add_line(p,[a '/' num2str(ap)],[b '/' num2str(bp)],'autorouting','on');end
function from(p,n,tag,pos),part(p,'simulink/Signal Routing/From',n,pos,'GotoTag',tag);end
function route(p,src,port,tag,pos)
n=['发布_' tag];part(p,'simulink/Signal Routing/Goto',n,pos,'GotoTag',tag,'TagVisibility','scoped');wire(p,src,port,n,1);
end
function constant(p,n,value,tag,pos)
part(p,'simulink/Sources/Constant',n,pos,'Value',value);route(p,n,1,tag,pos+[145 0 230 0]);
end
function clock(p,n,rate,pos)
part(p,'simulink/Sources/Digital Clock',n,pos,'SampleTime',rate);
end
