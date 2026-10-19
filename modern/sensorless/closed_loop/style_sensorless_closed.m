function report = style_sensorless_closed(mdl)
% Functional hierarchy and a restrained engineering drawing style.
% All groups are virtual: controller states and task boundaries are untouched.
blue='[0.86 0.92 0.97]';green='[0.86 0.94 0.90]';
sand='[0.97 0.93 0.84]';gray='[0.95 0.95 0.95]';
group(mdl,'电流坐标变换',{'199','200','183','191','593','597','62','65','66','265'},[780 570 960 650],blue);
group(mdl,'电压坐标变换',{'228','229','231','232','233','235','606','236','237','238','266'},[1020 245 1200 325],blue);
group(mdl,'电流给定',{'1624','1625','193','222','197','194','195','196','216','217','215','578','201','190','169','509'},[60 245 240 325],green);
group(mdl,'电流调节',{'40','133','439','453','144','152','991','992','1048','1049','206','210','202','203','579','1628','869','139','209','212','141','213','214','990','468','220','221'},[300 245 480 325],blue);
group(mdl,'空间矢量调制',{'240','243','242','246','247','1039','1040','1041','1042','718','307','372'},[1260 245 1440 325],blue);
group(mdl,'PWM比较与门极',{'324','426','886','295','346','347','348','291','292','293','299','300','301','298','244','334','302'},[1020 410 1200 490],sand);
group(mdl,'逆变器与直流母线',{'245','681','615','682','496','845','671','281','32','34','28'},[780 410 960 490],sand);
group(mdl,'永磁同步电机',{'626','649','660','171','186','188','172','189','177','180','523','506','358','359','693'},[540 410 720 490],sand);
% Legacy auxiliary plots are retained on a separate page.
all=find_system(mdl,'SearchDepth',1,'Type','Block');selected=[];
for k=1:numel(all)
    b=all{k};if strcmp(b,mdl),continue;end
    type=get_param(b,'BlockType');pos=get_param(b,'Position');sid=get_param(b,'SID');
    old=str2double(sid)<1144;
    if old&&pos(2)>=1350&&~strcmp(type,'SubSystem'),selected(end+1)=get_param(b,'Handle');end %#ok<AGROW>
    if old&&ismember(sid,{'683','688'}),selected(end+1)=get_param(b,'Handle');end %#ok<AGROW>
end
if ~isempty(selected),make_group(selected,'辅助观测',[1260 795 1440 850],gray);end
move_feedback_tags(mdl);
place(mdl,'限压',[780 245 960 325],blue);
place(mdl,'输出延迟',[1260 410 1440 490],sand);
place(mdl,'闭环控制',[60 570 240 650],green);
place(mdl,'无感观测',[540 570 720 650],blue);
place(mdl,'采样设置',[300 410 480 490],green);
place(mdl,'speed_ref',[60 420 180 460],green);
settings={'时序设置','功率设置','角度设置','解耦','角度生成'};
for k=1:numel(settings),place(mdl,settings{k},[60+280*(k-1) 90 240+280*(k-1) 145],gray);end
observations={'闭环结果观测','跟踪观测','PI观测','时序观测','测量观测','功率观测'};
for k=1:numel(observations),place(mdl,observations{k},[60+240*(k-1) 795 240+240*(k-1) 850],gray);end
% Keep auxiliary observations on their own second row if the root has six viewers.
place(mdl,'辅助观测',[1260 890 1440 945],gray);
layout_visibility(mdl,1030,5,280);
remove_annotations(mdl);
annotation(mdl,'PMSM 无感矢量控制',[60 15],22,'[0.13 0.23 0.32]');
annotation(mdl,'工程设置',[60 60],12,'[0.35 0.40 0.45]');
annotation(mdl,'电流与电压调节',[60 205],14,'[0.19 0.32 0.43]');
annotation(mdl,'PWM 执行与电机',[300 370],14,'[0.40 0.32 0.20]');
annotation(mdl,'无感反馈 · Ts = 50 μs',[60 530],14,'[0.19 0.32 0.43]');
annotation(mdl,'原生观察入口',[60 745],14,'[0.35 0.40 0.45]');
annotation(mdl,'信号作用域',[60 1000],11,'[0.45 0.45 0.45]');
annotation(mdl,'3000 rpm  |  0.34 s 加载 0.207 N·m  |  ADC、门极死区及发布延迟保留',[460 25],11,'[0.35 0.40 0.45]');
style_observer(mdl,blue,green,gray);
style_core(mdl);
style_observations(mdl);
blocks=find_system(mdl,'LookUnderMasks','all','FollowLinks','off','Type','Block');
for k=1:numel(blocks)
    if strcmp(blocks{k},mdl),continue;end
    set_param(blocks{k},'FontName','Microsoft YaHei','FontSize','10');
    if ismember(get_param(blocks{k},'BlockType'),{'From','Goto'}),set_param(blocks{k},'ShowName','off');end
end
set_param(mdl,'ScreenColor','white','ZoomFactor','FitSystem');
route_system(mdl);
finish_sensorless_style(mdl);
report=struct('virtual_function_groups',9,'font','Microsoft YaHei','scoped_signal_routing',true);
end

function group(mdl,name,sids,pos,color)
handles=[];
for k=1:numel(sids)
    b=Simulink.ID.getHandle([mdl ':' sids{k}]);
    assert(strcmp(get_param(b,'Parent'),mdl),'Expected root block %s',sids{k});
    handles(end+1)=b; %#ok<AGROW>
end
make_group(handles,name,pos,color);
end

function path=make_group(handles,name,pos,color)
parent=get_param(handles(1),'Parent');
Simulink.BlockDiagram.createSubSystem(handles);
p=get_param(handles(1),'Parent');set_param(p,'Name',name);path=[parent '/' name];
set_param(path,'Position',pos,'BackgroundColor',color,'ShowName','on');
Simulink.BlockDiagram.arrangeSystem(path,'FullLayout','true');
end

function move_feedback_tags(mdl)
% Publish where the controller computes the signals, with root-scoped visibility.
p=[mdl '/闭环控制'];outports=find_system(p,'SearchDepth',1,'BlockType','Outport');
for k=1:numel(outports)
    port=str2double(get_param(outports{k},'Port'));ph=get_param(outports{k},'PortHandles');
    source=get_param(get_param(ph.Inport,'Line'),'SrcPortHandle');
    rootph=get_param(p,'PortHandles');ln=get_param(rootph.Outport(port),'Line');
    if ln<0,continue;end
    targets=get_param(ln,'DstBlockHandle');
    for target=targets(:)'
        assert(strcmp(get_param(target,'BlockType'),'Goto'));
        name=get_param(target,'Name');tag=get_param(target,'GotoTag');vis=get_param(target,'TagVisibility');
        add_block('simulink/Signal Routing/Goto',[p '/' name],'GotoTag',tag,'TagVisibility',vis, ...
            'Position',[1050 40+50*port 1240 65+50*port],'ShowName','off');
        tp=get_param([p '/' name],'PortHandles');add_line(p,source,tp.Inport,'autorouting','on');
    end
end
% Remove from highest port down so port renumbering cannot change destinations.
numbers=cellfun(@(b)str2double(get_param(b,'Port')),outports);[~,order]=sort(numbers,'descend');
for i=order(:)'
    port=str2double(get_param(outports{i},'Port'));ph=get_param(p,'PortHandles');ln=get_param(ph.Outport(port),'Line');
    if ln>0,targets=get_param(ln,'DstBlockHandle');delete_line(ln);for target=targets(:)',delete_block(target);end,end
    ip=get_param(outports{i},'PortHandles');delete_line(get_param(ip.Inport,'Line'));delete_block(outports{i});
end
Simulink.BlockDiagram.arrangeSystem(p,'FullLayout','true');
end

function style_observer(mdl,blue,green,gray)
p=[mdl '/无感观测'];mask=Simulink.Mask.get(p);mask.Display="disp('SMO + PLL')";
enable=mask.getParameter('enabled');enable.Prompt='启用无感观测';
remove_annotations(p);
cards={'采样输入',60,170,green;'区间电压',360,170,green;'执行许可',660,170,gray; ...
 '滑模观测',60,355,blue;'反电动势',360,355,blue;'锁相环',660,355,blue; ...
 '有效判断',960,355,green;'发布许可',960,170,green;'观测',960,550,gray};
for k=1:size(cards,1),place(mdl,['无感观测/' cards{k,1}],[cards{k,2} cards{k,3} cards{k,2}+210 cards{k,3}+80],cards{k,4});end
% Separate configuration and exports from the algorithm cards.
all=find_system(p,'LookUnderMasks','all','SearchDepth',1,'Type','Block');config=0;exports=0;
for k=1:numel(all)
    b=all{k};if strcmp(b,p),continue;end
    type=get_param(b,'BlockType');
    if strcmp(type,'Constant')
        set_param(b,'Position',[60+300*config 65 165+300*config 95]);config=config+1;
        ln=get_param(get_param(b,'PortHandles').Outport,'Line');if ln>0,d=get_param(ln,'DstBlockHandle');set_param(d,'Position',[185+300*(config-1) 65 280+300*(config-1) 95]);end
    elseif strcmp(type,'Outport')
        port=str2double(get_param(b,'Port'));set_param(b,'Position',[1230 570+60*port 1260 590+60*port]);
    elseif strcmp(type,'From')
        set_param(b,'Position',[960 630+60*exports 1160 655+60*exports]);exports=exports+1;
    end
end
layout_visibility(p,860,5,255);
annotation(p,'无感位置与转速观测',[60 15],20,'[0.13 0.23 0.32]');
annotation(p,'输入与区间对齐',[60 135],12,'[0.35 0.40 0.45]');
annotation(p,'离散观测主链路',[60 315],14,'[0.19 0.32 0.43]');
annotation(p,'状态与发布',[960 315],12,'[0.35 0.40 0.45]');
annotation(p,'复位、样本有效和参数在本层通过作用域信号分发。',[60 555],11,'[0.35 0.40 0.45]');
annotation(p,'SMO：隐式校正  |  EMF：低通及相位补偿  |  PLL：归一化鉴相与条件积分',[60 600],11,'[0.35 0.40 0.45]');
annotation(p,'信号作用域',[60 825],11,'[0.45 0.45 0.45]');
route_system(p);
end

function style_core(mdl)
roots={[mdl '/无感观测/滑模观测'],[mdl '/无感观测/反电动势'],[mdl '/无感观测/锁相环']};
for r=1:numel(roots)
    systems=find_system(roots{r},'LookUnderMasks','all','BlockType','SubSystem');
    for j=numel(systems):-1:1
        p=systems{j};if strcmp(get_param(p,'MaskType'),'Stateflow'),continue;end
        if numel(find_system(p,'SearchDepth',1,'Type','Block'))>1
            Simulink.BlockDiagram.arrangeSystem(p,'FullLayout','true');
            set_param(p,'ZoomFactor','FitSystem','ScreenColor','white');
        end
    end
end
end

function style_observations(mdl)
p=[mdl '/闭环结果观测'];
% Rename automatic display identifiers without touching signal labels or logs.
prefixes={'速度对照','切换状态','角度误差','三相电流'};
blocks=find_system(p,'SearchDepth',1,'Type','Block');
for k=1:numel(blocks)
    b=blocks{k};if strcmp(b,p),continue;end
    n=get_param(b,'Name');tokens=regexp(n,'^显示([12])_([1-4])_(.*)$','tokens','once');
    if isempty(tokens),continue;end
    periods={'全程','稳态'};name=[periods{str2double(tokens{1})} '_' prefixes{str2double(tokens{2})} '_' tokens{3}];
    set_param(b,'Name',name);
end
Simulink.BlockDiagram.arrangeSystem(p,'FullLayout','true');
set_param(p,'ScreenColor','white','ZoomFactor','FitSystem');
% The observer's legacy logs are kept, with the original callbacks and names.
p=[mdl '/无感观测/观测'];Simulink.BlockDiagram.arrangeSystem(p,'FullLayout','true');
end

function layout_visibility(p,y,columns,spacing)
blocks=find_system(p,'LookUnderMasks','all','SearchDepth',1,'BlockType','GotoTagVisibility');
for k=1:numel(blocks)
    x=60+spacing*mod(k-1,columns);yy=y+48*floor((k-1)/columns);
    set_param(blocks{k},'Position',[x yy x+spacing-25 yy+25],'ShowName','off');
end
end

function place(mdl,name,pos,color)
p=[mdl '/' name];if getSimulinkBlockHandle(p)<0,return;end
set_param(p,'Position',pos,'BackgroundColor',color,'ShowName','on');
end

function remove_annotations(p)
items=find_system(p,'FindAll','on','SearchDepth',1,'Type','annotation');
for k=1:numel(items),delete(items(k));end
end

function annotation(p,text,pos,size,color)
a=Simulink.Annotation(p,text);a.Position=pos;a.FontName='Microsoft YaHei';a.FontSize=size;a.ForegroundColor=color;
end

function route_system(p)
lines=find_system(p,'FindAll','on','SearchDepth',1,'Type','line');
for k=1:numel(lines)
    if get_param(lines(k),'LineParent')==-1,Simulink.BlockDiagram.routeLine(lines(k));end
end
end
