function organize_original_layout
error('旧排版脚本已停用；当前纯布局脚本为 tidy_flat_layout。');
% Only graphic properties are changed. All existing functional blocks stay.
folder=fileparts(mfilename('fullpath'));
mdl='PMSM_FOC_R2026a'; source=fullfile(fileparts(folder),[mdl '.slx']);
load_system(source); guard=onCleanup(@() close_system(mdl,0));
if getSimulinkBlockHandle([mdl '/速度环'])>0
    error('模型已完成层级整理，旧版平铺布局脚本不再适用。');
end
open_system(mdl);drawnow;
before=functionalSnapshot(mdl);
fprintf('SNAPSHOT_OK\n');
placements=jsondecode(fileread(fullfile(folder,'layout_positions.json')));
for k=1:numel(placements)
    if mod(k,25)==0,fprintf('POSITION %d / %d\n',k,numel(placements));end
    b=Simulink.ID.getHandle([mdl ':' placements(k).sid]);
    assert(strcmp(get_param(b,'Name'),placements(k).name),'Block identity mismatch.');
    set_param(b,'Position',placements(k).position(:)', ...
        'Orientation','right','FontName','Arial','FontSize','10', ...
        'ForegroundColor','black','BackgroundColor','white','DropShadow','off');
    typ=get_param(b,'BlockType');
    if ismember(typ,{'From','Goto','Constant','Gain','Sum','Product','Abs', ...
            'Mux','Demux','RateTransition','ZeroOrderHold','Logic','RelationalOperator','Terminator'})
        set_param(b,'ShowName','off');
    else
        set_param(b,'ShowName','on');
    end
    if strcmp(typ,'SubSystem')
        if strcmp(get_param(b,'LinkStatus'),'none')
            set_param(b,'ContentPreviewEnabled','off');
            set_param(b,'ShowPortLabels','none');
        end
        set_param(b,'BackgroundColor','[0.91 0.95 0.99]');
    end
    if strcmp(typ,'From') || strcmp(typ,'Goto')
        set_param(b,'BackgroundColor','[0.96 0.97 0.98]');
    end
    if ismember(placements(k).sid,{'592','590','523'})
        set_param(b,'BackgroundColor','[1 0.91 0.73]','ShowName','on');
    elseif ismember(placements(k).sid,{'155','439','453'})
        set_param(b,'BackgroundColor','[0.78 0.92 0.88]');
    end
end
fprintf('BLOCK_LAYOUT_OK\n');

% Reuse all seven existing area annotations.
areas={ ...
 '31','01  功率级与 PMSM',[50 100 850 530],'[0.93 0.96 0.99]'; ...
 '234','02  测量反馈与角度',[900 100 1620 530],'[0.94 0.96 0.99]'; ...
 '70','03  坐标变换 / 逆变换',[1650 100 2530 530],'[0.99 0.97 0.92]'; ...
 '198','04  速度环与电流给定',[50 565 820 1120],'[0.94 0.98 0.94]'; ...
 '154','05  d / q 电流环',[850 565 1710 1120],'[0.94 0.93 0.99]'; ...
 '252','06  SVPWM 与六路门极',[1750 565 2530 1120],'[1 0.95 0.93]'; ...
 '254','07  波形观测与辅助信号',[50 1150 2530 1880],'[0.97 0.97 0.98]'};
for k=1:size(areas,1)
    fprintf('AREA %s\n',areas{k,1});
    h=Simulink.ID.getHandle([mdl ':' areas{k,1}]); a=get_param(h,'Object');
    a.Name=areas{k,2}; a.FontName='Microsoft YaHei';a.FontSize=14;a.FontWeight='bold';
    a.ForegroundColor=areas{k,4};a.BackgroundColor=areas{k,4};
    a.DropShadow='off';a.FixedWidth='on';a.FixedHeight='on';a.Position=areas{k,3};
end
fprintf('AREAS_OK\n');
% Replace overlapping notes with readable text; retain author attribution.
note(mdl,'4',sprintf('PMSM FOC  |  原模型布局整理\n原作者：SheeperXu / 2023/11'),[60 15 1050 80],18);
note(mdl,'694',sprintf('MATLAB R2026a  ·  24 V  ·  PWM 20 kHz\n原控制算法与参数保留；电机参数仍为演示值'),[1450 15 2520 80],12);
note(mdl,'425','参数入口：Model Workspace → MATLAB Code',[90 540 800 560],10);
note(mdl,'168','橙色：主控制给定 / 负载输入     绿色：原 PI 控制器',[900 540 1610 560],10);

captions={ ...
 'Clarke → Park：采样相电流转换为 id / iq',[1680 135 2470 160]; ...
 '逆 Park：vd / vq 转换为 vα / vβ',[1680 315 2470 340]; ...
 'dq 反馈端口：Vq_re / Vd_re',[950 370 1240 400]; ...
 '原转矩 → iq_ref 换算',[90 1060 780 1090]; ...
 '保留原解耦支路；未使用支路仍保留',[900 1090 1650 1110]; ...
 'Scope1：速度 / 转矩',[90 1190 490 1210]; ...
 'Scope8：id / iq',[580 1190 980 1210]; ...
 'Scope3：三相电流',[1070 1190 1470 1210]; ...
 'Scope4：三相线电压',[1560 1190 1960 1210]; ...
 'Scope14 / 15：dq 反馈与指令',[2050 1190 2500 1210]; ...
 'Scope2：六路门极',[90 1390 490 1410]; ...
 'Scope5：αβ 电压',[580 1390 980 1410]; ...
 'Scope11：调制时间',[1070 1390 1470 1410]; ...
 'XY Graph1：电压矢量轨迹',[1560 1390 1960 1410]; ...
 'Scope7：扇区',[2050 1390 2500 1410]; ...
 'Scope9：母线 / 速度',[90 1570 490 1590]; ...
 '原速度辅助对照',[580 1570 980 1590]; ...
 '原 id 辅助对照',[1070 1570 1470 1590]; ...
 'Chirp 辅助信号源',[1560 1570 1960 1590]; ...
 '验证数据记录',[2050 1570 2500 1590]; ...
 '辅助对照使用原 Chirp 标签；不代表主速度 / id 给定',[580 1850 1950 1870]};
for k=1:size(captions,1)
    handles=find_system(mdl,'FindAll','on','SearchDepth',1,'Type','annotation');
    a=[];
    for j=1:numel(handles)
        candidate=get_param(handles(j),'Object');
        if strcmp(candidate.Name,captions{k,1}),a=candidate;break;end
    end
    if isempty(a),a=Simulink.Annotation(mdl,captions{k,1});end
    a.FontName='Microsoft YaHei';a.FontSize=10;a.ForegroundColor='[0.35 0.40 0.46]';
    a.BackgroundColor='automatic';a.Tag='OriginalLayoutCaption';
    a.FixedWidth='on';a.FixedHeight='on';a.Position=captions{k,2};
end
fprintf('NOTES_OK\n');
lines=find_system(mdl,'FindAll','on','SearchDepth',1,'Type','line');
Simulink.BlockDiagram.routeLine(lines);
Simulink.BlockDiagram.routeLine('DeferredLines');
fprintf('ROUTES_OK\n');
after=functionalSnapshot(mdl);
assert(isequaln(before,after),'Functional configuration changed; refusing to save.');
set_param(mdl,'SimulationCommand','update');
unresolved=find_system(mdl,'LookUnderMasks','all','FollowLinks','off','LinkStatus','unresolved');
assert(isempty(unresolved),'Unresolved library links.');
load(fullfile(folder,'before_sim.mat'),'beforeResult');
afterResult=sim(mdl);
names=beforeResult.who; signals=struct('name',{},'samples',{},'max_abs_difference',{},'identical',{});
for k=1:numel(names)
    old=beforeResult.get(names{k});new=afterResult.get(names{k});
    if isa(old,'timeseries')
        same=isequaln(old.Time,new.Time) && isequaln(old.Data,new.Data);
        signals(end+1)=struct('name',names{k},'samples',numel(old.Time), ...
            'max_abs_difference',max(abs(double(old.Data(:))-double(new.Data(:)))), ...
            'identical',same); %#ok<AGROW>
        assert(same,'Simulation changed for %s.',names{k});
    end
end
assert(~isempty(signals),'No simulation signals compared.');
report=struct('matlab',version,'top_blocks',numel(placements), ...
    'functional_snapshot_identical',isequaln(before,after), ...
    'unresolved_links',numel(unresolved),'simulation_stop_time_s',1, ...
    'signals',signals,'all_identical',all([signals.identical]));
fid=fopen(fullfile(folder,'layout_verification.json'),'w','n','UTF-8');
fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));fclose(fid);
set_param(mdl,'ZoomFactor','FitSystem');
save_system(mdl,source);
print(['-s' mdl],'-dpng','-r120',fullfile(folder,'after.png'));
fprintf('LAYOUT_SAVED: %d blocks; %d signals bitwise identical.\n',numel(placements),numel(signals));
end

function note(mdl,sid,text,pos,sz)
fprintf('NOTE %s\n',sid);
a=get_param(Simulink.ID.getHandle([mdl ':' sid]),'Object');
a.Interpreter='off';
a.Name=text;a.FontName='Microsoft YaHei';a.FontSize=sz;a.FontWeight='normal';
a.ForegroundColor='[0.22 0.29 0.36]';a.BackgroundColor='automatic';
a.FixedWidth='on';a.FixedHeight='on';a.Position=pos;
end

function s=functionalSnapshot(mdl)
blocks=sort(find_system(mdl,'LookUnderMasks','all','FollowLinks','off','Type','Block'));
ignore={'ShowPortLabels','ShowSubsystemReinitializePorts','ContentPreviewEnabled'};
entries=cell(numel(blocks),1);
for k=1:numel(blocks)
    b=blocks{k};pp=get_param(b,'DialogParameters'); params=struct;
    if ~isempty(pp)
        keys=sort(fieldnames(pp));
        for j=1:numel(keys)
            if ~ismember(keys{j},ignore), params.(keys{j})=get_param(b,keys{j});end
        end
    end
    ph=get_param(b,'PortHandles');ins=cell(numel(ph.Inport),1);
    for j=1:numel(ph.Inport)
        ln=get_param(ph.Inport(j),'Line');
        if ln<0,ins{j}=[];continue;end
        src=get_param(ln,'SrcPortHandle');
        if src<0,ins{j}=[];continue;end
        ins{j}={get_param(src,'Parent'),get_param(src,'PortNumber')};
    end
    entries{k}=struct('path',b,'type',get_param(b,'BlockType'),'parameters',params,'inputs',{ins});
end
mw=get_param(mdl,'ModelWorkspace');
keys={'SolverType','Solver','FixedStep','StartTime','StopTime','SignalLogging','ReturnWorkspaceOutputs'};
settings=struct;for k=1:numel(keys),settings.(keys{k})=get_param(mdl,keys{k});end
root=sfroot;charts=root.find('-isa','Stateflow.EMChart');code=struct;
for k=1:numel(charts)
    if startsWith(charts(k).Path,[mdl '/'])
        code.(matlab.lang.makeValidName(charts(k).Path))=charts(k).Script;
    end
end
s=struct('blocks',{entries},'workspace_source',mw.DataSource,'workspace_code',mw.MATLABCode, ...
    'configuration',settings,'matlab_function_scripts',code);
end
