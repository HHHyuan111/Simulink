function record=sensorless_r2_fault_model(mdl,testcase)
% Removable local observer adaptation; scoped tags and explicit dimensions.
here=fileparts(mfilename('fullpath'));root=[mdl '/无感观测'];program=sensorless_r2_fault_program(testcase);
record=struct('program',program,'hardware_measured',false,'interrupt_overlap_supported',false);
p=[root '/执行许可'];
add_block('simulink/Sources/Constant',[p '/故障计划'],'Value',mat2str(program,17),'VectorParams1D','off','Position',[20 470 180 500]);
route(p,'故障计划',1,'SLessV2_fault_program',[220 470 420 500]);
baseTag='SLessV2_front_cfg';
if program(1)==3
 set_param([root '/发布_SLessV2_front_cfg'],'GotoTag','SLessV2_front_base');baseTag='SLessV2_front_base';
end
chart(p,'故障时刻','sless_r2_profile_block.m','timing_h',...
 {'t','1';'base','[1 35]';'program','[1 22]';'front','[1 35]';'missing','1';'reset','1';'jitter','1';'interference','1';'reference','1'},...
 {'missing','reset'},[620 320 820 660]);
tags={'SLessV2_native_time',baseTag,'SLessV2_fault_program'};
for k=1:numel(tags),input(p,['计划输入' num2str(k)],tags{k},'故障时刻',k,[430 340+65*k 600 365+65*k]);end
out={'SLessV2_fault_front','SLessV2_missing','SLessV2_external_reset','SLessV2_release_jitter','SLessV2_interference','SLessV2_fault_reference'};
if program(1)==3,out{1}='SLessV2_front_cfg';end
for k=1:numel(out)
 if k==1&&program(1)~=3
  add_block('simulink/Sinks/Terminator',[p '/非时序工况参数终止'],'Position',[900 345 925 370]);add_line(p,'故障时刻/1','非时序工况参数终止/1','autorouting','on');
 else,route(p,'故障时刻',k,out{k},[870 320+55*k 1090 345+55*k]);end
end
resetSource=find_system(p,'SearchDepth',1,'BlockType','Goto','GotoTag','SLessV2_reset');assert(numel(resetSource)==1);
set_param(resetSource{1},'GotoTag','SLessV2_base_reset');
add_block('simulink/Logic and Bit Operations/Logical Operator',[p '/合并复位'],'Operator','OR','Inputs','2','Position',[620 70 700 140]);
input(p,'原执行复位','SLessV2_base_reset','合并复位',1,[420 70 580 95]);
input(p,'外部软件复位','SLessV2_external_reset','合并复位',2,[420 115 580 140]);
route(p,'合并复位',1,'SLessV2_reset',[750 90 960 115]);
% ADC validity is independent of timing admission. Only available, nonreset
% current can anchor the causal voltage predictor.
add_block('simulink/Logic and Bit Operations/Logical Operator',[p '/允许电流锚点'],'Operator','AND','Inputs','2','Position',[620 200 700 270]);
add_block('simulink/Logic and Bit Operations/Logical Operator',[p '/非外部复位'],'Operator','NOT','Position',[420 235 500 265]);
input(p,'锚点复位','SLessV2_external_reset','非外部复位',1,[210 235 380 260]);
input(p,'锚点ADC','SLessV2_adc_valid','允许电流锚点',1,[420 190 580 215]);
add_line(p,'非外部复位/1','允许电流锚点/2','autorouting','on');route(p,'允许电流锚点',1,'SLessV2_anchor_valid',[750 210 960 235]);
p=[root '/采样输入'];replace(p,'校准对齐','sless_r2_ingress_block.m',{'missing','1';'reset','1'}, {'missing','reset'});
input(p,'丢帧状态','SLessV2_missing','校准对齐',6,[20 480 190 505]);input(p,'软件复位','SLessV2_external_reset','校准对齐',7,[20 540 190 565]);
p=[root '/区间电压'];replace(p,'非理想累计','sless_r2_voltage_block.m',{'anchor_valid','1'},{'anchor_valid'});
input(p,'电流锚点许可','SLessV2_anchor_valid','非理想累计',11,[20 1110 190 1135]);
p=[root '/发布许可'];replace(p,'完成后发布','sless_r2_queue_block.m',{'reset','1';'missing','1';'jitter','1';'diagnostic','[8 1]'}, {'reset','missing'});
input(p,'发布复位','SLessV2_external_reset','完成后发布',8,[20 480 190 505]);input(p,'发布丢帧','SLessV2_missing','完成后发布',9,[20 540 190 565]);
input(p,'发布抖动','SLessV2_release_jitter','完成后发布',10,[20 600 190 625]);route(p,'完成后发布',4,'SLessV2_fault_queue',[530 290 760 315]);
% Record actual accepted completions, including jitter and skipped captures.
add_block('simulink/User-Defined Functions/Fcn',[p '/接受完成事件'],'Expr','u(5)','Position',[850 290 1000 320]);
add_line(p,'完成后发布/4','接受完成事件/1','autorouting','on');
e=[p '/实际完成记录'];add_block('built-in/SubSystem',e,'Position',[1100 190 1310 260]);
add_block('built-in/Inport',[e '/数据'],'Position',[25 50 55 70],'PortDimensions','[13 1]');add_block('built-in/EnablePort',[e '/完成'],'Position',[95 10 115 30]);
add_block('simulink/Sinks/To Workspace',[e '/保存'],'Position',[110 45 310 75],'VariableName','obs_sless_r2_actual_publications',...
 'SaveFormat','Timeseries','SampleTime','-1','MaxDataPoints','inf');add_line(e,'数据/1','保存/1','autorouting','on');
add_line(p,'完成后发布/1','实际完成记录/1','autorouting','on');add_line(p,'接受完成事件/1','实际完成记录/Enable','autorouting','on');
p=[root '/观测'];rows={'fault_queue','SLessV2_fault_queue';'anchor_valid','SLessV2_anchor_valid';...
 'release_jitter_s','SLessV2_release_jitter';'interference_s','SLessV2_interference';'fault_reference_s','SLessV2_fault_reference'};
for k=1:size(rows,1)
 n=['故障记录来源' num2str(k)];add_block('simulink/Signal Routing/From',[p '/' n],'GotoTag',rows{k,2},'Position',[2500 900+65*k 2700 925+65*k]);
 add_block('simulink/Sinks/To Workspace',[p '/记录_' rows{k,1}],'Position',[2750 900+65*k 3000 925+65*k],...
  'VariableName',['obs_sless_r2_' rows{k,1}],'SaveFormat','Timeseries','SampleTime','timing_control_sample','MaxDataPoints','inf');
 add_line(p,[n '/1'],['记录_' rows{k,1} '/1'],'autorouting','on');
end
gotos=find_system(root,'LookUnderMasks','all','BlockType','Goto');visible=find_system(root,'LookUnderMasks','all','BlockType','GotoTagVisibility');
existing=cellfun(@(b)get_param(b,'GotoTag'),visible,'UniformOutput',false);
for k=1:numel(gotos)
 tag=get_param(gotos{k},'GotoTag');if ismember(tag,existing),continue;end
 add_block('simulink/Signal Routing/Goto Tag Visibility',[root '/可见域_' tag],'GotoTag',tag,'ShowName','off',...
  'Position',[25+300*mod(k,4) 1250+35*floor(k/4) 300+300*mod(k,4) 1275+35*floor(k/4)]);
end
record.additional_tags=numel(setdiff(cellfun(@(b)get_param(b,'GotoTag'),gotos,'UniformOutput',false),existing));
 function replace(parent,name,source,sizes,booleans)
  rt=sfroot;c=rt.find('-isa','Stateflow.EMChart','Path',[parent '/' name]);c.Script=fileread(fullfile(here,'blocks',source));
  size_data(c,sizes,booleans);
 end
 function chart(parent,name,source,period,sizes,booleans,position)
  add_block('simulink/User-Defined Functions/MATLAB Function',[parent '/' name],'Position',position);
  rt=sfroot;c=rt.find('-isa','Stateflow.EMChart','Path',[parent '/' name]);c.Script=fileread(fullfile(here,'blocks',source));
  c.ChartUpdate='DISCRETE';c.SampleTime=period;c.VectorOutputs1D=false;size_data(c,sizes,booleans);
 end
end
function size_data(c,sizes,booleans)
for k=1:size(sizes,1)
 data=c.find('-isa','Stateflow.Data','Name',sizes{k,1});assert(isscalar(data));data.Props.Array.Size=sizes{k,2};data.DataType='double';
 if ismember(sizes{k,1},booleans),data.DataType='boolean';end
end
end
function input(p,name,tag,dest,port,pos)
add_block('simulink/Signal Routing/From',[p '/' name],'GotoTag',tag,'Position',pos);add_line(p,[name '/1'],[dest '/' num2str(port)],'autorouting','on');
end
function route(p,source,port,tag,pos)
name=['发布_' tag];add_block('simulink/Signal Routing/Goto',[p '/' name],'GotoTag',tag,'TagVisibility','scoped','Position',pos);
add_line(p,[source '/' num2str(port)],[name '/1'],'autorouting','on');
end
