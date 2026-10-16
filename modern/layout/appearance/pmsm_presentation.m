function result=pmsm_presentation(action,mdl)
% Reversible presentation of the SAME model; the archived compute SLX stays fixed.
% Use remove before fixed-reference tools; apply again afterwards.
persistent state
if nargin<1,action='apply';end
if nargin<2,mdl='PMSM_FOC_R2026a';end
result=[];
if strcmp(action,'forget'),state=[];return;end % Model CloseFcn, not an editing action.
if strcmp(action,'installed'),result=~isempty(state)&&bdIsLoaded(mdl);return;end
if ~bdIsLoaded(mdl),state=[];if strcmp(action,'remove'),return;end;load_system(mdl);end
if strcmp(action,'remove')
 if isempty(state),return;end
 assert(strcmp(get_param(mdl,'SimulationStatus'),'stopped'),'先停止仿真。');
 userDirty=get_param(mdl,'Dirty');view=gcs;
 for k=numel(state.edges):-1:1
  e=state.edges(k);if ishandle(e.from),delete_block(e.from);end
  if ishandle(e.goto),delete_block(e.goto);end
  ln=get_param(e.dst,'Line');if ln>=0,delete_line(ln);end
  add_line(e.parent,e.src,e.dst,'autorouting','on');
 end
 for k=numel(state.props):-1:1
  p=state.props(k);if ishandle(p.handle),set_param(p.handle,p.key,p.value);end
 end
 for h=state.annotations,if ishandle(h),delete(get_param(h,'Object'));end,end
 for sys=state.systems,route(sys{1});end
 restoreView(view,mdl);
 if strcmp(userDirty,'off'),set_param(mdl,'Dirty',state.dirty);end
 state=[];return;
end
assert(strcmp(action,'apply'),'未知布局操作。');
if ~isempty(state),return;end
assert(strcmp(get_param(mdl,'SimulationStatus'),'stopped'),'先停止仿真。');
state=struct('dirty',get_param(mdl,'Dirty'),'props',struct('handle',{},'key',{},'value',{}), ...
 'edges',struct('parent',{},'src',{},'dst',{},'goto',{},'from',{}),'annotations',[],'systems',{{mdl}});
try
 view=gcs;
 change(get_param(mdl,'Handle'),'PreSaveFcn',"error('pmsm:PresentationSave','布局配置已自动保存在脚本中。修改计算模型前，请先执行 pmsm_presentation(''remove'')，再保存新的基线版本。');");
 oldClose=get_param(mdl,'CloseFcn');change(get_param(mdl,'Handle'),'CloseFcn',[oldClose newline 'pmsm_presentation(''forget'');']);
 positions=jsondecode(fileread(fullfile(fileparts(mfilename('fullpath')),'positions.json')));
 for k=1:numel(positions)
  h=Simulink.ID.getHandle([mdl ':' num2str(positions(k).sid)]);change(h,'Position',positions(k).position');
 end
 % Keep the user's open tabs; reading block handles also works in hidden diagrams.
 drawnow;
 palette=[.35 .74 .53;.56 .51 .86;.91 .71 .30;.92 .52 .36;.32 .63 .89;.24 .70 .72;.44 .65 .85;.62 .55 .81;.74 .64 .39];
 blocks=find_system(mdl,'LookUnderMasks','all','FollowLinks','off','Type','Block');
 for k=1:numel(blocks)
  h=get_param(blocks{k},'Handle');typ=get_param(h,'BlockType');p=get_param(h,'Position');
  if strcmp(typ,'SubSystem')
   try,change(h,'ContentPreviewEnabled','off');catch,end
   color=[.68 .82 .94];
   if strcmp(get_param(h,'Parent'),mdl)
    row=min(2,max(0,floor((mean(p([2 4]))-100)/620)));col=min(2,max(0,floor((mean(p([1 3]))-50)/900)));color=palette(row*3+col+1,:)*.65+.35;
   end
   change(h,'BackgroundColor',mat2str(color));
  elseif strcmp(typ,'Scope')||strcmp(typ,'Record')
   change(h,'BackgroundColor','white');
  end
 end
 % Stronger region fills, keeping the existing nine equal areas.
 anns=find_system(mdl,'FindAll','on','SearchDepth',1,'Type','annotation');
 for h=anns(:)'
  a=get_param(h,'Object');if strcmp(a.Tag,'FlatTidyRegion')
   p=a.Position;row=min(2,max(0,round((p(2)-100)/620)));col=min(2,max(0,round((p(1)-50)/900)));
   change(h,'BackgroundColor',mat2str(palette(row*3+col+1,:)*.28+.72));
  end
 end
 % 05 and 06 communicate by named buses; no long inter-area wires.
 connectTag(649,1,'MotorBus',[1710 840 1800 864],[1880 908 1980 932]);
 connectTag(660,1,'MotorBus',[1710 840 1800 864],[1880 1128 1980 1152]);
 connectTag(671,2,'PhaseCurrent',[1710 1100 1800 1124],[1200 1100 1310 1124]);
 connectTag(141,2,'iq');connectTag(214,1,'id');
 connectTag(213,1,'OmegaTask',[1190 330 1300 354]);connectTag(141,3,'OmegaTask');
 connectTag(990,2,'LdId',[1555 570 1665 594],[1240 410 1360 434]);
 connectTag(1042,1,'Modulation');
 % Sampling chain is now read in three rows; telemetry has its own bottom row.
 sys=[mdl '/采样设置'];state.systems{end+1}=sys;
 headings={'模拟前端',30,10;'ADC与滤波',30,405;'延迟与输出',30,690;'时序采样',30,995;'数据记录',30,1435};
 for k=1:size(headings,1)
  a=Simulink.Annotation(sys,headings{k,1});a.FontName='Microsoft YaHei';a.FontSize=15;a.FontWeight='bold';a.ForegroundColor='[0.16 0.35 0.50]';a.Position=[headings{k,2} headings{k,3}];a.Tag='PMSMPresentation';state.annotations(end+1)=a.Handle;
 end
 edges={1086,1,'AnalogOut';1087,2,'AnalogOut';1087,1,'SampledABC';782,1,'FilteredABC';784,3,'FilteredABC';786,3,'CurrentTruth'; ...
  788,1,'CurrentTruth';790,1,'CurrentNoise';791,1,'CurrentADC';792,1,'CurrentFiltered';789,1,'CurrentMeasured'; ...
  1089,1,'ADCTiming';1090,1,'ADCCodes'};
 for k=1:size(edges,1),connectTag(edges{k,1},edges{k,2},edges{k,3});end
 % Give every input of the PI overview a short, separate connection.
 tags={'SpeedPI','dPI','qPI','FF','Vdq','Vmax','Util','Saturated','Residual','Correction'};
 for k=1:numel(tags),connectTag(982,k,tags{k});end
 % Other subsystem telemetry branches and long backtracking wires use local tags.
 for parentName={'角度设置','输出延迟','功率设置','限压','跟踪观测','PI观测','时序观测','测量观测','功率观测'}
  parent=[mdl '/' parentName{1}];if getSimulinkBlockHandle(parent)<=0,continue;end
  state.systems{end+1}=parent;
  children=find_system(parent,'SearchDepth',1,'LookUnderMasks','all','FollowLinks','off','Type','Block');
  for b=children(:)'
   if strcmp(b{1},parent),continue;end
   ph=get_param(b{1},'PortHandles');
   for j=1:numel(ph.Inport)
    ln=get_param(ph.Inport(j),'Line');if ln<0,continue;end
    src=get_param(ln,'SrcPortHandle');if src<0,continue;end
    sp=get_param(src,'Position');dp=get_param(ph.Inport(j),'Position');
    if strcmp(get_param(b{1},'BlockType'),'ToWorkspace')&&strcmp(get_param(get_param(src,'Parent'),'BlockType'),'From')&&abs(sp(1)-dp(1))<250,continue;end
    if strcmp(get_param(b{1},'BlockType'),'ToWorkspace')||abs(sp(1)-dp(1))>650
     sid=Simulink.ID.getSID(b{1});n=str2double(extractAfter(sid,':'));tag=['Trace' num2str(n) '_' num2str(j)];
     if strcmp(get_param(b{1},'BlockType'),'ToWorkspace'),tag=erase(get_param(b{1},'VariableName'),{'out.','log_','obs_'});end
     connectTag(n,j,tag);
    end
   end
  end
 end
 for sys=state.systems,route(sys{1});end
 restoreView(view,mdl);
 for section={'采样设置','角度设置','功率设置','时序设置'}
  path=[mdl '/' section{1}];change(get_param(path,'Handle'),'OpenFcn',['open_pmsm_controls(''' section{1} ''');']);
 end
 set_param(mdl,'Dirty',state.dirty);result=struct('tag_pairs',numel(state.edges),'styled_properties',numel(state.props));
catch err
 pmsm_presentation('remove',mdl);rethrow(err);
end
 function change(h,key,value)
  old=get_param(h,key);if isequal(old,value),return;end
  state.props(end+1)=struct('handle',h,'key',key,'value',old);set_param(h,key,value);
 end
 function connectTag(sid,port,tag,gpos,fpos)
  dstBlock=Simulink.ID.getHandle([mdl ':' num2str(sid)]);ph=get_param(dstBlock,'PortHandles');dst=ph.Inport(port);ln=get_param(dst,'Line');
  if ln<0,return;end
  src=get_param(ln,'SrcPortHandle');parent=get_param(dstBlock,'Parent');sp=get_param(src,'Position');dp=get_param(dst,'Position');
  if nargin<4,gpos=[sp(1)+25 sp(2)-10 sp(1)+130 sp(2)+10];end
  if nargin<4&&strcmp(get_param(get_param(src,'Parent'),'BlockType'),'From'),gpos=[sp(1)+25 sp(2)-75 sp(1)+145 sp(2)-51];end
  if nargin<4&&strcmp(tag,'CurrentMeasured'),gpos=[sp(1)+25 sp(2)+60 sp(1)+155 sp(2)+84];end
  if nargin<4&&strcmp(tag,'ADCTiming'),gpos=[sp(1)+25 sp(2)-75 sp(1)+155 sp(2)-51];end
  if nargin<5,fpos=[dp(1)-145 dp(2)-10 dp(1)-25 dp(2)+10];end
  i=numel(state.edges)+1;name=['_View_' num2str(i)];
  existing=find([state.edges.src]==src,1);
  sourceIsFrom=strcmp(get_param(get_param(src,'Parent'),'BlockType'),'From');
  sourceLine=get_param(src,'Line');consumers=get_param(sourceLine,'DstPortHandle');
  if sourceIsFrom&&numel(consumers(consumers>=0))==1
   change(get_param(get_param(src,'Parent'),'Handle'),'Position',fpos);return;
  end
  originalGoto=[];
  for consumer=consumers(:)'
   if consumer<0,continue;end;owner=get_param(consumer,'Parent');
   if get_param(owner,'Handle')~=dstBlock&&strcmp(get_param(owner,'BlockType'),'Goto')&&~strcmp(get_param(owner,'Tag'),'PMSMPresentation'),originalGoto=get_param(owner,'Handle');break;end
  end
  if sourceIsFrom
   gh=-1;tag=get_param(get_param(src,'Parent'),'GotoTag');
  elseif ~isempty(originalGoto)
   gh=-1;tag=get_param(originalGoto,'GotoTag');
  elseif isempty(existing)
   gh=add_block('simulink/Signal Routing/Goto',[parent '/' name '_G'],'GotoTag',tag,'TagVisibility','local','Position',gpos,'ShowName','off','BackgroundColor','white','Tag','PMSMPresentation');
  else
   gh=state.edges(existing).goto;tag=get_param(gh,'GotoTag');
  end
  fh=add_block('simulink/Signal Routing/From',[parent '/' name '_F'],'GotoTag',tag,'Position',fpos,'ShowName','off','BackgroundColor','white','Tag','PMSMPresentation');
  state.edges(end+1)=struct('parent',parent,'src',src,'dst',dst,'goto',gh,'from',fh);
  delete_line(parent,src,dst);if isempty(existing)&&gh>0,add_line(parent,src,get_param(gh,'PortHandles').Inport,'autorouting','on');end
  add_line(parent,get_param(fh,'PortHandles').Outport,dst,'autorouting','on');
 end
end
function route(sys)
% Recreate signal geometry after moving blocks. Routing old branch vertices
% independently can leave diagonal segments and dangling visual stubs.
drawnow;
children=find_system(sys,'SearchDepth',1,'LookUnderMasks','all','FollowLinks','off','Type','Block');lines=[];
for b=children(:)'
 if strcmp(b{1},sys),continue;end
 ph=get_param(b{1},'PortHandles');for p=ph.Outport(:)',ln=get_param(p,'Line');if ln>=0,lines(end+1)=ln;end,end
end
lines=unique(lines);saved=struct('src',{},'dst',{},'values',{});roots=[];
keys={'Name','DataLogging','DataLoggingNameMode','DataLoggingName','TestPoint'};
for h=lines(:)'
 src=get_param(h,'SrcPortHandle');if src<0,continue;end
 dst=get_param(h,'DstPortHandle');dst=dst(dst>=0);if isempty(dst),continue;end
 values=struct;for key=keys,try,values.(key{1})=get_param(h,key{1});catch,end,end
 saved(end+1)=struct('src',src,'dst',dst,'values',values);roots(end+1)=h;
end
% Removing a branch can retain orphan visual segments. Clear those as well.
allLines=find_system(sys,'FindAll','on','SearchDepth',1,'LookUnderMasks','all','FollowLinks','off','Type','line');
for h=allLines(:)',try,delete_line(h);catch,end,end
for k=1:numel(saved)
 e=saved(k);h=add_line(sys,e.src,e.dst(1),'autorouting','on');
 for j=2:numel(e.dst),add_line(sys,e.src,e.dst(j),'autorouting','on');end
 for key=fieldnames(e.values)',try,set_param(h,key{1},e.values.(key{1}));catch,end,end
end
end
function restoreView(view,mdl)
if isempty(view)||(~strcmp(view,mdl)&&getSimulinkBlockHandle(view)<=0),view=mdl;end
if strcmp(view,mdl),open_system(view);else,open_system(view,'force');end
end
