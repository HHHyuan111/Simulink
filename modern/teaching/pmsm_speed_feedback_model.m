function result=pmsm_speed_feedback_model(action,mdl)
% Reversible source selection BEFORE the original speed-task hold.
if nargin<1,action='install';end
if nargin<2,mdl='PMSM_FOC_R2026a';end
path=[mdl '/速度反馈'];base=[mdl '/角度设置/编码器/测速'];
if strcmp(action,'installed'),result=bdIsLoaded(mdl)&&getSimulinkBlockHandle(path)>0;return;end
assert(bdIsLoaded(mdl)&&strcmp(get_param(mdl,'SimulationStatus'),'stopped'));
if strcmp(action,'remove')
 if getSimulinkBlockHandle(path)<0,result=false;return;end
 if exist('pmsm_speed_filter_model','file')==2&&pmsm_speed_filter_model('installed',mdl),pmsm_speed_filter_model('remove',mdl);end
 b=get_param(path,'UserData');ph=get_param(path,'PortHandles');
 for port=[ph.Inport ph.Outport],line=get_param(port,'Line');if line>=0,delete_line(line);end,end
 delete_block(path);
 for name=b.taps
  if getSimulinkBlockHandle(name{1})>0
   ph=get_param(name{1},'PortHandles');line=get_param(ph.Inport,'Line');
   if line>=0,src=get_param(line,'SrcPortHandle');delete_line(base,src,ph.Inport);end
   delete_block(name{1});
  end
 end
 add_line(mdl,b.source,b.destination,'autorouting','on');set_param(get_param(b.destination,'Line'),'Name',b.line_name);
 set_param(mdl,'Dirty',b.dirty);result=true;return;
end
assert(strcmp(action,'install')&&pmsm_encoder_speed_model('installed',mdl)&&getSimulinkBlockHandle(path)<0);
target=get_param(Simulink.ID.getHandle([mdl ':190']),'PortHandles');line=get_param(target.Inport,'Line');
b=struct('source',get_param(line,'SrcPortHandle'),'destination',target.Inport,'line_name',get_param(line,'Name'),'dirty',get_param(mdl,'Dirty'),'taps',{{}});
assert(isscalar(get_param(line,'DstPortHandle')),'速度输入必须为单一原连接。');
add_block('built-in/SubSystem',path,'Position',[280 410 390 455],'BackgroundColor','[0.81 0.91 0.86]');set_param(path,'UserData',b);
try
 mask=Simulink.Mask.create(path);mask.Type='速度反馈选择';mask.Display="disp('速度反馈')";
 mask.Description='原速度或计数测速；选择放在原速度任务保持之前。计数无效时为零，不回填真值。无速度滤波。';
 mask.addParameter('Name','feedback_on','Type','checkbox','Prompt','计数测速反馈','Value','off','Tunable','off');
 mask.addParameter('Name','window_choice','Type','edit','Prompt','窗口选择 [1短/2窗口/3长窗]','Value','2','Tunable','off');
 mask.Initialization="validateattributes(window_choice,{'double'},{'scalar','integer','>=',1,'<=',3});";
 names={'单拍','窗口','长窗'};
 for k=1:3
  name=[base '/反馈候选' num2str(k)];b.taps{end+1}=name;set_param(path,'UserData',b);
  add_block('simulink/Signal Routing/Goto',name,'GotoTag',['speed_candidate_' num2str(k)],'TagVisibility','global','Position',[555 65+165*(k-1) 680 95+165*(k-1)]);
  add_line(base,[names{k} '/1'],['反馈候选' num2str(k) '/1'],'autorouting','on');
  part(path,'simulink/Signal Routing/From',['候选' num2str(k)],[25 100+65*k 140 120+65*k],'GotoTag',['speed_candidate_' num2str(k)]);
 end
 part(path,'built-in/Inport','原速度',[25 45 55 65]);
 part(path,'simulink/Sources/Constant','窗口选择',[25 110 140 135],'Value','window_choice');
 part(path,'simulink/Signal Routing/Multiport Switch','候选选择',[190 135 240 325],'Inputs','3','DataPortOrder','One-based contiguous');
 wire(path,'窗口选择',1,'候选选择',1);for k=1:3,wire(path,['候选' num2str(k)],1,'候选选择',k+1);end
 part(path,'simulink/Signal Routing/Demux','测速包',[280 150 285 370],'Outputs','7');wire(path,'候选选择',1,'测速包',1);
 for k=[3 4 7],part(path,'simulink/Sinks/Terminator',['备用' num2str(k)],[320 390+25*k 340 410+25*k]);wire(path,'测速包',k,['备用' num2str(k)],1);end
 part(path,'simulink/Sources/Constant','零初值',[320 310 375 335],'Value','0');
 part(path,'simulink/Signal Routing/Switch','有效测速',[420 165 465 245],'Threshold','0.5','Criteria','u2 >= Threshold');
 wire(path,'测速包',1,'有效测速',1);wire(path,'测速包',2,'有效测速',2);wire(path,'零初值',1,'有效测速',3);
 part(path,'simulink/Sources/Constant','反馈开关',[420 100 490 125],'Value','feedback_on');
 part(path,'simulink/Signal Routing/Switch','反馈选择',[550 40 595 120],'Threshold','0.5','Criteria','u2 >= Threshold');
 wire(path,'有效测速',1,'反馈选择',1);wire(path,'反馈开关',1,'反馈选择',2);wire(path,'原速度',1,'反馈选择',3);
 part(path,'built-in/Outport','反馈',[665 65 695 85]);wire(path,'反馈选择',1,'反馈',1);
 part(path,'simulink/Signal Routing/Mux','观测',[735 150 740 410],'Inputs','8');
 sources={'测速包',1;'测速包',2;'反馈开关',1;'窗口选择',1;'原速度',1;'反馈选择',1;'测速包',6;'测速包',5};
 for k=1:8,wire(path,sources{k,1},sources{k,2},'观测',k);end
 part(path,'simulink/Sinks/To Workspace','记录',[800 260 960 290],'VariableName','log_speed_feedback','SaveFormat','Timeseries','SampleTime','timing_speed_sample','MaxDataPoints','inf');wire(path,'观测',1,'记录',1);
 delete_line(line);ph=get_param(path,'PortHandles');add_line(mdl,b.source,ph.Inport,'autorouting','on');add_line(mdl,ph.Outport,b.destination,'autorouting','on');
 result=path;
catch err
 % Installation may fail before the original line was replaced.
 attached=get_param(b.destination,'Line');if attached>=0&&get_param(attached,'SrcPortHandle')==b.source,delete_line(attached);end
 pmsm_speed_feedback_model('remove',mdl);rethrow(err);
end
end
function part(p,lib,name,pos,varargin)
add_block(lib,[p '/' name],'Position',pos,varargin{:});
end
function wire(p,a,ap,b,bp)
add_line(p,[a '/' num2str(ap)],[b '/' num2str(bp)],'autorouting','on');
end
