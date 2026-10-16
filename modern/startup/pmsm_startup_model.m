function result=pmsm_startup_model(action,mdl)
% Reversible local additions. Original algorithms, masks and SIDs are retained.
if nargin<1,action='install';end
if nargin<2,mdl='PMSM_FOC_R2026a';end
path=[mdl '/启停'];here=fileparts(mfilename('fullpath'));
if strcmp(action,'installed'),result=bdIsLoaded(mdl)&&getSimulinkBlockHandle(path)>0;return;end
assert(bdIsLoaded(mdl)&&strcmp(get_param(mdl,'SimulationStatus'),'stopped'));
if strcmp(action,'remove')
 if getSimulinkBlockHandle(path)<0,result=false;return;end
 b=get_param(path,'UserData');
 % Restore destinations before deleting added branch sources.
 for j=numel(b.rewires):-1:1
  r=b.rewires(j);line=get_param(r.destination,'Line');
  if line>=0,src=get_param(line,'SrcPortHandle');delete_line(r.parent,src,r.destination);end
  add_line(r.parent,r.source,r.destination,'autorouting','on');
 end
 for j=numel(b.blocks):-1:1
  if getSimulinkBlockHandle(b.blocks{j})>0,delete_block(b.blocks{j});end
 end
 for j=1:numel(b.integrators),set_param(b.integrators(j).path,'ExternalReset',b.integrators(j).reset,'Position',b.integrators(j).position);end
 set_param(mdl,'InitFcn',b.init_fcn);delete_block(path);set_param(mdl,'Dirty',b.dirty);result=true;return;
end
assert(strcmp(action,'install')&&getSimulinkBlockHandle(path)<0&&pmsm_speed_filter_model('installed',mdl));
assert(strcmp(get_param([mdl '/时序设置'],'real_on'),'on'),'启停实验需要真实时序。');
assert(strcmp(get_param([mdl '/角度设置/编码器'],'encoder_on'),'on')&&strcmp(get_param([mdl '/速度反馈'],'feedback_on'),'on'),...
 '首批启停要求计数角度和计数测速反馈，避免使用未选中的准备标志。');
b=struct('dirty',get_param(mdl,'Dirty'),'init_fcn',get_param(mdl,'InitFcn'),'blocks',{{}},'rewires',struct('parent',{},'source',{},'destination',{},'newsource',{}),...
 'integrators',struct('path',{},'reset',{},'position',{}),'pwm_path',[mdl '/输出延迟/CCR预装载'],'pwm_script','');
rt=sfroot;c=rt.find('-isa','Stateflow.EMChart','Path',b.pwm_path);b.pwm_script=c.Script;
add_block('built-in/SubSystem',path,'Position',[300 920 450 980],'BackgroundColor','[0.79 0.87 0.95]');saveState;
try
 mask=Simulink.Mask.create(path);mask.Type='启停接管';mask.Display="disp('启停')";
 mask.addParameter('Name','enabled','Type','checkbox','Prompt','启停框架','Value','on','Tunable','off');
 for row={'start_ms','启动 [ms]','0';'stop_ms','停止 [ms]','70';'restart_ms','重启 [ms]','85'}'
  mask.addParameter('Name',row{1},'Type','edit','Prompt',row{2},'Value',row{3},'Tunable','off');
 end
 mask.Initialization="assert(all(isfinite([start_ms stop_ms restart_ms]))&&start_ms>=0&&start_ms<stop_ms&&stop_ms<restart_ms,'启停时间须有限、非负且依次递增。');";
 part(path,'simulink/Sources/Digital Clock','时钟',[25 40 95 65],'SampleTime','timing_control_sample');
 part(path,'simulink/Sources/Constant','参数',[25 270 140 300],...
  'Value','[enabled start_ms*1e-3 stop_ms*1e-3 restart_ms*1e-3 timing_adc_cfg(2) -1 -1]');
 tap('log_speed_filter','StartupSpeed',1);tap('obs_adc_timing','StartupADC',2);
 part(path,'simulink/Signal Routing/From','测速准备',[25 110 135 135],'GotoTag','StartupSpeed');
 part(path,'simulink/Discrete/Unit Delay','准备快照',[140 110 195 140],'InitialCondition','zeros(1,7)','SampleTime','timing_control_sample');wire(path,'测速准备',1,'准备快照',1);
 part(path,'simulink/Signal Routing/From','采样状态',[25 180 135 205],'GotoTag','StartupADC');
 chart(path,'顺序',fileread(fullfile(here,'startup_step.m')),'timing_control_sample',[200 40 350 280]);
 for row={'时钟',1;'准备快照',2;'采样状态',3;'参数',4}'
  wire(path,row{1},1,'顺序',row{2});
 end
 part(path,'simulink/Signal Routing/Demux','状态包',[390 45 395 370],'Outputs','8');wire(path,'顺序',1,'状态包',1);
 part(path,'simulink/Sources/Constant','开关',[410 415 475 440],'Value','enabled');
 part(path,'simulink/Sources/Constant','允许',[410 470 475 495],'Value','1');
 for j=1:3
  name=['许可' num2str(j)];part(path,'simulink/Signal Routing/Switch',name,[520 60+95*j 560 120+95*j],'Threshold','0.5');
  wire(path,'状态包',j+1,name,1);wire(path,'开关',1,name,2);wire(path,'允许',1,name,3);
  if j<3
   part(path,'simulink/Signal Routing/Goto',['标签' num2str(j)],[600 80+95*j 725 105+95*j],...
    'GotoTag',['StartupPermit' num2str(j)],'TagVisibility','global');wire(path,name,1,['标签' num2str(j)],1);
  end
 end
 part(path,'simulink/Signal Routing/Mux','输出许可',[790 90 795 340],'Inputs','4');wire(path,'开关',1,'输出许可',1);
 for j=1:3,wire(path,['许可' num2str(j)],1,'输出许可',j+1);end
 part(path,'simulink/Discrete/Zero-Order Hold','事件许可',[815 350 900 385],'SampleTime','timing_h');wire(path,'输出许可',1,'事件许可',1);
 part(path,'simulink/Signal Routing/Goto','许可标签',[940 350 1070 380],'GotoTag','StartupControl','TagVisibility','global');wire(path,'事件许可',1,'许可标签',1);
 part(path,'simulink/Sinks/To Workspace','状态记录',[440 20 600 50],'VariableName','log_startup','SaveFormat','Timeseries','SampleTime','timing_control_sample','MaxDataPoints','inf');wire(path,'顺序',1,'状态记录',1);
 for j=[1 5 6 7 8],part(path,'simulink/Sinks/Terminator',['备用' num2str(j)],[430 530+25*j 450 550+25*j]);wire(path,'状态包',j,['备用' num2str(j)],1);end
 % Explicit reset of each original integrator; retain gains and back calculation.
 for id={'155','439','453'}
  pi=getfullname(Simulink.ID.getHandle([mdl ':' id{1}]));permission=1;if strcmp(id{1},'155'),permission=2;end
  from=[pi '/启停许可'];addTracked('simulink/Signal Routing/From',from,[20 370 145 395],'GotoTag',['StartupPermit' num2str(permission)]);
  zero=[pi '/启停零值'];addTracked('simulink/Sources/Constant',zero,[20 430 90 455],'Value','0');
  inp=find_system(pi,'LookUnderMasks','all','SearchDepth',1,'BlockType','Inport');assert(isscalar(inp));ip=get_param(inp{1},'PortHandles');line=get_param(ip.Outport,'Line');dest=get_param(line,'DstPortHandle');
  sw=[pi '/误差许可'];addTracked('simulink/Signal Routing/Switch',sw,[60 500 110 580],'Threshold','0.5');sp=get_param(sw,'PortHandles');
  add_line(pi,ip.Outport,sp.Inport(1),'autorouting','on');fp=get_param(from,'PortHandles');zp=get_param(zero,'PortHandles');
  add_line(pi,fp.Outport,sp.Inport(2),'autorouting','on');add_line(pi,zp.Outport,sp.Inport(3),'autorouting','on');
  for d=dest(:)',rewire(pi,ip.Outport,d,sp.Outport);end
  inv=[pi '/保持复位'];addTracked('simulink/Logic and Bit Operations/Logical Operator',inv,[170 370 215 400],'Operator','NOT');np=get_param(inv,'PortHandles');add_line(pi,fp.Outport,np.Inport,'autorouting','on');
  term=[pi '/复位观测'];addTracked('simulink/Sinks/Terminator',term,[265 385 285 405]);tp=get_param(term,'PortHandles');add_line(pi,np.Outport,tp.Inport,'autorouting','on');
  ints=find_system(pi,'LookUnderMasks','all','SearchDepth',1,'BlockType','DiscreteIntegrator');assert(isscalar(ints));
  b.integrators(end+1)=struct('path',ints{1},'reset',get_param(ints{1},'ExternalReset'),'position',get_param(ints{1},'Position'));saveState;
  set_param(ints{1},'ExternalReset','level');hp=get_param(ints{1},'PortHandles');add_line(pi,np.Outport,hp.Inport(2),'autorouting','on');
 end
 % Current command is withdrawn at the fast boundary, even between speed tasks.
 dest=get_param(Simulink.ID.getHandle([mdl ':222']),'PortHandles');line=get_param(dest.Inport,'Line');src=get_param(line,'SrcPortHandle');
 permit=[mdl '/iq给定许可'];addTracked('simulink/Signal Routing/From',permit,[490 1100 620 1130],'GotoTag','StartupPermit2');
 zero=[mdl '/iq零给定'];addTracked('simulink/Sources/Constant',zero,[490 1160 550 1190],'Value','0');
 choice=[mdl '/iq许可'];addTracked('simulink/Signal Routing/Switch',choice,[690 1100 740 1180],'Threshold','0.5');
 cp=get_param(choice,'PortHandles');fp=get_param(permit,'PortHandles');zp=get_param(zero,'PortHandles');
 add_line(mdl,src,cp.Inport(1),'autorouting','on');add_line(mdl,fp.Outport,cp.Inport(2),'autorouting','on');add_line(mdl,zp.Outport,cp.Inport(3),'autorouting','on');rewire(mdl,src,dest.Inport,cp.Outport);
 % Preserve the archived chart and its generated SIDs; add a local controlled queue.
 parent=[mdl '/输出延迟'];newpwm=[parent '/启停队列'];
 addTracked('simulink/User-Defined Functions/MATLAB Function',newpwm,[300 500 460 625]);
 c=rt.find('-isa','Stateflow.EMChart','Path',newpwm);c.Script=fileread(fullfile(here,'startup_pwm.m'));c.ChartUpdate='DISCRETE';c.SampleTime='timing_h';c.VectorOutputs1D=false;
 original=get_param(b.pwm_path,'PortHandles');replacement=get_param(newpwm,'PortHandles');
 for j=1:3,src=get_param(get_param(original.Inport(j),'Line'),'SrcPortHandle');add_line(parent,src,replacement.Inport(j),'autorouting','on');end
 for j=1:2
  destinations=get_param(get_param(original.Outport(j),'Line'),'DstPortHandle');
  for d=destinations(:)',rewire(parent,original.Outport(j),d,replacement.Outport(j));end
  term=[parent '/原队列保留' num2str(j)];addTracked('simulink/Sinks/Terminator',term,[510 660+30*j 530 680+30*j]);tp=get_param(term,'PortHandles');add_line(parent,original.Outport(j),tp.Inport,'autorouting','on');
 end
 parent=[mdl '/输出延迟'];from=[parent '/启停许可'];addTracked('simulink/Signal Routing/From',from,[30 560 160 590],'GotoTag','StartupControl');
 fp=get_param(from,'PortHandles');cp=get_param(newpwm,'PortHandles');assert(numel(cp.Inport)==4);add_line(parent,fp.Outport,cp.Inport(4),'autorouting','on');
 % Interlock before gate-deadtime logic, so all pending rises are cancelled.
 bridge=[mdl '/Universal Bridge'];ph=get_param(bridge,'PortHandles');line=get_param(ph.Inport(1),'Line');src=get_param(line,'SrcPortHandle');
 control=[mdl '/启停门极许可'];addTracked('simulink/Signal Routing/From',control,[500 1010 640 1040],'GotoTag','StartupControl');
 gate=[mdl '/启停门极'];addTracked('built-in/SubSystem',gate,[700 930 850 1000]);
 part(gate,'built-in/Inport','请求',[20 30 50 50],'Port','1');part(gate,'built-in/Inport','许可',[20 200 50 220],'Port','2');
 part(gate,'simulink/Signal Routing/Demux','许可包',[100 160 105 290],'Outputs','4');wire(gate,'许可',1,'许可包',1);
 part(gate,'simulink/Sources/Constant','三低侧',[80 90 175 115],'Value','[0 1 0 1 0 1]');
 part(gate,'simulink/Sources/Constant','六路关闭',[220 280 315 305],'Value','zeros(1,6)');
 for j=1:3,part(gate,'simulink/Signal Routing/Switch',['选择' num2str(j)],[210+130*(j-1) 50 250+130*(j-1) 130],'Threshold','0.5');end
 wire(gate,'请求',1,'选择1',1);wire(gate,'许可包',2,'选择1',2);wire(gate,'三低侧',1,'选择1',3);
 wire(gate,'选择1',1,'选择2',1);wire(gate,'许可包',4,'选择2',2);wire(gate,'六路关闭',1,'选择2',3);
 wire(gate,'选择2',1,'选择3',1);wire(gate,'许可包',1,'选择3',2);wire(gate,'请求',1,'选择3',3);
 part(gate,'simulink/Sinks/Terminator','速度备用',[150 330 170 350]);wire(gate,'许可包',3,'速度备用',1);
 part(gate,'built-in/Outport','实际请求',[650 80 680 100]);wire(gate,'选择3',1,'实际请求',1);
 gp=get_param(gate,'PortHandles');fp=get_param(control,'PortHandles');add_line(mdl,src,gp.Inport(1),'autorouting','on');add_line(mdl,fp.Outport,gp.Inport(2),'autorouting','on');rewire(mdl,src,ph.Inport(1),gp.Outport);
 set_param(mdl,'InitFcn',sprintf('%s\npmsm_startup_mode(bdroot);',b.init_fcn));result=path;
catch err
 try,pmsm_startup_model('remove',mdl);catch rollback,err=addCause(err,rollback);end
 rethrow(err);
end
 function saveState,set_param(path,'UserData',b);end
 function addTracked(lib,name,pos,varargin)
  b.blocks{end+1}=name;saveState;add_block(lib,name,'Position',pos,varargin{:});
 end
 function rewire(parent,src,dst,newsrc)
  fresh=~any([b.rewires.newsource]==newsrc);
  b.rewires(end+1)=struct('parent',parent,'source',src,'destination',dst,'newsource',newsrc);saveState;
  delete_line(parent,src,dst);add_line(parent,newsrc,dst,'autorouting','on');
  if fresh
   name=[parent '/接口保留' num2str(numel(b.rewires))];
   addTracked('simulink/Sinks/Terminator',name,[1150 800+25*numel(b.rewires) 1170 820+25*numel(b.rewires)]);
   ph=get_param(name,'PortHandles');add_line(parent,newsrc,ph.Inport,'autorouting','on');
  end
 end
 function tap(variable,tag,index)
  logs=find_system(mdl,'LookUnderMasks','all','BlockType','ToWorkspace','VariableName',variable);assert(isscalar(logs));
  lp=get_param(logs{1},'PortHandles');src=get_param(get_param(lp.Inport,'Line'),'SrcPortHandle');parent=get_param(logs{1},'Parent');
  name=[parent '/启停观测' num2str(index)];addTracked('simulink/Signal Routing/Goto',name,[1050 650+40*index 1200 680+40*index],'GotoTag',tag,'TagVisibility','global');
  gp=get_param(name,'PortHandles');add_line(parent,src,gp.Inport,'autorouting','on');
 end
end
function part(p,lib,n,pos,varargin),add_block(lib,[p '/' n],'Position',pos,varargin{:});end
function wire(p,a,ap,b,bp),add_line(p,[a '/' num2str(ap)],[b '/' num2str(bp)],'autorouting','on');end
function chart(p,n,code,st,pos)
part(p,'simulink/User-Defined Functions/MATLAB Function',n,pos);rt=sfroot;c=rt.find('-isa','Stateflow.EMChart','Path',[p '/' n]);c.Script=code;c.ChartUpdate='DISCRETE';c.SampleTime=st;c.VectorOutputs1D=false;
end

