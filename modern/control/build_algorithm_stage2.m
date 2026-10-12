function build_algorithm_stage2
% Build a reviewable candidate only. Publication follows separate validation.
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);addpath(fullfile(root,'teaching'));
mdl='PMSM_FOC_R2026a';source=fullfile(root,[mdl '.slx']);
expected='6db333bfaf2d10822562c31a51ed8941ffd5ca421edaab858295af521885cc8b';
assert(strcmp(teach_hash(source),expected));assert(~bdIsLoaded(mdl));
work=fullfile(root,'.build','algorithm_stage');cached=load(fullfile(work,'before.mat'),'before');
candidate=fullfile(work,[mdl '.slx']);copyfile(source,candidate);
load_system(candidate);guard=onCleanup(@()close_system(mdl,0));
assert(isequaln(cached.before,teach_snapshot(mdl)));
mw=get_param(mdl,'ModelWorkspace');mw.MATLABCode=[mw.MATLABCode newline ...
 'decoupling_enabled=1; voltage_utilization=0.96; % Algorithm stage 2; PI gains frozen' newline];reload(mw);
settings=[mdl '/解耦'];add_block('built-in/SubSystem',settings,'Position',[1640 625 1755 655],'ShowName','off','BackgroundColor','white');
m=Simulink.Mask.create(settings);m.addParameter('Name','enabled','Type','checkbox','Prompt','dq解耦与反电动势前馈（运行前选择）','Value','on','Tunable','off');
m.Display='if enabled, disp(''解耦：开''); else, disp(''解耦：关''); end';
m.Description='开：vd_ff=-we*Lq*iq；vq_ff=we*(phis+Ld*id)。关：两个前馈均为零。最终限压与抗饱和始终启用。';
set_param(mdl,'InitFcn',[get_param(mdl,'InitFcn') newline ...
 'assignin(get_param(bdroot,''ModelWorkspace''),''decoupling_enabled'',double(strcmp(get_param([bdroot ''/解耦''],''enabled''),''on'')));']);
set_param(sid(mdl,'439'),'Kp','kp_id','Ki','ki_id','Ks','ks_id','uplimit','uplimit_id','downlimit','downlimit_id');
% Keep the original Ld*id product and its observation terminator.
add_block('simulink/Math Operations/Sum',[mdl '/磁链'],'Inputs','++','Position',[1400 445 1420 465],'ShowName','off');
wire(mdl,name(mdl,'212'),1,'磁链',1);wire(mdl,name(mdl,'214'),1,'磁链',2);
replaceInput(mdl,name(mdl,'213'),2,'磁链',1);
for row={'141','144',2,'d';'213','152',1,'q'}'
 gate=['解耦_' row{4}];pos=[1545 305 1585 335];if strcmp(row{4},'q'),pos=[1545 445 1585 475];end
 add_block('simulink/Math Operations/Gain',[mdl '/' gate],'Gain','decoupling_enabled','Position',pos,'ShowName','off');
 wire(mdl,name(mdl,row{1}),1,gate,1);replaceInput(mdl,name(mdl,row{2}),row{3},gate,1);
end
% The existing vd/vq tags become requests; final tags live inside the limiter.
set_param(sid(mdl,'220'),'GotoTag','vd_req');set_param(sid(mdl,'221'),'GotoTag','vq_req');
limit=[mdl '/限压'];add_block('built-in/SubSystem',limit,'Position',[1640 350 1755 395],'ShowName','off','BackgroundColor','white');
m=Simulink.Mask.create(limit);m.Display='disp(''限压'');';
m.Description='输入：PI轴限幅输出+前馈；方向保持的dq圆限幅，Vmax=0.96*max(Vbus,0)/sqrt(3)。输出vd/vq；最终残差Vfinal-Vrequest回到PI，和原轴限幅残差合并，仅回算一次。';
for row={'d','vd_req',1;'q','vq_req',2;'母线','UDC',3}'
 from(limit,row{1},row{2},[20 30+65*row{3} 120 50+65*row{3}]);
end
add_block('simulink/Signal Routing/Mux',[limit '/输入'],'Inputs','3','Position',[170 80 175 260]);
add_block('simulink/Discrete/Zero-Order Hold',[limit '/母线采样'],'SampleTime','dt','Position',[125 225 160 255]);wire(limit,'母线',1,'母线采样',1);
wire(limit,'d',1,'输入',1);wire(limit,'q',1,'输入',2);wire(limit,'母线采样',1,'输入',3);
fcn(limit,'请求幅值','sqrt(u(1)^2+u(2)^2)',[240 40 420 75]);wire(limit,'输入',1,'请求幅值',1);
add_block('simulink/Math Operations/Gain',[limit '/母线裕量'],'Gain','voltage_utilization/sqrt(3)','Position',[240 360 420 395]);wire(limit,'母线采样',1,'母线裕量',1);
add_block('simulink/Discontinuities/Saturation',[limit '/可用电压'],'LowerLimit','0','UpperLimit','inf','Position',[470 360 550 395]);wire(limit,'母线裕量',1,'可用电压',1);
add_block('simulink/Sources/Constant',[limit '/除零保护'],'Value','1e-12','Position',[240 450 320 480]);
for row={'幅值分母','请求幅值',100;'电压分母','可用电压',430}'
 add_block('simulink/Math Operations/MinMax',[limit '/' row{1}],'Function','max','Inputs','2','Position',[600 row{3} 650 row{3}+50]);
 wire(limit,row{2},1,row{1},1);wire(limit,'除零保护',1,row{1},2);
end
add_block('simulink/Math Operations/Product',[limit '/比例'],'Inputs','*/','Position',[700 350 760 400]);wire(limit,'可用电压',1,'比例',1);wire(limit,'幅值分母',1,'比例',2);
add_block('simulink/Discontinuities/Saturation',[limit '/比例限幅'],'LowerLimit','0','UpperLimit','1','Position',[800 350 880 390]);wire(limit,'比例',1,'比例限幅',1);
for k=1:2
 axes={'d','q'};ax=axes{k};n=['输出_' ax];add_block('simulink/Math Operations/Product',[limit '/' n],'Position',[470 40+100*k 510 80+100*k]);wire(limit,ax,1,n,1);wire(limit,'比例限幅',1,n,2);
 tap(limit,n,['v' ax],[560 40+100*k 680 65+100*k]);
 add_block('simulink/Math Operations/Sum',[limit '/残差_' ax],'Inputs','+-','Position',[730 45+100*k 750 75+100*k]);
 wire(limit,n,1,['残差_' ax],1);wire(limit,ax,1,['残差_' ax],2);
 tap(limit,['残差_' ax],['ObsResidual_' ax],[800 40+100*k 940 65+100*k]);
end
% Diagnostics: requested d/q, final d/q, Vmax, requested/final utilization, flag.
add_block('simulink/Signal Routing/Mux',[limit '/诊断'],'Inputs','8','Position',[1080 80 1085 440]);
wire(limit,'d',1,'诊断',1);wire(limit,'q',1,'诊断',2);wire(limit,'输出_d',1,'诊断',3);wire(limit,'输出_q',1,'诊断',4);
wire(limit,'可用电压',1,'诊断',5);
for row={'请求利用率','请求幅值',6;'最终利用率','最终幅值',7}'
 if strcmp(row{1},'最终利用率'),add_block('simulink/Math Operations/Product',[limit '/最终幅值'],'Position',[700 500 760 540]);wire(limit,'请求幅值',1,'最终幅值',1);wire(limit,'比例限幅',1,'最终幅值',2);end
 add_block('simulink/Math Operations/Product',[limit '/' row{1}],'Inputs','*/','Position',[800 450+70*(row{3}-6) 880 500+70*(row{3}-6)]);
 wire(limit,row{2},1,row{1},1);wire(limit,'电压分母',1,row{1},2);wire(limit,row{1},1,'诊断',row{3});
end
add_block('simulink/Logic and Bit Operations/Relational Operator',[limit '/饱和'],'Operator','>','Position',[800 620 880 660]);wire(limit,'请求幅值',1,'饱和',1);wire(limit,'可用电压',1,'饱和',2);
add_block('simulink/Signal Attributes/Data Type Conversion',[limit '/标志数值'],'OutDataTypeStr','double','Position',[930 620 1010 650]);wire(limit,'饱和',1,'标志数值',1);wire(limit,'标志数值',1,'诊断',8);
tap(limit,'诊断','ObsVoltage',[1140 180 1260 205]);logSignal(limit,'诊断','obs_voltage',[1140 250 1280 280]);
tap(limit,'可用电压','ObsVmax',[1140 400 1260 425]);tap(limit,'标志数值','ObsSaturation',[1140 460 1260 485]);
add_block('simulink/Signal Routing/Mux',[limit '/利用率'],'Inputs','2','Position',[1020 520 1025 600]);wire(limit,'请求利用率',1,'利用率',1);wire(limit,'最终利用率',1,'利用率',2);tap(limit,'利用率','ObsUtilization',[1140 550 1290 575]);
for row={'439','d';'453','q'}'
 path=getfullname(sid(mdl,row{1}));ax=row{2};
 from(path,'最终残差',['ObsResidual_' ax],[160 300 300 325]);
 set_param([path '/Sum'],'Inputs','+|--');wire(path,'最终残差',1,'Sum',3);
 add_block('simulink/Math Operations/Gain',[path '/回算修正'],'Gain','-1','Position',[550 300 600 330]);wire(path,'Gain',1,'回算修正',1);
 add_block('simulink/Signal Routing/Mux',[path '/回算观测'],'Inputs','2','Position',[650 300 655 370]);
 wire(path,'最终残差',1,'回算观测',1);wire(path,'回算修正',1,'回算观测',2);
 tap(path,'回算观测',['ObsAW_' ax],[730 320 880 345]);logSignal(path,'回算观测',['obs_aw_' ax],[730 380 880 410]);
 tap(path,'回算修正',['ObsCorrection_' ax],[930 320 1090 345]);
end
% SVPWM input follows the same bus signal as the plant and final limiter.
from(mdl,'调制母线','UDC',[90 1090 165 1110]);add_block('simulink/Discrete/Zero-Order Hold',[mdl '/母线采样'],'SampleTime','dt','Position',[175 1080 205 1120],'ShowName','off');wire(mdl,'调制母线',1,'母线采样',1);replaceInput(mdl,name(mdl,'240'),3,'母线采样',1);
add_block('simulink/Sinks/Terminator',[mdl '/母线常量保留'],'Position',[175 960 190 980],'ShowName','off');wire(mdl,name(mdl,'246'),1,'母线常量保留',1);
rt=sfroot;chart=rt.find('-isa','Stateflow.EMChart','Path',getfullname(sid(mdl,'240')));assert(isscalar(chart));chart.Script=fileread(fullfile(folder,'svpwm_checked.m'));
set_param(mdl,'SimulationCommand','update');
tap(mdl,name(mdl,'240'),'ObsMod',[350 1090 425 1110],3);
collector=getfullname(sid(mdl,'695'));from(collector,'调制状态','ObsMod',[850 340 960 360]);logSignal(collector,'调制状态','obs_mod',[1000 335 1150 365]);
% d sign is included in the observation: FFd=-we*Lq*iq.
add_block('simulink/Math Operations/Gain',[limit '/d前馈符号'],'Gain','-1','Position',[240 760 320 790]);from(limit,'d前馈幅值','ObsFFdMagnitude',[20 760 160 780]);wire(limit,'d前馈幅值',1,'d前馈符号',1);tap(limit,'d前馈符号','ObsFFd',[380 760 500 785]);
tap(mdl,'解耦_d','ObsFFdMagnitude',[1660 270 1785 290]);tap(mdl,'解耦_q','ObsFFq',[1660 445 1785 465]);
extendScope([mdl '/PI观测'],{'前馈 [V]','dq请求与输出 [V]','可用电压 [V]','利用率','饱和标志','最终残差 [V]','回算修正 [A]'}, ...
 {{'ObsFFd','ObsFFq'},{'vd_req','vq_req','vd','vq'},{'ObsVmax'},{'ObsUtilization'},{'ObsSaturation'},{'ObsResidual_d','ObsResidual_q'},{'ObsCorrection_d','ObsCorrection_q'}},[5 2]);
timing=[mdl '/时序观测'];from(timing,'调制状态','ObsMod',[1250 700 1390 720]);
add_block('simulink/Signal Routing/Demux',[timing '/调制分组'],'Outputs','[3 3 2]','Position',[1450 690 1455 820]);wire(timing,'调制状态',1,'调制分组',1);
for row={'矢量时间 [s]',1;'占空比',2;'调制边界标志',3}'
 add_block('simulink/Signal Routing/Goto',[timing '/标签_' num2str(row{2})],'GotoTag',['ObsModGroup' num2str(row{2})],'TagVisibility','local','Position',[1520 660+60*row{2} 1670 685+60*row{2}]);wire(timing,'调制分组',row{2},['标签_' num2str(row{2})],1);
end
extendScope(timing,{'矢量时间 [s]','占空比','调制边界标志'},{{'ObsModGroup1'},{'ObsModGroup2'},{'ObsModGroup3'}},[3 2]);
% Reset old geometry, including blocks whose port count changed.
for b=cached.before.blocks(:)',set_param(Simulink.ID.getHandle(b.sid),'Position',b.position);end
set_param(mdl,'SimulationCommand','update');after=teach_snapshot(mdl);
assert(isequaln(cached.before.regions,after.regions));
for b=cached.before.blocks(:)'
 n=after.blocks(strcmp({after.blocks.sid},b.sid));assert(isscalar(n)&&strcmp(b.path,n.path)&&strcmp(b.type,n.type)&&isequal(b.position,n.position));
end
save_system(mdl,candidate);save(fullfile(work,'built.mat'),'after');
fprintf('ALGORITHM_CANDIDATE_BUILT %s\n',teach_hash(candidate));
end

function extendScope(path,names,tags,layout)
scope=[path '/总览'];old=str2double(get_param(scope,'NumInputPorts'));set_param(scope,'NumInputPorts',num2str(old+numel(names)));
c=get_param(scope,'ScopeConfiguration');c.LayoutDimensions=layout;
for k=1:numel(names)
 n=names{k};add_block('simulink/Signal Routing/Mux',[path '/' n],'Inputs',num2str(numel(tags{k})),'Position',[1450 50+110*k 1455 120+110*k]);
 for j=1:numel(tags{k}),s=sprintf('%s_%d',n,j);from(path,s,tags{k}{j},[1250 50+110*k+25*j 1380 70+110*k+25*j]);wire(path,s,1,n,j);end
 wire(path,n,1,'总览',old+k);c.ActiveDisplay=num2str(old+k);c.Title=n;c.ShowLegend=true;
end
end
function fcn(p,n,expr,pos),add_block('simulink/User-Defined Functions/Fcn',[p '/' n],'Expr',expr,'Position',pos);end
function from(p,n,tag,pos),add_block('simulink/Signal Routing/From',[p '/' n],'GotoTag',tag,'Position',pos,'ShowName','off');end
function tap(p,n,tag,pos,port)
if nargin<5,port=1;end
g=['标签_' tag];add_block('simulink/Signal Routing/Goto',[p '/' g],'GotoTag',tag,'TagVisibility','global','Position',pos,'ShowName','off');wire(p,n,port,g,1);
end
function logSignal(p,n,var,pos),add_block('simulink/Sinks/To Workspace',[p '/记录_' var],'VariableName',var,'SaveFormat','Timeseries','SampleTime','dt','MaxDataPoints','inf','Position',pos);wire(p,n,1,['记录_' var],1);end
function wire(p,s,sp,d,dp),a=get_param([p '/' s],'PortHandles');b=get_param([p '/' d],'PortHandles');add_line(p,a.Outport(sp),b.Inport(dp),'autorouting','on');end
function replaceInput(p,d,dp,s,sp),h=get_param([p '/' d],'PortHandles');delete_line(get_param(h.Inport(dp),'Line'));wire(p,s,sp,d,dp);end
function h=sid(m,id),h=Simulink.ID.getHandle([m ':' id]);end
function n=name(m,id),n=get_param(sid(m,id),'Name');end
