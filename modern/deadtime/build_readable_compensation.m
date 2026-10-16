function build_readable_compensation(mode)
% Expose the SAME polarity feedforward with ordinary blocks. No gain tuning.
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);addpath(fullfile(root,'teaching'));
if nargin && strcmp(mode,'redraw')
 work=fullfile(root,'.build','readable_compensation');mdl='PMSM_FOC_R2026a';candidate=fullfile(work,[mdl '.slx']);recordFile=fullfile(folder,'readable_compensation_results.json');record=jsondecode(fileread(recordFile));assert(record.all_passed&&strcmp(teach_hash(candidate),record.model_sha256));
 load_system(candidate);guard=onCleanup(@()close_system(mdl,0));saved=teach_snapshot(mdl);redraw([mdl '/限压']);assert(isequaln(saved,teach_snapshot(mdl)),'Wire redraw changed block logic or geometry');reload(get_param(mdl,'ModelWorkspace'));save_system(mdl,candidate);close_system(mdl,0);load_system(candidate);assert(isequaln(saved,teach_snapshot(mdl)));
 record.model_sha256=teach_hash(candidate);record.wire_geometry_only=true;teach_writejson(recordFile,record);exportLesson(mdl,folder);fprintf('READABLE_WIRE_REDRAW_PASS %s\n',record.model_sha256);return;
end
mdl='PMSM_FOC_R2026a';canonical=fullfile(root,[mdl '.slx']);expected='a0f7cbae9e7c334c25aa9dcf6e7e88d65fd89bd1888a0fa2ec0cd04f6cce262d';
assert(strcmp(teach_hash(canonical),expected));work=fullfile(root,'.build','readable_compensation');if ~isfolder(work),mkdir(work);end
candidate=fullfile(work,[mdl '.slx']);copyfile(canonical,candidate);copyfile(canonical,fullfile(work,'PMSM_FOC_before_readable.slx'));
load_system(candidate);guard=onCleanup(@()close_system(mdl,0));before=teach_snapshot(mdl);mw=get_param(mdl,'ModelWorkspace');code=mw.MATLABCode;settings=teach_settings(mdl);
fprintf('READABLE_BEFORE\n');if isfile(fullfile(work,'before_comp.mat')),cache=load(fullfile(work,'before_comp.mat'),'old');old=cache.old;else,old=run_deadtime_case(mdl,2,'on',.01);save(fullfile(work,'before_comp.mat'),'old','-v7.3');end
if isfile(fullfile(work,'before_off.mat')),cache=load(fullfile(work,'before_off.mat'),'off');off=cache.off;else,in=Simulink.SimulationInput(mdl);in=in.setModelParameter('StopTime','.003');off=sim(in);save(fullfile(work,'before_off.mat'),'off','-v7.3');end
reload(mw);parent=[mdl '/限压'];path=[parent '/死区补偿'];ph=get_param(path,'PortHandles');incoming=cell(1,numel(ph.Inport));outgoing=cell(1,numel(ph.Outport));
for k=1:numel(ph.Inport),l=get_param(ph.Inport(k),'Line');sp=get_param(l,'SrcPortHandle');incoming{k}={get_param(sp,'Parent'),get_param(sp,'PortNumber')};end
for k=1:numel(ph.Outport),l=get_param(ph.Outport(k),'Line');dp=get_param(l,'DstPortHandle');row={};for j=1:numel(dp),row(end+1,:)={get_param(dp(j),'Parent'),get_param(dp(j),'PortNumber')};end;outgoing{k}=row;end
for k=1:numel(ph.Outport),l=get_param(ph.Outport(k),'Line');if l>=0,delete_line(l);end,end
for k=1:numel(ph.Inport),a=get_param(incoming{k}{1},'PortHandles');delete_line(parent,a.Outport(incoming{k}{2}),ph.Inport(k));end
delete_block(path);add_block('built-in/SubSystem',path,'Position',[260 300 560 490],'BackgroundColor','lightBlue');
makeCompensation(path);
for k=1:numel(incoming),absoluteWire(parent,incoming{k}{1},incoming{k}{2},path,k);end
for k=1:numel(outgoing),row=outgoing{k};for j=1:size(row,1),absoluteWire(parent,path,k,row{j,1},row{j,2});end,end
tidyLimiter(parent);
mask=Simulink.Mask.get(parent);mask.Description=[mask.Description newline '死区补偿已展开为普通模块。双击内部“死区补偿”，从左到右阅读极性判断、电压修正、坐标变换。'];
set_param(mdl,'SimulationCommand','update');after=teach_snapshot(mdl);
assert(isequaln(before.regions,after.regions)&&strcmp(code,mw.MATLABCode)&&isequaln(settings,teach_settings(mdl)));
for b=before.blocks
 if startsWith(b.path,[path '/'])||strcmp(b.path,path),continue;end
 n=after.blocks(strcmp({after.blocks.sid},b.sid));assert(isscalar(n)&&strcmp(n.path,b.path)&&strcmp(n.type,b.type));
 assert(isequaln(n.params,b.params)&&isequaln(n.inputs,b.inputs),'Unexpected logic change %s',b.path);
 if ~startsWith(b.path,[parent '/']),assert(isequal(n.position,b.position));end
end
% Only one code chart is removed; all unrelated embedded algorithms remain.
oldScripts=before.scripts;oldScripts(strcmp(oldScripts(:,1),path),:)=[];assert(isequaln(oldScripts,after.scripts));
fprintf('READABLE_AFTER\n');actual=run_deadtime_case(mdl,2,'on',.01);record=struct('all_passed',false,'source_sha256',expected,'comp',compare(old,actual));clear old actual;
in=Simulink.SimulationInput(mdl);in=in.setModelParameter('StopTime','.003');actual=sim(in);record.off=compare(off,actual);clear off actual;
reload(mw);save_system(mdl,candidate);saved=teach_snapshot(mdl);close_system(mdl,0);load_system(candidate);fresh=teach_snapshot(mdl);teach_writejson(fullfile(work,'saved_snapshot.json'),saved);teach_writejson(fullfile(work,'reloaded_snapshot.json'),fresh);assert(isequaln(saved,fresh));
save(fullfile(work,'closed_loop_verified.mat'),'record');
record.component=checkComponent(path,folder,work);
record.pi_unchanged=true;record.root_geometry_preserved=true;record.regions_preserved=true;record.settings_preserved=true;record.saved_reload_preserved=true;
record.model_sha256=teach_hash(candidate);record.total_blocks=numel(saved.blocks);record.root_blocks=numel(find_system(mdl,'SearchDepth',1,'Type','Block'));
record.all_passed=true;record.publication_status='verified_candidate';teach_writejson(fullfile(folder,'readable_compensation_results.json'),record);
exportLesson(mdl,folder);
fprintf('READABLE_COMPENSATION_ALL_PASS %s\n',record.model_sha256);
end

function makeCompensation(p)
for k=1:4,labels={'电流','角度','母线','参数'};add(p,'simulink/Sources/In1',labels{k},[30 80+120*k 60 100+120*k],'Port',num2str(k));end
for k=1:2,labels={'dq补偿','诊断'};add(p,'simulink/Sinks/Out1',labels{k},[1510 160+260*(k-1) 1540 180+260*(k-1)],'Port',num2str(k));end
add(p,'simulink/Discrete/Zero-Order Hold','电流采样',[120 190 175 230],'SampleTime','timing_control_sample');wire(p,'电流',1,'电流采样',1);
add(p,'simulink/Math Operations/Reshape','三相向量',[220 190 280 230],'OutputDimensionality','Customize','OutputDimensions','[1 3]');wire(p,'电流采样',1,'三相向量',1);
add(p,'simulink/Discrete/Zero-Order Hold','角度采样',[120 310 175 350],'SampleTime','timing_control_sample');wire(p,'角度',1,'角度采样',1);
add(p,'simulink/Discrete/Zero-Order Hold','母线采样',[120 430 175 470],'SampleTime','timing_control_sample');wire(p,'母线',1,'母线采样',1);
add(p,'simulink/Signal Routing/Demux','参数分组',[130 530 135 650],'Outputs','4');wire(p,'参数',1,'参数分组',1);
sub(p,'极性判断',[350 150 540 270]);makePolarity([p '/极性判断']);
sub(p,'电压修正',[680 150 870 270]);makeVoltage([p '/电压修正']);
sub(p,'坐标变换',[1010 150 1200 270]);makeTransform([p '/坐标变换']);
wire(p,'三相向量',1,'极性判断',1);wire(p,'参数分组',1,'极性判断',2);wire(p,'参数分组',4,'极性判断',3);
wire(p,'极性判断',1,'电压修正',1);wire(p,'母线采样',1,'电压修正',2);wire(p,'参数分组',2,'电压修正',3);wire(p,'参数分组',3,'电压修正',4);
wire(p,'电压修正',1,'坐标变换',1);wire(p,'角度采样',1,'坐标变换',2);wire(p,'坐标变换',1,'dq补偿',1);
add(p,'simulink/Signal Routing/Mux','诊断合并',[1320 370 1325 510],'Inputs','3');
wire(p,'电压修正',1,'诊断合并',1);wire(p,'坐标变换',1,'诊断合并',2);wire(p,'极性判断',1,'诊断合并',3);
add(p,'simulink/Math Operations/Reshape','诊断向量',[1380 405 1450 445],'OutputDimensionality','Customize','OutputDimensions','[1 8]');wire(p,'诊断合并',1,'诊断向量',1);wire(p,'诊断向量',1,'诊断',1);
note(p,'按电流任务采样；与原MATLAB Function相同。补偿关闭时输出为0，极性记忆保持。',[30 25 1420 65]);
note(p,'参数依次：启用、补偿时间[s]、PWM周期[s]、电流滞环[A]。诊断依次：abc修正、dq修正、三相极性。',[240 570 1470 615]);
route(p);
end
function makePolarity(p)
port(p,{'电流','启用','滞环'},{'极性'});
add(p,'simulink/Logic and Bit Operations/Relational Operator','正阈值',[240 65 300 105],'Operator','>');
add(p,'simulink/Math Operations/Gain','负滞环',[120 290 175 325],'Gain','-1');wire(p,'滞环',1,'负滞环',1);
add(p,'simulink/Logic and Bit Operations/Relational Operator','负阈值',[240 200 300 240],'Operator','<');
wire(p,'电流',1,'正阈值',1);wire(p,'滞环',1,'正阈值',2);wire(p,'电流',1,'负阈值',1);wire(p,'负滞环',1,'负阈值',2);
add(p,'simulink/Sources/Constant','正极性',[340 10 405 40],'Value','[1 1 1]');add(p,'simulink/Sources/Constant','负极性',[500 160 565 190],'Value','[-1 -1 -1]');
add(p,'simulink/Discrete/Unit Delay','上次极性',[360 360 430 400],'SampleTime','timing_control_sample','InitialCondition','[0 0 0]');
add(p,'simulink/Signal Routing/Switch','正向切换',[440 55 490 125],'Criteria','u2 ~= 0');wire(p,'正极性',1,'正向切换',1);wire(p,'正阈值',1,'正向切换',2);wire(p,'上次极性',1,'正向切换',3);
add(p,'simulink/Signal Routing/Switch','负向切换',[600 190 650 260],'Criteria','u2 ~= 0');wire(p,'负极性',1,'负向切换',1);wire(p,'负阈值',1,'负向切换',2);wire(p,'正向切换',1,'负向切换',3);
add(p,'simulink/Signal Routing/Switch','记忆更新',[760 275 810 345],'Criteria','u2 ~= 0');wire(p,'负向切换',1,'记忆更新',1);wire(p,'启用',1,'记忆更新',2);wire(p,'上次极性',1,'记忆更新',3);wire(p,'记忆更新',1,'上次极性',1);
add(p,'simulink/Sources/Constant','关闭输出',[760 415 825 445],'Value','[0 0 0]');
add(p,'simulink/Signal Routing/Switch','输出选择',[920 175 970 245],'Criteria','u2 ~= 0');wire(p,'负向切换',1,'输出选择',1);wire(p,'启用',1,'输出选择',2);wire(p,'关闭输出',1,'输出选择',3);wire(p,'输出选择',1,'极性',1);
note(p,'i > +h → +1；i < -h → -1；带内保持。关闭补偿时输出0，记忆不更新；初始记忆0。',[30 480 1090 520]);route(p);
end
function makeVoltage(p)
port(p,{'极性','母线','补偿时间','PWM周期'},{'abc修正'});
add(p,'simulink/Discontinuities/Saturation','非负母线',[220 170 300 205],'LowerLimit','0','UpperLimit','inf');wire(p,'母线',1,'非负母线',1);
add(p,'simulink/Math Operations/Product','母线乘时间',[360 170 410 220]);wire(p,'非负母线',1,'母线乘时间',1);wire(p,'补偿时间',1,'母线乘时间',2);
add(p,'simulink/Math Operations/Product','补偿幅值',[480 170 535 220],'Inputs','*/');wire(p,'母线乘时间',1,'补偿幅值',1);wire(p,'PWM周期',1,'补偿幅值',2);
add(p,'simulink/Math Operations/Product','三相修正',[610 75 665 125]);wire(p,'补偿幅值',1,'三相修正',1);wire(p,'极性',1,'三相修正',2);
add(p,'simulink/Math Operations/Sum of Elements','三相求和',[720 260 790 300]);wire(p,'三相修正',1,'三相求和',1);
add(p,'simulink/Math Operations/Gain','三相均值',[850 260 920 300],'Gain','1/3');wire(p,'三相求和',1,'三相均值',1);
add(p,'simulink/Math Operations/Sum','去共模',[950 75 980 125],'Inputs','+-');wire(p,'三相修正',1,'去共模',1);wire(p,'三相均值',1,'去共模',2);wire(p,'去共模',1,'abc修正',1);
note(p,'幅值 = max(Vdc,0) × tcomp / Tpwm；每相乘极性，再减去三相均值。',[30 480 1090 520]);route(p);
end
function makeTransform(p)
port(p,{'abc修正','测量角度'},{'dq修正'});
add(p,'simulink/User-Defined Functions/Fcn','alpha',[200 65 390 100],'Expr','(2*u(1)-u(2)-u(3))/3');wire(p,'abc修正',1,'alpha',1);
add(p,'simulink/User-Defined Functions/Fcn','beta',[200 190 390 225],'Expr','(u(2)-u(3))/sqrt(3)');wire(p,'abc修正',1,'beta',1);
add(p,'simulink/Math Operations/Trigonometric Function','cos',[210 330 280 365],'Operator','cos');add(p,'simulink/Math Operations/Trigonometric Function','sin',[210 410 280 445],'Operator','sin');wire(p,'测量角度',1,'cos',1);wire(p,'测量角度',1,'sin',1);
for row={'alpha_cos','alpha','cos',500,65;'beta_sin','beta','sin',500,160;'alpha_sin','alpha','sin',680,295;'beta_cos','beta','cos',680,390}'
 add(p,'simulink/Math Operations/Product',row{1},[row{4} row{5} row{4}+55 row{5}+40]);wire(p,row{2},1,row{1},1);wire(p,row{3},1,row{1},2);
end
add(p,'simulink/Math Operations/Sum','d修正',[830 95 860 145],'Inputs','++');wire(p,'alpha_cos',1,'d修正',1);wire(p,'beta_sin',1,'d修正',2);
add(p,'simulink/Math Operations/Sum','q修正',[830 325 860 375],'Inputs','-+');wire(p,'alpha_sin',1,'q修正',1);wire(p,'beta_cos',1,'q修正',2);
add(p,'simulink/Signal Routing/Mux','dq合并',[920 140 925 330],'Inputs','2');wire(p,'d修正',1,'dq合并',1);wire(p,'q修正',1,'dq合并',2);
add(p,'simulink/Math Operations/Reshape','dq向量',[965 165 1020 205],'OutputDimensionality','Customize','OutputDimensions','[1 2]');wire(p,'dq合并',1,'dq向量',1);wire(p,'dq向量',1,'dq修正',1);
note(p,'沿用原幅值不变Clarke/Park约定。角度来自theta_meas，不使用电机真角度。',[30 480 1090 520]);route(p);
end
function port(p,ins,outs)
for k=1:numel(ins),add(p,'simulink/Sources/In1',ins{k},[30 80+100*(k-1) 60 100+100*(k-1)],'Port',num2str(k));end
for k=1:numel(outs),add(p,'simulink/Sinks/Out1',outs{k},[1090 180+100*(k-1) 1120 200+100*(k-1)],'Port',num2str(k));end
end
function tidyLimiter(p)
positions={ ...
'd',[20 60 130 85];'q',[20 150 130 175];'母线',[20 640 130 665];'母线采样',[170 630 225 670]; ...
'补偿电流',[20 340 150 365];'补偿角度',[20 410 150 435];'补偿参数',[20 480 150 515]; ...
'死区补偿',[260 310 520 530];'补偿分轴',[570 330 575 450];'补偿_d',[650 55 680 95];'补偿_q',[650 145 680 185]; ...
'输入',[770 60 775 240];'请求幅值',[850 60 1020 95];'幅值分母',[1050 305 1110 355]; ...
'母线裕量',[310 630 430 670];'可用电压',[500 630 600 670];'除零保护',[850 450 920 480];'电压分母',[1050 630 1110 680]; ...
'比例',[1170 305 1230 355];'比例限幅',[1290 305 1370 345];'输出_d',[1340 60 1390 100];'输出_q',[1340 150 1390 190]; ...
'标签_vd',[1450 60 1550 85];'标签_vq',[1450 150 1550 175];'残差_d',[1630 65 1660 95];'残差_q',[1630 155 1660 185]; ...
'标签_ObsResidual_d',[1730 60 1880 85];'标签_ObsResidual_q',[1730 150 1880 175]; ...
'最终幅值',[1290 480 1350 520];'请求利用率',[1460 480 1530 520];'最终利用率',[1460 590 1530 630]; ...
'饱和',[1460 700 1530 740];'标志数值',[1590 700 1670 735];'利用率',[1730 480 1735 620]; ...
'诊断',[1950 300 1955 700];'标签_ObsVoltage',[2020 360 2150 385];'记录_obs_voltage',[2020 440 2170 475]; ...
'标签_ObsVmax',[2020 600 2150 625];'标签_ObsSaturation',[2020 690 2150 715];'标签_ObsUtilization',[1830 540 1980 565]; ...
'd前馈幅值',[20 850 160 875];'d前馈符号',[230 845 300 880];'标签_ObsFFd',[370 850 500 875]; ...
'标签_ObsDeadComp',[650 530 800 555];'记录_obs_dead_comp',[850 525 1020 560]};
for k=1:size(positions,1),if getSimulinkBlockHandle([p '/' positions{k,1}])>=0,set_param([p '/' positions{k,1}],'Position',positions{k,2});end,end
note(p,'主线：原dq请求 + 死区补偿 → 圆限幅 → vd/vq；最终残差回原PI。',[20 5 1900 35]);
note(p,'双击“死区补偿”：极性判断 → 电压修正 → 坐标变换。算法与原版本相同。',[20 250 1030 280]);
note(p,'可用电压与比例计算',[310 590 1000 615]);note(p,'右侧为观测与记录；不参与补偿计算。',[1460 250 2170 280]);redraw(p);
end
function redraw(p)
% Discard stale bend points left by moving old blocks; preserve endpoints and
% root signal names/logging. No blocks, parameters or destinations change.
open_system(p,'force');set_param(bdroot(p),'SimulationCommand','update');
lines=find_system(p,'FindAll','on','LookUnderMasks','all','SearchDepth',1,'Type','line');meta={};
keys={'Name','DataLogging','DataLoggingNameMode','DataLoggingName','DataLoggingLimitDataPoints','DataLoggingMaxPoints','DataLoggingDecimateData','DataLoggingDecimation'};
for h=lines(:)'
 sp=get_param(h,'SrcPortHandle');if sp<0,continue;end
 props=get_param(h,'ObjectParameters');v=struct;for k=1:numel(keys),if isfield(props,keys{k}),v.(keys{k})=get_param(h,keys{k});end,end
 meta(end+1,:)={sp,v}; %#ok<AGROW>
end
blocks=find_system(p,'LookUnderMasks','all','SearchDepth',1,'Type','Block');edges={};
for k=1:numel(blocks)
 if strcmp(blocks{k},p),continue;end
 ph=get_param(blocks{k},'PortHandles');for dp=ph.Inport(:)'
  l=get_param(dp,'Line');if l>=0,sp=get_param(l,'SrcPortHandle');assert(sp>=0);edges(end+1,:)={sp,dp};end %#ok<AGROW>
 end
end
for k=1:size(meta,1),l=get_param(meta{k,1},'Line');if l>=0,delete_line(l);end,end
for k=1:size(edges,1),add_line(p,edges{k,1},edges{k,2},'autorouting','on');end
for k=1:size(meta,1)
 l=get_param(meta{k,1},'Line');v=meta{k,2};for key=fieldnames(v)',set_param(l,key{1},v.(key{1}));end
end
end
function exportLesson(mdl,folder)
parent=[mdl '/限压'];path=[parent '/死区补偿'];report=fullfile(folder,'lesson');
for row={parent,'limiter_readable';path,'compensation_readable';[path '/极性判断'],'polarity_readable';[path '/电压修正'],'voltage_readable';[path '/坐标变换'],'transform_readable'}'
 print(['-s' row{1}],'-dpng','-r140',fullfile(report,[row{2} '.png']));
end
end
function r=checkComponent(path,folder,work)
% Independent equivalence including off/on transitions and near-zero currents.
fixture='ReadableCompFixture';new_system(fixture);guard=onCleanup(@()close_system(fixture,0));set_param(fixture,'Solver','FixedStepDiscrete','FixedStep','1e-6','StopTime','.004');mw=get_param(fixture,'ModelWorkspace');assignin(mw,'timing_control_sample',[50e-6 25e-6]);
t=(0:1e-6:.004)';i=[.1*sin(2*pi*1400*t),.04*cos(2*pi*1700*t),.2*sin(2*pi*850*t)];theta=1300*t;bus=24*ones(size(t));bus(t>.002& t<.0025)=-1;
cfg=repmat([1 2e-6 50e-6 .05],numel(t),1);cfg(t>.001& t<.0017,1)=0;
data={i,theta,bus,cfg};vars={'i','theta','bus','cfg'};
add_block(path,[fixture '/可见补偿'],'Position',[300 40 500 220]);add_block('simulink/User-Defined Functions/MATLAB Function',[fixture '/原补偿'],'Position',[300 300 500 480]);rt=sfroot;c=rt.find('-isa','Stateflow.EMChart','Path',[fixture '/原补偿']);c.Script=fileread(fullfile(folder,'deadtime_comp.m'));c.ChartUpdate='DISCRETE';c.SampleTime='timing_control_sample';c.VectorOutputs1D=false;
outputs=c.find('-isa','Stateflow.Data','Scope','Output');for d=outputs(:)',sizes={'[1 2]','[1 8]'};d.Props.Array.Size=sizes{d.Port};end
for k=1:4
 assignin(mw,vars{k},timeseries(data{k},t));n=['输入' num2str(k)];add(fixture,'simulink/Sources/From Workspace',n,[20 30+70*k 160 60+70*k],'VariableName',vars{k},'Interpolate','off','OutputAfterFinalValue','Holding final value');wire(fixture,n,1,'可见补偿',k);wire(fixture,n,1,'原补偿',k);
end
for row={'可见补偿','new',1;'可见补偿','newdiag',2;'原补偿','old',1;'原补偿','olddiag',2}'
 add(fixture,'simulink/Sinks/To Workspace',row{2},[650 50+80*numel(find_system(fixture,'BlockType','ToWorkspace')) 800 90+80*numel(find_system(fixture,'BlockType','ToWorkspace'))],'VariableName',row{2},'SaveFormat','Timeseries','SampleTime','timing_control_sample');wire(fixture,row{1},row{3},row{2},1);
end
o=sim(fixture);assert(isequal(o.new.Time,o.old.Time));assert(max(abs(teach_values(o.new)-teach_values(o.old)),[],'all')<1e-12);assert(max(abs(teach_values(o.newdiag)-teach_values(o.olddiag)),[],'all')<1e-12);
r=struct('all_passed',true,'enable_freezes_state',true,'zero_crossing_hysteresis_equivalent',true,'negative_bus_clamp_equivalent',true);save(fullfile(work,'component.mat'),'o','-v7.3');
end
function r=compare(old,actual)
r=struct('timeseries',0,'max_abs_difference',0);for key=old.who',a=old.get(key{1});if ~isa(a,'timeseries'),continue;end;b=actual.get(key{1});assert(isequaln(a.Time,b.Time),'Times changed %s',key{1});d=max(abs(teach_values(a)-teach_values(b)),[],'all');assert(isfinite(d)&&d<1e-8,'Changed %s: %g',key{1},d);r.timeseries=r.timeseries+1;r.max_abs_difference=max(r.max_abs_difference,d);end
end
function sub(p,n,pos),add(p,'built-in/SubSystem',n,pos);end
function add(p,lib,n,pos,varargin),add_block(lib,[p '/' n],'Position',pos,varargin{:});end
function wire(p,s,sp,d,dp),absoluteWire(p,[p '/' s],sp,[p '/' d],dp);end
function absoluteWire(p,s,sp,d,dp),a=get_param(s,'PortHandles');b=get_param(d,'PortHandles');add_line(p,a.Outport(sp),b.Inport(dp),'autorouting','on');end
function note(p,s,pos),a=Simulink.Annotation(p,s);a.Position=pos;a.FontSize=12;a.ForegroundColor='darkBlue';end
function route(p),ls=find_system(p,'FindAll','on','LookUnderMasks','all','SearchDepth',1,'Type','line');for h=ls(:)',try,Simulink.BlockDiagram.routeLine(h);catch,end,end;end
