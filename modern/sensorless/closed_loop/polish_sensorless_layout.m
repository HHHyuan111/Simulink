function polish_sensorless_layout(mdl)
% Geometry and text only. No block, port, parameter or connection is added.
observer=[mdl '/无感观测'];
blocks=find_system(observer,'LookUnderMasks','all','SearchDepth',1,'Type','Block');
constants=blocks(cellfun(@(b)strcmp(get_param(b,'BlockType'),'Constant'),blocks));
for k=1:numel(constants)
    x=60+320*(k-1);b=constants{k};set_param(b,'Position',[x 70 x+110 100]);
    ph=get_param(b,'PortHandles');ln=get_param(ph.Outport,'Line');
    if ln>0
        target=get_param(ln,'DstBlockHandle');
        set_param(target,'Position',[x+135 70 x+285 100]);
    end
end
visible=find_system(observer,'LookUnderMasks','all','SearchDepth',1,'BlockType','GotoTagVisibility');
for k=1:numel(visible)
    x=60+260*mod(k-1,5);y=870+45*floor((k-1)/5);
    set_param(visible{k},'Position',[x y x+240 y+25],'FontSize','9');
end
outs=find_system(observer,'LookUnderMasks','all','SearchDepth',1,'BlockType','Outport');
for k=1:numel(outs)
    n=str2double(get_param(outs{k},'Port'));y=660+65*(n-1);
    set_param(outs{k},'Position',[1260 y 1290 y+20]);
    ph=get_param(outs{k},'PortHandles');source=get_param(get_param(ph.Inport,'Line'),'SrcBlockHandle');
    set_param(source,'Position',[970 y-5 1200 y+25]);
end
systems={...
    [observer '/滑模观测/隐式校正'], ...
    [observer '/反电动势/滤波校正'], ...
    [observer '/锁相环/归一化PLL']};
cards={...
    {'电流预测',300,80,200,110;'隐式边界层',630,80,220,210;'样本与复位选择',1000,80,230,310}, ...
    {'反电势低通',300,80,210,190;'离散链路相位',660,80,230,290;'前端滤波相位',1040,470,230,190;'正交矢量与补偿',1040,80,230,230}, ...
    {'归一化鉴相',300,80,220,240;'条件积分与限速',670,80,230,320;'角度更新与输出',1050,80,230,240}};
for s=1:3
    p=systems{s};rows=cards{s};
    for k=1:size(rows,1)
        x=rows{k,2};y=rows{k,3};set_param([p '/' rows{k,1}],'Position',[x y x+rows{k,4} y+rows{k,5}]);
    end
    inputs=find_system(p,'SearchDepth',1,'BlockType','Inport');
    for k=1:numel(inputs)
        n=str2double(get_param(inputs{k},'Port'));set_param(inputs{k},'Position',[25 70+75*(n-1) 55 90+75*(n-1)]);
    end
    outputs=find_system(p,'SearchDepth',1,'BlockType','Outport');
    for k=1:numel(outputs)
        n=str2double(get_param(outputs{k},'Port'));y=80+75*(n-1);
        set_param(outputs{k},'Position',[1550 y 1580 y+20]);
        ph=get_param(outputs{k},'PortHandles');source=get_param(get_param(ph.Inport,'Line'),'SrcBlockHandle');
        if strcmp(get_param(source,'BlockType'),'Reshape'),set_param(source,'Position',[1370 y-5 1470 y+25]);end
    end
    declarations=find_system(p,'SearchDepth',1,'BlockType','Goto');
    parameters=find_system(p,'SearchDepth',1,'BlockType','SubSystem');j=0;
    for k=1:numel(parameters)
        q=parameters{k};if ~endsWith(get_param(q,'Name'),'参数展开'),continue;end
        x=280+600*j;ph=get_param(q,'PortHandles');height=70+45*numel(ph.Outport);
        set_param(q,'Position',[x 950 x+220 950+height]);
        for n=1:numel(ph.Outport)
            target=get_param(get_param(ph.Outport(n),'Line'),'DstBlockHandle');
            set_param(target,'Position',[x+270 970+45*(n-1) x+470 995+45*(n-1)]);
        end
        j=j+1;
    end
    reads=find_system(p,'SearchDepth',1,'BlockType','From');counters=struct;
    for k=1:numel(reads)
        b=reads{k};ph=get_param(b,'PortHandles');ln=get_param(ph.Outport,'Line');target=get_param(ln,'DstBlockHandle');
        name=get_param(target,'Name');column=1;
        for j=1:size(rows,1),if strcmp(name,rows{j,1}),column=j;break;end,end
        key=['column_' num2str(column)];if ~isfield(counters,key),counters.(key)=0;end
        n=counters.(key);counters.(key)=n+1;x=rows{column,2};y=470+45*n;
        if strcmp(name,'前端滤波相位'),y=720+45*n;end
        set_param(b,'Position',[x y x+190 y+25]);
    end
    delays=find_system(p,'SearchDepth',1,'BlockType','UnitDelay');
    for k=1:numel(delays),x=300+360*(k-1);set_param(delays{k},'Position',[x 790 x+120 835]);end
    annotations=find_system(p,'FindAll','on','SearchDepth',1,'Type','annotation');
    for k=1:numel(annotations),set_param(annotations(k),'Position',[25 895 1450 925]);end
    tags=[reads;declarations];
    for k=1:numel(tags)
        set_param(tags{k},'IconDisplay','Tag','ShowName','off','FontName','Microsoft YaHei','FontSize','10');
    end
    reroute(p);set_param(p,'ZoomFactor','FitSystem');
end
% Remove stale bend points after moving the retained functional-mask ports.
reroute(observer);reroute(mdl);
rootCards=find_system(mdl,'SearchDepth',1,'BlockType','SubSystem');
for k=1:numel(rootCards),set_param(rootCards{k},'FontSize','12');end
end

function reroute(p)
lines=find_system(p,'LookUnderMasks','all','FindAll','on','SearchDepth',1,'Type','line');
top=lines(arrayfun(@(h)get_param(h,'LineParent')==-1,lines));
for k=1:numel(top),Simulink.BlockDiagram.routeLine(top(k));end
end
