function result=pmsm_speed_filter_model(action,mdl)
% One-pole firmware-form filter before the existing speed-task hold.
if nargin<1,action='install';end
if nargin<2,mdl='PMSM_FOC_R2026a';end
parent=[mdl '/速度反馈'];path=[parent '/速度滤波'];
if strcmp(action,'installed'),result=bdIsLoaded(mdl)&&getSimulinkBlockHandle(path)>0;return;end
assert(bdIsLoaded(mdl)&&strcmp(get_param(mdl,'SimulationStatus'),'stopped'));
if strcmp(action,'remove')
 if getSimulinkBlockHandle(path)<0,result=false;return;end
 b=get_param(path,'UserData');ph=get_param(path,'PortHandles');
 for port=ph.Inport,line=get_param(port,'Line');if line>=0,src=get_param(line,'SrcPortHandle');delete_line(parent,src,port);end,end
 line=get_param(ph.Outport,'Line');if line>=0,delete_line(line);end
 delete_block(path);add_line(parent,b.source,b.destination,'autorouting','on');set_param(mdl,'Dirty',b.dirty);result=true;return;
end
assert(strcmp(action,'install')&&pmsm_speed_feedback_model('installed',mdl)&&getSimulinkBlockHandle(path)<0);
dest=get_param([parent '/反馈选择'],'PortHandles');line=get_param(dest.Inport(1),'Line');
b=struct('source',get_param(line,'SrcPortHandle'),'destination',dest.Inport(1),'dirty',get_param(mdl,'Dirty'));
add_block('built-in/SubSystem',path,'Position',[470 270 585 315],'BackgroundColor','[0.81 0.91 0.86]');set_param(path,'UserData',b);
try
 mask=Simulink.Mask.create(path);mask.Type='速度低通';mask.Display="disp('速度滤波')";
 mask.Description='a=1/(1+2πfcTs)，y=b*x+a*y_prev，零初态。20kHz更新；关闭直通。无效输入零，内部状态按零输入递推，发布值零。';
 mask.addParameter('Name','filter_on','Type','checkbox','Prompt','速度滤波','Value','off','Tunable','off');
 mask.addParameter('Name','cutoff_hz','Type','edit','Prompt','截止频率 [Hz]','Value','200','Tunable','off');
 mask.Initialization="validateattributes(cutoff_hz,{'double'},{'scalar','real','finite','>=',20,'<=',5000});";
 part(path,'built-in/Inport','测速',[25 55 55 75],'Port','1');part(path,'built-in/Inport','有效',[25 270 55 290],'Port','2');
 part(path,'simulink/Math Operations/Gain','输入项',[110 45 215 85],'Gain','1-1/(1+2*pi*cutoff_hz*dt)');
 part(path,'simulink/Math Operations/Sum','递推',[270 50 295 80],'Inputs','++');wire(path,'测速',1,'输入项',1);wire(path,'输入项',1,'递推',1);
 part(path,'simulink/Discrete/Unit Delay','历史',[350 155 425 190],'InitialCondition','0','SampleTime','timing_control_sample');
 part(path,'simulink/Math Operations/Gain','历史项',[135 150 235 190],'Gain','1/(1+2*pi*cutoff_hz*dt)');
 wire(path,'递推',1,'历史',1);wire(path,'历史',1,'历史项',1);wire(path,'历史项',1,'递推',2);
 part(path,'simulink/Sources/Constant','零值',[310 300 365 325],'Value','0');
 part(path,'simulink/Signal Routing/Switch','有效输出',[455 160 500 235],'Threshold','0.5','Criteria','u2 >= Threshold');
 wire(path,'递推',1,'有效输出',1);wire(path,'有效',1,'有效输出',2);wire(path,'零值',1,'有效输出',3);
 part(path,'simulink/Sources/Constant','滤波开关',[450 90 520 115],'Value','filter_on');
 part(path,'simulink/Signal Routing/Switch','滤波选择',[560 40 605 120],'Threshold','0.5','Criteria','u2 >= Threshold');
 wire(path,'有效输出',1,'滤波选择',1);wire(path,'滤波开关',1,'滤波选择',2);wire(path,'测速',1,'滤波选择',3);
 part(path,'built-in/Outport','输出',[665 65 695 85]);wire(path,'滤波选择',1,'输出',1);
 part(path,'simulink/Sources/Constant','系数a',[465 345 535 370],'Value','1/(1+2*pi*cutoff_hz*dt)');
 part(path,'simulink/Sources/Constant','系数b',[465 400 535 425],'Value','1-1/(1+2*pi*cutoff_hz*dt)');
 part(path,'simulink/Signal Routing/Mux','观测',[730 160 735 435],'Inputs','7');
 sources={'测速',1;'递推',1;'滤波选择',1;'有效',1;'滤波开关',1;'系数a',1;'系数b',1};
 for k=1:7,wire(path,sources{k,1},sources{k,2},'观测',k);end
 part(path,'simulink/Sinks/To Workspace','记录',[795 275 955 305],'VariableName','log_speed_filter','SaveFormat','Timeseries','SampleTime','timing_control_sample','MaxDataPoints','inf');wire(path,'观测',1,'记录',1);
 delete_line(parent,b.source,b.destination);ph=get_param(path,'PortHandles');add_line(parent,b.source,ph.Inport(1),'autorouting','on');
 valid=get_param([parent '/测速包'],'PortHandles');add_line(parent,valid.Outport(2),ph.Inport(2),'autorouting','on');add_line(parent,ph.Outport,b.destination,'autorouting','on');result=path;
catch err
 attached=get_param(b.destination,'Line');if attached>=0&&get_param(attached,'SrcPortHandle')==b.source,delete_line(parent,b.source,b.destination);end
 pmsm_speed_filter_model('remove',mdl);rethrow(err);
end
end
function part(p,lib,name,pos,varargin)
add_block(lib,[p '/' name],'Position',pos,varargin{:});
end
function wire(p,a,ap,b,bp)
add_line(p,[a '/' num2str(ap)],[b '/' num2str(bp)],'autorouting','on');
end
