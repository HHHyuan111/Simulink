function result=pmsm_signal_chain_view(action,mdl)
% Local reversible layout/labels. No block names or numerical parameters change.
if nargin<1,action='apply';end;if nargin<2,mdl='PMSM_FOC_R2026a';end
key=['PMSMSignalChainView_' mdl];state=[];
if isappdata(groot,key)
 state=getappdata(groot,key);
 if ~bdIsLoaded(mdl)||~isequal(state.model_handle,get_param(mdl,'Handle')),rmappdata(groot,key);state=[];end
end
result=[];if strcmp(action,'installed'),result=~isempty(state);return;end
if strcmp(action,'refresh'),pmsm_signal_chain_view('remove',mdl);action='apply';state=[];end
if strcmp(action,'remove')
 if isempty(state),return;end
 assert(strcmp(get_param(mdl,'SimulationStatus'),'stopped'));dirty=get_param(mdl,'Dirty');
 for item=state.edges(end:-1:1)
  e=item{1};ln=get_param(e.dst,'Line');if ln>=0,delete_line(e.parent,get_param(ln,'SrcPortHandle'),e.dst);end
  add_line(e.parent,e.src,e.dst,'autorouting','on');
 end
 for h=state.created_blocks(end:-1:1),if ishandle(h),delete_block(h);end,end
 for row=state.props(end:-1:1),r=row{1};if ishandle(r.handle),set_param(r.handle,r.key,r.value);end,end
 for row=state.annotations(end:-1:1),r=row{1};if ishandle(r.handle),a=get_param(r.handle,'Object');a.Name=r.name;a.Position=r.position;end,end
 for h=state.created,if ishandle(h),delete(get_param(h,'Object'));end,end
 rmappdata(groot,key);route([mdl '/采样设置']);route([mdl '/输出延迟']);set_param(mdl,'Dirty',dirty);return;
end
assert(strcmp(action,'apply')&&bdIsLoaded(mdl)&&pmsm_presentation('installed'));
assert(strcmp(get_param(mdl,'SimulationStatus'),'stopped'));if ~isempty(state),return;end
dirty=get_param(mdl,'Dirty');state=struct('model_handle',get_param(mdl,'Handle'),'props',{{}},'annotations',{{}},'created',[],'created_blocks',[],'edges',{{}});
try
 p=[mdl '/采样设置'];
 rows={
 '真实电流',[40 100 150 124];'增益',[200 96 300 128];'偏置求和',[370 100 395 125];'零偏',[315 190 440 220];
 '模拟测量',[520 100 545 125];'噪声源',[310 275 425 315];'噪声开关',[490 280 600 310];
 '模拟低通',[700 78 845 140];'模拟选择',[970 92 1030 154];'模拟开关',[770 200 875 230];
 '标签_obs_analog_current',[1140 110 1300 134];
 '采样方式',[200 472 250 532];'捕获',[350 485 410 525];'量化',[510 450 580 490];
 '量程',[650 450 730 490];'ADC选择',[850 485 910 545];'ADC开关',[720 590 835 620];
 '数字低通',[1060 450 1190 490];'滤波选择',[1310 485 1370 545];'滤波开关',[1175 590 1290 620];
 '传递延迟',[220 790 340 830];'延迟选择',[500 825 560 885];'延迟开关',[350 930 465 960];
 '总选择',[800 825 860 885];'启用',[635 930 750 960];'测量电流',[1010 845 1160 869];
 '事件时钟',[40 1190 145 1220];'门极',[40 1090 145 1114];'门极历史',[215 1080 325 1120];
 '模拟缓存',[215 1280 325 1320];'时序参数',[40 1380 145 1410];
 '顺序采样',[510 1060 715 1370];'列向量',[845 1090 925 1130];
 '标签_ObsADCTiming',[845 1210 1020 1234];
 '记录_log_iabc_true',[235 1550 450 1580];'记录_log_iabc_noise',[235 1630 450 1660];
 '记录_log_iabc_adc',[690 1550 905 1580];'记录_log_iabc_filter',[690 1630 905 1660];
 '记录_log_iabc_meas',[1145 1550 1360 1580];'记录_obs_adc_timing',[1145 1630 1360 1660];
 '记录_obs_adc_codes',[1145 1710 1360 1740]};
 for k=1:size(rows,1),change(get_param([p '/' rows{k,1}],'Handle'),'Position',rows{k,2});end
 change(get_param([p '/记录_obs_adc_codes'],'Handle'),'AttributesFormatString','固定12 bit参考码');
 headings={'模拟前端','模拟前端',10;'ADC与滤波','采样与数字处理',400;...
  '延迟与输出','等效延迟与反馈',720;'时序采样','事件采样',990;'数据记录','数据记录',1480};
 anns=find_system(p,'FindAll','on','SearchDepth',1,'Type','annotation');
 for h=anns(:)'
  a=get_param(h,'Object');plain=regexprep(a.Name,'<[^>]*>','');plain=strtrim(plain);ix=find(strcmp(headings(:,1),plain));if isempty(ix),continue;end
  state.annotations{end+1}=struct('handle',h,'name',a.Name,'position',a.Position);
  a.Name=headings{ix,2};a.Position=[30 headings{ix,3}];
 end
 % Place existing named links by their consumers/sources, not remote branches.
 arrangeLinks(p);
 placeTag(p,'CurrentNoise',[650 280 820 304]);placeTag(p,'CurrentADC',[915 365 1075 389]);
 a=Simulink.Annotation(p,'观测接口');a.Position=[30 1780];a.FontSize=15;a.FontWeight='bold';a.Tag='PMSMSignalChainHeading';state.created(end+1)=a.Handle;
 q=[mdl '/输出延迟'];rows={
 '指令',[40 110 70 130];'周期延迟',[240 60 355 100];'选择',[500 100 560 160];...
 '启用',[365 210 475 240];'输出方式',[980 230 1030 290];'生效',[1220 250 1250 270];...
 '事件时钟',[40 390 145 420];'时序参数',[40 480 145 510];'指令缓存',[240 470 355 510];...
 'CCR预装载',[500 370 700 550];'阈值向量',[800 380 880 420];...
 '记录_log_Tcm_requested',[240 690 460 720];'记录_log_Tcm_applied',[700 690 920 720];...
 '记录_obs_pwm_timing',[1150 690 1370 720];'标签_ObsPWMTiming',[800 510 990 534]};
 for k=1:size(rows,1),change(get_param([q '/' rows{k,1}],'Handle'),'Position',rows{k,2});end
 for row={'等效周期延迟',30,10;'事件预装载',30,310;'数据记录',30,630;'观测接口',30,750}'
  a=Simulink.Annotation(q,row{1});a.Position=[row{2} row{3}];a.FontSize=15;a.FontWeight='bold';a.Tag='PMSMSignalChainHeading';state.created(end+1)=a.Handle;
 end
 arrangeLinks(q);placeTag(q,'Tcm_requested',[90 30 240 54]);placeTag(q,'Tcm_applied',[1080 180 1240 204]);
 route(p);route(q);setappdata(groot,key,state);set_param(mdl,'Dirty',dirty);
 result=struct('styled_properties',numel(state.props),'numerical_change',false);
catch err
 setappdata(groot,key,state);pmsm_signal_chain_view('remove',mdl);rethrow(err);
end
 function change(h,keyName,value)
  state.props{end+1}=struct('handle',h,'key',keyName,'value',get_param(h,keyName));set_param(h,keyName,value);
 end
 function placeTag(parent,tag,pos)
  names=find_system(parent,'SearchDepth',1,'LookUnderMasks','all','BlockType','Goto','GotoTag',tag);
  for name=names(:)',change(get_param(name{1},'Handle'),'Position',pos);end
 end
 function arrangeLinks(parent)
  observerIndex=0;
  children=find_system(parent,'SearchDepth',1,'LookUnderMasks','all','Type','Block');
  for path=children(:)'
   b=path{1};if strcmp(b,parent),continue;end
   if ~ismember(get_param(b,'Tag'),{'PMSMPresentation','PMSMNativeCurrentSamplingScope','PMSMNativeElectricalScope','PMSMNativePWMScope'}),continue;end
   typ=get_param(b,'BlockType');ph=get_param(b,'PortHandles');
   if strcmp(typ,'From')
    ln=get_param(ph.Outport,'Line');if ln<0,continue;end;dst=get_param(ln,'DstPortHandle');dst=dst(dst>=0);
    if numel(dst)~=1,continue;end;pos=get_param(dst,'Position');change(get_param(b,'Handle'),'Position',[pos(1)-180 pos(2)-12 pos(1)-35 pos(2)+12]);
   elseif strcmp(typ,'Goto')
    ln=get_param(ph.Inport,'Line');if ln<0,continue;end;src=get_param(ln,'SrcPortHandle');pos=get_param(src,'Position');
    % Keep observer branches short, alongside their existing local sources.
    if startsWith(get_param(b,'Tag'),'PMSMNative')
     change(get_param(b,'Handle'),'ShowName','off');
     if strcmp(get_param(get_param(src,'Parent'),'BlockType'),'From')
      observerIndex=observerIndex+1;x=30+360*mod(observerIndex-1,4);baseY=1840;if endsWith(parent,'/输出延迟'),baseY=790;end
      y=baseY+80*floor((observerIndex-1)/4);
      local=add_block('simulink/Signal Routing/From',[parent '/_ChainObserver_' num2str(observerIndex)],...
       'GotoTag',get_param(get_param(src,'Parent'),'GotoTag'),'Position',[x y x+145 y+24],'ShowName','off','Tag','PMSMSignalChainLink');
      state.created_blocks(end+1)=local;state.edges{end+1}=struct('parent',parent,'src',src,'dst',ph.Inport);
      delete_line(parent,src,ph.Inport);add_line(parent,get_param(local,'PortHandles').Outport,ph.Inport,'autorouting','on');
      target=[x+185 y x+345 y+24];
     else,target=[pos(1)+35 pos(2)+130 pos(1)+215 pos(2)+154];end
    else,target=[pos(1)+35 pos(2)-65 pos(1)+185 pos(2)-41];end
    change(get_param(b,'Handle'),'Position',target);
   end
  end
 end
end
function route(parent)
% Rebuild visual routes while keeping exact port connectivity and log labels.
blocks=find_system(parent,'SearchDepth',1,'LookUnderMasks','all','Type','Block');edges={};roots=[];
for b=blocks(:)'
 if strcmp(b{1},parent),continue;end;ph=get_param(b{1},'PortHandles');
 for port=ph.Outport(:)'
  ln=get_param(port,'Line');if ln<0,continue;end;dst=get_param(ln,'DstPortHandle');dst=dst(dst>=0);if isempty(dst),continue;end
  meta=struct;for key={'Name','DataLogging','DataLoggingNameMode','DataLoggingName','TestPoint'},try,meta.(key{1})=get_param(ln,key{1});catch,end,end
  edges{end+1}=struct('src',port,'dst',dst,'meta',meta);roots(end+1)=ln;
 end
end
allLines=find_system(parent,'FindAll','on','SearchDepth',1,'LookUnderMasks','all','Type','line');
for h=allLines(:)',try,delete_line(h);catch,end,end
for item=edges
 e=item{1};ln=add_line(parent,e.src,e.dst(1),'autorouting','on');
 for j=2:numel(e.dst),add_line(parent,e.src,e.dst(j),'autorouting','on');end
 for key=fieldnames(e.meta)',try,set_param(ln,key{1},e.meta.(key{1}));catch,end,end
end
end
