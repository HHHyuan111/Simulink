function route_sensorless_pages(mdl)
% Move long inter-page wires to named scoped channels, without delays or casts.
marker=[mdl '/页面作用域_Cmd_speed_rpm'];
if getSimulinkBlockHandle(marker)<0
    lines=find_system(mdl,'FindAll','on','SearchDepth',1,'Type','line');
    records=struct('source',{},'source_port',{},'source_inner',{},'destinations',{},'destination_inner',{},'tag',{});
    for k=1:numel(lines)
        if get_param(lines(k),'LineParent')~=-1,continue;end
        source=get_param(lines(k),'SrcPortHandle');targets=get_param(lines(k),'DstPortHandle');
        if source<0||isempty(targets)||any(targets<0),continue;end
        block=get_param(source,'Parent');port=get_param(source,'PortNumber');name=get_param(block,'Name');
        r=struct('source',block,'source_port','','source_inner',source,'destinations',{{}},'destination_inner',{{}},'tag',channel(name,port));
        if strcmp(get_param(block,'BlockType'),'SubSystem') && ~functional_mask(block)
            output=find_port(block,'Outport',port);r.source_port=output;
            ip=get_param(output,'PortHandles');r.source_inner=get_param(get_param(ip.Inport,'Line'),'SrcPortHandle');
        end
        for target=targets(:)'
            parent=get_param(target,'Parent');
            if functional_mask(parent)
                r.destinations{end+1}=parent;r.destination_inner{end+1}=target;
            else
                input=find_port(parent,'Inport',get_param(target,'PortNumber'));
                ip=get_param(input,'PortHandles');ln=get_param(ip.Outport,'Line');
                r.destinations{end+1}=input;r.destination_inner{end+1}=get_param(ln,'DstPortHandle');
            end
        end
        records(end+1)=r; %#ok<AGROW>
    end
    % Snapshot every endpoint before deleting any external port or branch.
    top=lines(arrayfun(@(ln)get_param(ln,'LineParent')==-1,lines));
    for k=1:numel(top),delete_line(top(k));end
    for k=1:numel(records)
        r=records(k);parent=r.source;
        if isempty(r.source_port),parent=mdl;end
        gotoname=['页面发布_' r.tag];
        add_block('simulink/Signal Routing/Goto',[parent '/' gotoname], ...
            'GotoTag',r.tag,'TagVisibility','scoped','Position',[1450 60+45*k 1660 85+45*k],'ShowName','off');
        ph=get_param([parent '/' gotoname],'PortHandles');add_line(parent,r.source_inner,ph.Inport,'autorouting','on');
        add_block('simulink/Signal Routing/Goto Tag Visibility',[mdl '/页面作用域_' r.tag], ...
            'GotoTag',r.tag,'Position',[60 1200+35*k 300 1225+35*k],'ShowName','off');
    end
    for k=1:numel(records)
        r=records(k);
        for j=1:numel(r.destinations)
            input=r.destinations{j};parent=get_param(input,'Parent');name=['页面接收_' r.tag '_' num2str(j)];
            pos=get_param(input,'Position');
            if ~functional_mask(input)
                ip=get_param(input,'PortHandles');ln=get_param(ip.Outport,'Line');
                if ln>0,delete_line(ln);end
                delete_block(input);
            end
            add_block('simulink/Signal Routing/From',[parent '/' name],'GotoTag',r.tag, ...
                'Position',[pos(1) pos(2) pos(1)+210 pos(2)+25],'ShowName','off');
            ph=get_param([parent '/' name],'PortHandles');
            for target=r.destination_inner{j}(:)',add_line(parent,ph.Outport,target,'autorouting','on');end
        end
    end
    for k=1:numel(records)
        if ~isempty(records(k).source_port)
            r=records(k);source=get_param(r.source_inner,'Parent');parent=get_param(r.source_port,'Parent');
            delete_line(parent,[get_param(source,'Name') '/' num2str(get_param(r.source_inner,'PortNumber'))], ...
                [get_param(r.source_port,'Name') '/1']);
            delete_block(r.source_port);
        end
    end
end
% Compact the root into five columns; the order follows the control path.
positions={'电流给定',60,245;'电流调节',340,245;'限压',620,245; ...
    '电压坐标变换',900,245;'空间矢量调制',1180,245; ...
    '输出延迟',60,410;'PWM比较与门极',340,410;'逆变器与直流母线',620,410; ...
    '永磁同步电机',900,410;'采样设置',1180,410; ...
    '电流坐标变换',60,575;'无感观测',340,575;'闭环控制',900,575};
for k=1:size(positions,1)
    p=[mdl '/' positions{k,1}];x=positions{k,2};y=positions{k,3};
    set_param(p,'Position',[x y x+210 y+85]);
    ph=get_param(p,'PortHandles');
    for port=numel(ph.Outport):-1:1
        if get_param(ph.Outport(port),'Line')<0 && ~functional_mask(p),delete_block(find_port(p,'Outport',port));end
    end
end
set_param([mdl '/speed_ref'],'Position',[1180 590 1300 630]);
set_param([mdl '/页面发布_Cmd_speed_rpm'],'Position',[1180 680 1390 710]);
set_param([mdl '/页面发布_FB_smo_packet'],'Position',[620 585 830 615]);
set_param([mdl '/页面发布_FB_smo_permit'],'Position',[620 630 830 660]);
set_param([mdl '/页面发布_PWM_applied_threshold'],'Position',[60 510 270 535]);
set_param([mdl '/页面接收_PWM_requested_threshold_1'],'Position',[60 365 270 390]);
% Disable faded content thumbnails. The actual subsystem opens normally.
blocks=find_system(mdl,'SearchDepth',1,'BlockType','SubSystem');
for k=1:numel(blocks)
    p=blocks{k};if strcmp(p,mdl),continue;end
    parameters=get_param(p,'ObjectParameters');
    if isfield(parameters,'ContentPreviewEnabled'),set_param(p,'ContentPreviewEnabled','off');end
    if isempty(Simulink.Mask.get(p))
        mask=Simulink.Mask.create(p);mask.Display=['disp(''' strrep(get_param(p,'Name'),'''','''''') ''')'];
        set_param(p,'OpenFcn','open_system(gcb,''force'');');
    end
end
scopes=find_system(mdl,'SearchDepth',1,'BlockType','GotoTagVisibility');
for k=1:numel(scopes)
    x=60+280*mod(k-1,5);y=1030+45*floor((k-1)/5);
    set_param(scopes{k},'Position',[x y x+255 y+25],'FontName','Microsoft YaHei','FontSize','9','ShowName','off');
end
% Label the routing convention once on the main page.
annotations=find_system(mdl,'FindAll','on','SearchDepth',1,'Type','annotation');
for k=1:numel(annotations)
    text=get_param(annotations(k),'Name');
    if startsWith(text,'PWM 执行与电机'),set_param(annotations(k),'Position',[340 370 640 395]);end
    if startsWith(text,'无感反馈'),set_param(annotations(k),'Position',[60 550 390 572]);end
end

function result=functional_mask(path)
mask=Simulink.Mask.get(path);
result=~isempty(mask)&&(~isempty(mask.Parameters)||~isempty(strtrim(mask.Initialization)));
end
a=Simulink.Annotation(mdl,'层间信号使用具名 Goto / From；局部方程直接连线。');
a.Position=[60 695];a.FontName='Microsoft YaHei';a.FontSize=11;a.ForegroundColor='[0.35 0.40 0.45]';
end

function path=find_port(parent,type,number)
blocks=find_system(parent,'LookUnderMasks','all','SearchDepth',1,'BlockType',type);
for k=1:numel(blocks)
    if str2double(get_param(blocks{k},'Port'))==number,path=blocks{k};return;end
end
error('sensorless:PagePort','Missing %s %d in %s',type,number,parent);
end

function tag=channel(name,port)
switch name
    case 'speed_ref',tag='Cmd_speed_rpm';
    case '无感观测',tags={'FB_smo_packet','FB_smo_permit'};tag=tags{port};
    case '空间矢量调制',tag='PWM_requested_threshold';
    case '输出延迟',tag='PWM_applied_threshold';
    case '逆变器与直流母线',tags={'Plant_voltage_abc','Plant_measured_current_abc'};tag=tags{port};
    case '永磁同步电机',tags={'Plant_measurement_1','Plant_measurement_2','Plant_measurement_3','Plant_phase_current_abc'};tag=tags{port};
    case 'PWM比较与门极',tags={'View_voltage_ab','View_voltage_bc','View_voltage_ca'};tag=tags{port};
    case '辅助观测',tag='View_voltage_abc';
    otherwise,error('sensorless:PageSignal','Name the page signal from %s port %d',name,port);
end
end
