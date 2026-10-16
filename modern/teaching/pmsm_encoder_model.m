function result=pmsm_encoder_model(action,mdl)
% Reversible, visible extension of the original angle chain; never saves SLX.
if nargin<1,action='install';end
if nargin<2,mdl='PMSM_FOC_R2026a';end
path=[mdl '/角度设置/编码器'];
if strcmp(action,'installed'),result=bdIsLoaded(mdl)&&getSimulinkBlockHandle(path)>0;return;end
assert(bdIsLoaded(mdl)&&strcmp(get_param(mdl,'SimulationStatus'),'stopped'),'先加载并停止原模型。');
if strcmp(action,'remove')
 if getSimulinkBlockHandle(path)<0,result=false;return;end
 if exist('pmsm_encoder_speed_model','file')==2&&pmsm_encoder_speed_model('installed',mdl),pmsm_encoder_speed_model('remove',mdl);end
 backup=get_param(path,'UserData');assert(isstruct(backup)&&isfield(backup,'destinations'),'缺少编码器连接备份。');
 ports=get_param(path,'PortHandles');
 for port=[ports.Inport ports.Outport],attached=get_param(port,'Line');if attached>=0,delete_line(attached);end,end
 delete_block(path);
 for block=backup.root_blocks
  if getSimulinkBlockHandle(block{1})>0
   ph=get_param(block{1},'PortHandles');attached=get_param(ph.Inport,'Line');
   if attached>=0,original=get_param(attached,'SrcPortHandle');if original>=0,delete_line(mdl,original,ph.Inport);end,end
   delete_block(block{1});
  end
 end
 for dst=backup.destinations(:)'
  line=get_param(dst,'Line');
  if line<0,add_line([mdl '/角度设置'],backup.source,dst,'autorouting','on');
  else,assert(get_param(line,'SrcPortHandle')==backup.source,'原连接被另外修改。');end
 end
 line=get_param(backup.source,'Line');set_param(line,'Name',backup.line_name);
 set_param(mdl,'Dirty',backup.dirty);result=true;return;
end
assert(strcmp(action,'install'),'未知编码器操作。');assert(getSimulinkBlockHandle(path)<0,'编码器模块已经接入。');
parent=[mdl '/角度设置'];src=get_param([parent '/总选择'],'PortHandles');line=get_param(src.Outport,'Line');
backup=struct('source',src.Outport,'destinations',get_param(line,'DstPortHandle'), ...
 'line_name',get_param(line,'Name'),'dirty',get_param(mdl,'Dirty'),'root_blocks',{{}});
add_block('built-in/SubSystem',path,'Position',[1090 420 1190 465],'BackgroundColor','[0.80 0.89 0.98]');
set_param(path,'UserData',backup);
try
 mask=Simulink.Mask.create(path);mask.Type='编码器角度';mask.Display="disp('编码器')";
 mask.Description='机械计数角度路径；不模拟ABZ电气边沿或Z相。方向为传感器坐标与软件修正两部分，零位为手动设定。关闭时原角度直通。';
 entries={'encoder_on','checkbox','编码器','off';'counts','edit','每机械转计数','10000'; ...
  'sensor_dir','edit','原始计数方向','-1';'direction','edit','软件方向修正','-1'; ...
  'zero_deg','edit','零位 [电角度 °]','0';'delay_on','checkbox','角度延迟','off';'delay_cycles','edit','延迟 [控制拍]','2'};
 for j=1:size(entries,1),mask.addParameter('Name',entries{j,1},'Type',entries{j,2},'Prompt',entries{j,3},'Value',entries{j,4},'Tunable','off');end
 mask.Initialization=char(join(["validateattributes(counts,{'double'},{'scalar','integer','>=',2,'<=',1000000});" newline ...
  "assert(ismember(sensor_dir,[-1 1])&&ismember(direction,[-1 1]),'方向只能为±1。');" newline ...
  "validateattributes(zero_deg,{'double'},{'scalar','real','finite','>=',-180,'<=',180});" newline ...
  "validateattributes(delay_cycles,{'double'},{'scalar','integer','>=',0,'<=',20});" newline ...
  "if encoder_on, a=[bdroot '/角度设置']; assert(all(cellfun(@(k)strcmp(get_param(a,k),'off'),{'bias_on','quant_on','delay_on'})),'编码器对照不能重复叠加旧角度误差。'); end"],''));
 addPart(path,'built-in/Inport','原角度',[25 295 55 315]);
 addPart(path,'simulink/Signal Routing/From','机械真值',[25 55 95 75],'GotoTag','encoder_mechanical_truth');
 addPart(path,'simulink/Math Operations/Gain','计数方向',[125 45 185 85],'Gain','sensor_dir*counts/(2*pi)');
 addPart(path,'simulink/Math Operations/Rounding Function','计数边沿',[215 45 275 85],'Operator','floor');
 addPart(path,'simulink/User-Defined Functions/Fcn','单圈计数',[305 45 405 85],'Expr','u-counts*floor(u/counts)');
 addPart(path,'simulink/Sources/Clock','时钟',[305 130 345 150]);
 addPart(path,'simulink/Sources/Step','读取有效',[305 190 365 215], ...
  'Time','max(0,sum(timing_control_sample(2:end))-timing_h/4)','Before','0','After','1','SampleTime','timing_h');
 addPart(path,'simulink/Signal Routing/Mux','读取输入',[435 50 440 210],'Inputs','3');
 addPart(path,'simulink/Discrete/Zero-Order Hold','读取',[475 95 535 145],'SampleTime','timing_control_sample');
 addPart(path,'simulink/Signal Routing/Demux','读取拆分',[565 60 570 205],'Outputs','3');
 addPart(path,'simulink/Math Operations/Gain','方向修正',[610 40 675 80],'Gain','direction');
 addPart(path,'simulink/User-Defined Functions/Fcn','修正计数',[705 40 805 80],'Expr','u-counts*floor(u/counts)');
 addPart(path,'simulink/Math Operations/Gain','机械角度',[835 40 900 80],'Gain','2*pi/counts');
 addPart(path,'simulink/Math Operations/Gain','电角度',[930 40 990 80],'Gain','p');
 addPart(path,'simulink/Sources/Constant','零位',[930 125 990 155],'Value','zero_deg*pi/180');
 addPart(path,'simulink/Math Operations/Sum','零位修正',[1020 45 1040 75],'Inputs','++');
 addPart(path,'simulink/User-Defined Functions/Fcn','电角环绕',[1070 40 1190 80],'Expr','u-2*pi*floor(u/(2*pi))');
 addPart(path,'simulink/Signal Routing/Mux','样本包',[1220 55 1225 200],'Inputs','4');
 addPart(path,'simulink/Discrete/Delay','传递延迟',[1260 40 1340 90], ...
  'DelayLength','delay_cycles','InitialCondition','0','SampleTime','timing_control_sample');
 addPart(path,'simulink/Sources/Constant','延迟开关',[1260 230 1330 255],'Value','delay_on');
 addPart(path,'simulink/Signal Routing/Switch','延迟选择',[1380 105 1420 185],'Criteria','u2 >= Threshold','Threshold','0.5');
 addPart(path,'simulink/Signal Routing/Demux','样本拆分',[1460 85 1465 215],'Outputs','4');
 addPart(path,'simulink/Sources/Constant','编码器开关',[1475 270 1555 295],'Value','encoder_on');
 addPart(path,'simulink/Signal Routing/Switch','角度选择',[1590 270 1630 350],'Criteria','u2 >= Threshold','Threshold','0.5');
 addPart(path,'built-in/Outport','控制角度',[1690 300 1720 320]);
 wire(path,'机械真值',1,'计数方向',1);wire(path,'计数方向',1,'计数边沿',1);wire(path,'计数边沿',1,'单圈计数',1);
 wire(path,'单圈计数',1,'读取输入',1);wire(path,'时钟',1,'读取输入',2);wire(path,'读取有效',1,'读取输入',3);
 wire(path,'读取输入',1,'读取',1);wire(path,'读取',1,'读取拆分',1);
 wire(path,'读取拆分',1,'方向修正',1);wire(path,'方向修正',1,'修正计数',1);wire(path,'修正计数',1,'机械角度',1);
 wire(path,'机械角度',1,'电角度',1);wire(path,'电角度',1,'零位修正',1);wire(path,'零位',1,'零位修正',2);wire(path,'零位修正',1,'电角环绕',1);
 wire(path,'电角环绕',1,'样本包',1);wire(path,'读取拆分',2,'样本包',2);wire(path,'读取拆分',3,'样本包',3);wire(path,'读取拆分',1,'样本包',4);
 wire(path,'样本包',1,'传递延迟',1);wire(path,'传递延迟',1,'延迟选择',1);wire(path,'延迟开关',1,'延迟选择',2);wire(path,'样本包',1,'延迟选择',3);
 wire(path,'延迟选择',1,'样本拆分',1);wire(path,'样本拆分',1,'角度选择',1);wire(path,'编码器开关',1,'角度选择',2);wire(path,'原角度',1,'角度选择',3);wire(path,'角度选择',1,'控制角度',1);
 addPart(path,'simulink/Signal Routing/Mux','观测',[1250 420 1255 750],'Inputs','12');
 sources={'读取拆分',1;'修正计数',1;'机械角度',1;'电角环绕',1;'角度选择',1;'读取拆分',2;'样本拆分',2;'样本拆分',3;'编码器开关',1;'延迟开关',1;'样本拆分',4;'读取拆分',3};
 for j=1:size(sources,1),wire(path,sources{j,1},sources{j,2},'观测',j);end
 logBlock(path,'原始记录','log_encoder','timing_control_sample',[1310 560 1460 595]);wire(path,'观测',1,'原始记录',1);
 logBlock(path,'机械记录','log_encoder_mechanical','timing_control_sample',[25 420 200 455]);wire(path,'机械真值',1,'机械记录',1);
 addPart(path,'simulink/Signal Routing/From','Park角度',[25 510 145 530],'GotoTag','encoder_park_angle');
 addPart(path,'simulink/Signal Routing/From','逆Park角度',[25 570 145 590],'GotoTag','encoder_inverse_angle');
 addPart(path,'simulink/Signal Routing/Mux','控制使用',[220 510 225 590],'Inputs','2');
 wire(path,'Park角度',1,'控制使用',1);wire(path,'逆Park角度',1,'控制使用',2);
 logBlock(path,'使用记录','log_encoder_control','timing_control_sample',[280 535 455 570]);wire(path,'控制使用',1,'使用记录',1);
 % Tap mechanical truth before the existing electrical-angle conversion.
 truth=get_param(Simulink.ID.getHandle([mdl ':177']),'PortHandles');truthLine=get_param(truth.Inport,'Line');mechanical=get_param(truthLine,'SrcPortHandle');
 roots={'encoder_mechanical_truth',mechanical,[2600 1085 2720 1105]; ...
  'encoder_park_angle',outport(mdl,'191'),[2490 280 2610 300]; ...
  'encoder_inverse_angle',outport(mdl,'235'),[2490 485 2610 505]};
 for j=1:size(roots,1)
  name=[mdl '/' roots{j,1}];addPart(mdl,'simulink/Signal Routing/Goto',roots{j,1},roots{j,3},'GotoTag',roots{j,1},'TagVisibility','global');
  ph=get_param(name,'PortHandles');add_line(mdl,roots{j,2},ph.Inport,'autorouting','on');backup.root_blocks{end+1}=name;
  set_param(path,'UserData',backup);
 end
 delete_line(line);ph=get_param(path,'PortHandles');add_line(parent,backup.source,ph.Inport,'autorouting','on');
 for dst=backup.destinations(:)',add_line(parent,ph.Outport,dst,'autorouting','on');end
 result=path;
catch err
 pmsm_encoder_model('remove',mdl);rethrow(err);
end
end
function addPart(parent,library,name,pos,varargin)
add_block(library,[parent '/' name],'Position',pos,'ShowName','on',varargin{:});
end
function wire(parent,a,ap,b,bp)
add_line(parent,[a '/' num2str(ap)],[b '/' num2str(bp)],'autorouting','on');
end
function port=outport(mdl,sid)
ph=get_param(Simulink.ID.getHandle([mdl ':' sid]),'PortHandles');port=ph.Outport(1);
end
function logBlock(parent,name,variable,period,pos)
addPart(parent,'simulink/Sinks/To Workspace',name,pos,'VariableName',variable,'SaveFormat','Timeseries','SampleTime',period,'MaxDataPoints','inf');
end
