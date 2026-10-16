function tidy_flat_layout
% Graphic layout only: every original block, path and connection is retained.
folder=fileparts(mfilename('fullpath')); cd(folder);
mdl='PMSM_FOC_R2026a'; source=fullfile(fileparts(folder),[mdl '.slx']);
load_system(source); guard=onCleanup(@()close_system(mdl,0));
assert(getSimulinkBlockHandle([mdl '/PI Controller_w'])>0,'Expected the flat source model.');
set_param(mdl,'SimulationCommand','update');
before=functionalSnapshot(mdl);
placements=jsondecode(fileread(fullfile(folder,'flat_tidy_positions.json')));
assert(numel(find_system(mdl,'SearchDepth',1,'Type','Block'))==164);
for k=1:numel(placements)
    b=Simulink.ID.getHandle([mdl ':' placements(k).sid]);
    assert(strcmp(get_param(b,'Name'),placements(k).name),'Block identity mismatch.');
    set_param(b,'Position',placements(k).position(:)');
end
% Only the existing explanatory notes are replaced; blocks are never deleted.
notes=find_system(mdl,'FindAll','on','SearchDepth',1,'Type','annotation');
for k=1:numel(notes)
    a=get_param(notes(k),'Object');
    if strcmp(a.Tag,'OriginalLayoutCaption')||strcmp(a.Tag,'FlatTidyCaption')
        delete(a);
    end
end
areas={ ...
 '198','01  速度环',[50 100 910 680],'[0.85 0.94 0.87]'; ...
 '154','02  电流环',[950 100 1810 680],'[0.88 0.87 0.98]'; ...
 '70','03  坐标变换',[1850 100 2710 680],'[0.98 0.93 0.80]'; ...
 '252','04  SVPWM',[50 720 910 1300],'[0.98 0.87 0.82]'; ...
 '31','05  逆变器与 PMSM',[950 720 1810 1300],'[0.83 0.90 0.98]'; ...
 '234','06  采样反馈',[1850 720 2710 1300],'[0.84 0.93 0.94]'; ...
 '254','07  数据观测',[50 1340 910 1920],'[0.89 0.93 0.97]'; ...
 '','08  调制观测',[950 1340 1810 1920],'[0.91 0.90 0.96]'; ...
 '','09  辅助观测',[1850 1340 2710 1920],'[0.95 0.92 0.86]'};
for k=1:size(areas,1)
    if isempty(areas{k,1})
        found=find_system(mdl,'FindAll','on','SearchDepth',1,'Type','annotation','Name',areas{k,2});
        if isempty(found),h=add_block('built-in/Area',[mdl '/' areas{k,2}]);else,h=found(1);end
    else
        h=Simulink.ID.getHandle([mdl ':' areas{k,1}]);
    end
    a=get_param(h,'Object');a.Name=areas{k,2};
    a.FontName='Microsoft YaHei';a.FontSize=16;a.FontWeight='bold';
    a.ForegroundColor=areas{k,4};a.BackgroundColor=areas{k,4};
    a.DropShadow='off';a.FixedWidth='on';a.FixedHeight='on';a.Position=areas{k,3};
    a.Tag='FlatTidyRegion';
end
note(mdl,'4',sprintf('PMSM FOC  |  平铺布局\n原作者：SheeperXu / 2023/11'),[60 15 1100 80],18);
note(mdl,'694',sprintf('MATLAB R2026a  ·  24 V  ·  PWM 20 kHz\n小模块、连接、算法和参数保持原样'),[1920 15 2700 80],12);
note(mdl,'425','参数入口：Model Workspace → MATLAB Code',[90 640 850 665],10);
note(mdl,'168','电机参数仍为演示值',[1000 1260 1750 1285],10);
captions={ ...
 'Clarke / Park',[1890 145 2600 170]; ...
 '逆 Park',[1890 315 2600 340]; ...
 'd 轴',[990 140 1300 165]; ...
 'q 轴',[990 465 1300 490]; ...
 '转矩 → iq 给定',[90 595 800 620]; ...
 '速度 / 转矩',[90 1385 430 1410]; ...
 'id / iq',[500 1385 850 1410]; ...
 '三相电流',[90 1565 430 1590]; ...
 '三相线电压',[500 1565 850 1590]; ...
 'dq 电压反馈',[90 1745 430 1770]; ...
 'dq 电压指令',[500 1745 850 1770]; ...
 '六路门极',[990 1385 1340 1410]; ...
 'αβ 电压',[1400 1385 1750 1410]; ...
 '调制时间',[990 1565 1340 1590]; ...
 '电压矢量',[1400 1565 1750 1590]; ...
 '扇区',[990 1745 1340 1770]; ...
 '母线 / 速度',[1400 1745 1750 1770]; ...
 '原速度辅助对照',[1890 1385 2245 1410]; ...
 '原 id 辅助对照',[2310 1385 2665 1410]; ...
 'Chirp 辅助给定',[1890 1705 2245 1730]; ...
 '数据记录',[2400 1705 2665 1730]};
for k=1:size(captions,1)
    a=Simulink.Annotation(mdl,captions{k,1});a.Interpreter='off';
    a.FontName='Microsoft YaHei';a.FontSize=11;a.ForegroundColor='[0.25 0.31 0.38]';
    a.BackgroundColor='automatic';a.Tag='FlatTidyCaption';
    a.FixedWidth='on';a.FixedHeight='on';a.Position=captions{k,2};
end
lines=find_system(mdl,'FindAll','on','SearchDepth',1,'Type','line');
Simulink.BlockDiagram.routeLine(lines);Simulink.BlockDiagram.routeLine('DeferredLines');
after=functionalSnapshot(mdl);
assert(isequaln(before,after),'Layout changed functional configuration; refusing to save.');
set_param(mdl,'SimulationCommand','update');
unresolved=find_system(mdl,'LookUnderMasks','all','FollowLinks','off','LinkStatus','unresolved');
assert(isempty(unresolved),'Unresolved library links.');
load(fullfile(folder,'before_sim.mat'),'beforeResult');
afterResult=sim(mdl);names=beforeResult.who;
signals=struct('name',{},'samples',{},'max_abs_difference',{},'identical',{});
for k=1:numel(names)
    old=beforeResult.get(names{k});new=afterResult.get(names{k});
    if isa(old,'timeseries')
        same=isequaln(old.Time,new.Time)&&isequaln(old.Data,new.Data);
        signals(end+1)=struct('name',names{k},'samples',numel(old.Time), ...
            'max_abs_difference',max(abs(double(old.Data(:))-double(new.Data(:)))),'identical',same); %#ok<AGROW>
        assert(same,'Simulation changed for %s.',names{k});
    end
end
assert(numel(signals)==12);
report=struct('matlab',version,'top_blocks',numel(placements),'total_blocks',numel(before.blocks), ...
    'paths_parameters_connections_masks_workspace_and_code_identical',isequaln(before,after), ...
    'regions',9,'region_size',[860 580],'unresolved_links',numel(unresolved), ...
    'simulation_stop_time_s',1,'signals',signals,'all_identical',all([signals.identical]));
fid=fopen(fullfile(folder,'flat_tidy_verification.json'),'w','n','UTF-8');
fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));fclose(fid);
set_param(mdl,'ZoomFactor','FitSystem');save_system(mdl,source);
print(['-s' mdl],'-dpng','-r120',fullfile(folder,'flat_tidy.png'));
fprintf('FLAT_TIDY_SAVED: 164 original root blocks; 12 signals bitwise identical.\n');
end

function note(mdl,sid,text,pos,sz)
a=get_param(Simulink.ID.getHandle([mdl ':' sid]),'Object');a.Interpreter='off';
a.Name=text;a.FontName='Microsoft YaHei';a.FontSize=sz;a.FontWeight='normal';
a.ForegroundColor='[0.22 0.29 0.36]';a.BackgroundColor='automatic';
a.FixedWidth='on';a.FixedHeight='on';a.Position=pos;
end

function s=functionalSnapshot(mdl)
blocks=sort(find_system(mdl,'LookUnderMasks','all','FollowLinks','off','Type','Block'));
entries=cell(numel(blocks),1);
for k=1:numel(blocks)
    b=blocks{k};pp=get_param(b,'DialogParameters');params=struct;
    if ~isempty(pp)
        keys=sort(fieldnames(pp));
        for j=1:numel(keys),params.(keys{j})=get_param(b,keys{j});end
    end
    mask=struct;keys={'MaskType','MaskDisplay','MaskInitialization','MaskNames','MaskValues'};
    for j=1:numel(keys),mask.(keys{j})=get_param(b,keys{j});end
    ph=get_param(b,'PortHandles');ins=cell(numel(ph.Inport),1);
    for j=1:numel(ph.Inport)
        ln=get_param(ph.Inport(j),'Line');
        if ln<0,ins{j}=[];continue;end
        src=get_param(ln,'SrcPortHandle');
        if src<0,ins{j}=[];continue;end
        ins{j}={get_param(src,'Parent'),get_param(src,'PortNumber')};
    end
    entries{k}=struct('path',b,'sid',Simulink.ID.getSID(b),'type',get_param(b,'BlockType'), ...
        'parameters',params,'mask',mask,'inputs',{ins});
end
mw=get_param(mdl,'ModelWorkspace');
keys={'SolverType','Solver','FixedStep','StartTime','StopTime','SignalLogging','ReturnWorkspaceOutputs'};
settings=struct;for k=1:numel(keys),settings.(keys{k})=get_param(mdl,keys{k});end
root=sfroot;charts=root.find('-isa','Stateflow.EMChart');code=struct;
for k=1:numel(charts)
    if startsWith(charts(k).Path,[mdl '/']),code.(matlab.lang.makeValidName(charts(k).Path))=charts(k).Script;end
end
s=struct('blocks',{entries},'workspace_source',mw.DataSource,'workspace_code',mw.MATLABCode, ...
    'configuration',settings,'matlab_function_scripts',code);
end
