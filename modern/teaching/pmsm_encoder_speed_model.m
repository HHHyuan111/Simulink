function result=pmsm_encoder_speed_model(action,mdl)
% Visible speed observation only; never connects an estimate to the speed PI.
if nargin<1,action='install';end
if nargin<2,mdl='PMSM_FOC_R2026a';end
base=[mdl '/角度设置/编码器'];path=[base '/测速'];
if strcmp(action,'installed'),result=bdIsLoaded(mdl)&&getSimulinkBlockHandle(path)>0;return;end
assert(bdIsLoaded(mdl)&&strcmp(get_param(mdl,'SimulationStatus'),'stopped'));
if strcmp(action,'remove')
 if getSimulinkBlockHandle(path)<0,result=false;return;end
 if exist('pmsm_speed_feedback_model','file')==2&&pmsm_speed_feedback_model('installed',mdl),pmsm_speed_feedback_model('remove',mdl);end
 backup=get_param(path,'UserData');ports=get_param(path,'PortHandles');
 for port=ports.Inport,line=get_param(port,'Line');if line>=0,src=get_param(line,'SrcPortHandle');delete_line(base,src,port);end,end
 delete_block(path);node=backup.root_node;
 if getSimulinkBlockHandle(node)>0
  ph=get_param(node,'PortHandles');line=get_param(ph.Inport,'Line');if line>=0,src=get_param(line,'SrcPortHandle');delete_line(mdl,src,ph.Inport);end
  delete_block(node);
 end
 result=true;return;
end
assert(strcmp(action,'install')&&pmsm_encoder_model('installed',mdl)&&getSimulinkBlockHandle(path)<0);
add_block('built-in/SubSystem',path,'Position',[1570 560 1690 610],'BackgroundColor','[0.81 0.91 0.86]');
node=[mdl '/测速输入观测'];set_param(path,'UserData',struct('root_node',node));
try
 mask=Simulink.Mask.create(path);mask.Type='计数测速观测';mask.Display="disp('测速')";
 mask.Description='同一次读取上并行比较1拍、指定窗口及长窗口。仅观测，不改变速度PI输入；历史不足时输出零并标无效。';
 for row={'speed_on','checkbox','测速观测','on';'window_ticks','edit','差分窗口 [拍]','2';'long_ticks','edit','长窗口 [拍]','8'}'
  mask.addParameter('Name',row{1},'Type',row{2},'Prompt',row{3},'Value',row{4},'Tunable','off');
 end
 mask.Initialization=char(join(["validateattributes(window_ticks,{'double'},{'scalar','integer','>=',2,'<=',7});" newline ...
  "validateattributes(long_ticks,{'double'},{'scalar','integer','>',window_ticks,'<=',32});"],''));
 for k=1:3,addPart(path,'built-in/Inport',sprintf('输入%d',k),[25 55+50*(k-1) 55 75+50*(k-1)],'Port',num2str(k));end
 names={'单拍','窗口','长窗'};periods={'1','window_ticks','long_ticks'};logs={'log_speed_short','log_speed_window','log_speed_long'};
 for k=1:3
  makeWindow([path '/' names{k}],periods{k},[170 45+165*(k-1) 290 115+165*(k-1)]);
  for j=1:3,add_line(path,[sprintf('输入%d',j) '/1'],[names{k} '/' num2str(j)],'autorouting','on');end
  addPart(path,'simulink/Sinks/To Workspace',['记录' num2str(k)],[365 65+165*(k-1) 515 95+165*(k-1)], ...
   'VariableName',logs{k},'SaveFormat','Timeseries','SampleTime','timing_control_sample','MaxDataPoints','inf');
  add_line(path,[names{k} '/1'],['记录' num2str(k) '/1']);
 end
 addPart(path,'simulink/Signal Routing/From','速度环输入',[30 570 160 590],'GotoTag','speed_control_observed');
 addPart(path,'simulink/Sinks/To Workspace','输入记录',[225 565 390 595], ...
  'VariableName','log_speed_control','SaveFormat','Timeseries','SampleTime','timing_speed_sample','MaxDataPoints','inf');
 add_line(path,'速度环输入/1','输入记录/1');
 ph=get_param(path,'PortHandles');src=get_param([base '/修正计数'],'PortHandles');add_line(base,src.Outport,ph.Inport(1),'autorouting','on');
 src=get_param([base '/读取拆分'],'PortHandles');add_line(base,src.Outport(2),ph.Inport(2),'autorouting','on');add_line(base,src.Outport(3),ph.Inport(3),'autorouting','on');
 addPart(mdl,'simulink/Signal Routing/Goto','测速输入观测',[365 360 480 380],'GotoTag','speed_control_observed','TagVisibility','global');
 input=get_param(Simulink.ID.getHandle([mdl ':190']),'PortHandles');dest=get_param(node,'PortHandles');add_line(mdl,input.Outport,dest.Inport,'autorouting','on');
 result=path;
catch err
 pmsm_encoder_speed_model('remove',mdl);rethrow(err);
end
end
function makeWindow(path,window,pos)
add_block('built-in/SubSystem',path,'Position',pos);mask=Simulink.Mask.create(path);
mask.addParameter('Name','window','Type','edit','Prompt','窗口 [拍]','Value',window,'Tunable','off');mask.Display="disp([num2str(window) '拍'])";
for k=1:3,addPart(path,'built-in/Inport',sprintf('输入%d',k),[25 55+50*(k-1) 55 75+50*(k-1)],'Port',num2str(k));end
addPart(path,'simulink/Signal Routing/Mux','读取包',[105 55 110 175],'Inputs','3');
for k=1:3,wire(path,sprintf('输入%d',k),1,'读取包',k);end
addPart(path,'simulink/Discrete/Delay','窗口历史',[155 100 245 140],'DelayLength','window','InitialCondition','0','SampleTime','timing_control_sample');
addPart(path,'simulink/Signal Routing/Demux','历史拆分',[280 60 285 190],'Outputs','3');
wire(path,'读取包',1,'窗口历史',1);wire(path,'窗口历史',1,'历史拆分',1);
addPart(path,'simulink/Math Operations/Sum','计数差',[335 40 355 80],'Inputs','+-');wire(path,'输入1',1,'计数差',1);wire(path,'历史拆分',1,'计数差',2);
addPart(path,'simulink/User-Defined Functions/Fcn','单圈差分',[395 40 575 80],'Expr','u-counts*floor((u+counts/2)/counts)');wire(path,'计数差',1,'单圈差分',1);
addPart(path,'simulink/Math Operations/Gain','机械速度',[620 40 735 80],'Gain','60/(counts*window*dt)');wire(path,'单圈差分',1,'机械速度',1);
addPart(path,'simulink/Math Operations/Abs','差分幅度',[400 245 445 275]);wire(path,'单圈差分',1,'差分幅度',1);
addPart(path,'simulink/Sources/Constant','半圈',[395 315 475 340],'Value','counts/2');
addPart(path,'simulink/Logic and Bit Operations/Relational Operator','方向唯一',[515 245 560 290],'Operator','<');wire(path,'差分幅度',1,'方向唯一',1);wire(path,'半圈',1,'方向唯一',2);
addPart(path,'simulink/Sources/Constant','启用',[400 390 475 415],'Value','speed_on');
addPart(path,'simulink/Logic and Bit Operations/Logical Operator','有效窗口',[620 220 675 300],'Operator','AND','Inputs','4');
wire(path,'输入3',1,'有效窗口',1);wire(path,'历史拆分',3,'有效窗口',2);wire(path,'方向唯一',1,'有效窗口',3);wire(path,'启用',1,'有效窗口',4);
addPart(path,'simulink/Signal Attributes/Data Type Conversion','有效标志',[725 270 795 300],'OutDataTypeStr','double');wire(path,'有效窗口',1,'有效标志',1);
addPart(path,'simulink/Sources/Constant','无效初值',[750 185 805 210],'Value','0');
addPart(path,'simulink/Signal Routing/Switch','测速输出',[830 85 875 155],'Criteria','u2 >= Threshold','Threshold','0.5');
wire(path,'机械速度',1,'测速输出',1);wire(path,'有效窗口',1,'测速输出',2);wire(path,'无效初值',1,'测速输出',3);
addPart(path,'simulink/Math Operations/Sum','时间跨度',[335 135 355 175],'Inputs','+-');wire(path,'输入2',1,'时间跨度',1);wire(path,'历史拆分',2,'时间跨度',2);
addPart(path,'simulink/Signal Routing/Mux','观测',[945 55 950 385],'Inputs','7');
sources={'测速输出',1;'有效标志',1;'单圈差分',1;'时间跨度',1;'历史拆分',2;'输入2',1;'历史拆分',1};
for j=1:size(sources,1),wire(path,sources{j,1},sources{j,2},'观测',j);end
addPart(path,'built-in/Outport','记录',[1010 205 1040 225]);wire(path,'观测',1,'记录',1);
end
function addPart(parent,library,name,pos,varargin)
add_block(library,[parent '/' name],'Position',pos,varargin{:});
end
function wire(parent,a,ap,b,bp)
add_line(parent,[a '/' num2str(ap)],[b '/' num2str(bp)],'autorouting','on');
end
