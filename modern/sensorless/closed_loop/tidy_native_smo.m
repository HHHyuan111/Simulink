function report=tidy_native_smo(mdl,reference)
% Presentation repair. Existing equations, state delays and interfaces remain.
p=[mdl '/无感观测/滑模观测'];
if nargin<2,before=teach_snapshot(mdl);else,before=reference;end
assert(strcmp(get_param(mdl,'SimulationStatus'),'stopped'));
assert(getSimulinkBlockHandle([p '/电流状态'])>0);
added={};aliases=cell(0,2);

% Short, local channels keep the six regions independent on this flat page.
tagMap={'SMO_prediction','SMO_i_pred';'SMO_measured','SMO_i_meas';...
 'SMO_corrected_residual','SMO_r';'SMO_corrected_injection','SMO_z';...
 'SMO_injection_previous','SMO_z_prev';'SMO_sample_valid','SMO_valid';'SMO_reset','SMO_rst'};
for type={'From','Goto'}
 blocks=find_system(p,'SearchDepth',1,'BlockType',type{1});
 for k=1:numel(blocks)
  tag=get_param(blocks{k},'GotoTag');j=find(strcmp(tagMap(:,1),tag),1);
  if ~isempty(j),set_param(blocks{k},'GotoTag',tagMap{j,2});end
 end
end
route('注入用残差','SMO_r','残差归一化',1,'分段残差');
route('预测用历史注入','SMO_z_prev','历史注入 b',1,'注入状态');
zero('残差无效清零','样本残差选择',3);
zero('残差复位清零','残差复位',1);
zero('注入复位清零','注入复位',1);

rows={...
 '本拍电流反馈',[40 90 200 110];'电流状态',[240 80 290 120];...
 '电流递推 a',[340 80 395 120];'区间电压',[40 200 230 220];...
 '电压递推 b',[340 190 395 230];'电流预测',[460 130 490 160];...
 '发布_SMO_prediction',[550 135 710 155];...
 '测量电流',[40 275 200 295];'发布_SMO_measured',[245 275 395 295];...
 '样本有效',[485 275 675 295];'发布_SMO_sample_valid',[725 275 890 295];...
 '复位',[40 330 200 350];'发布_SMO_reset',[245 330 395 350];...
 '预测值',[40 465 185 485];'校正用电流',[40 535 185 555];...
 '预测偏差',[235 490 265 520];'发布_SMO_delta',[305 495 425 515];...
 '线性偏差',[455 450 580 470];'隐式分母',[455 515 650 540];...
 '线性残差',[690 445 755 485];...
 '判定偏差',[455 570 580 590];'偏差绝对值',[610 565 655 595];...
 '隐式分段阈值',[455 630 680 655];'处于边界层',[710 565 760 605];...
 '饱和偏差',[40 685 165 705];'偏差符号',[205 675 250 710];...
 '饱和校正 bK',[290 675 360 715];'饱和解输入',[205 755 350 775];...
 '饱和区残差',[410 680 440 710];'分段残差',[845 535 895 595];...
 '发布_SMO_corrected_residual',[930 545 1050 565];...
 '注入用残差',[40 930 180 950];'边界层电流',[40 1000 225 1025];...
 '残差归一化',[390 920 455 960];'边界层饱和',[525 920 575 960];...
 '滑模增益 K',[645 920 700 960];'发布_SMO_corrected_injection',[765 930 925 950];...
 '有效校正电流',[1180 110 1315 130];'有效校正残差',[1180 175 1315 195];...
 '有效电流估计',[1370 130 1400 160];'无效样本预测',[1180 265 1325 285];...
 '预测用历史注入',[1180 335 1325 355];'历史注入 b',[1380 325 1445 365];...
 '纯模型电流估计',[1490 270 1520 300];'电流更新许可',[1390 215 1535 235];...
 '样本电流选择',[1580 130 1630 190];'零矢量',[1670 65 1730 95];...
 '电流复位许可',[1655 110 1790 130];'电流复位',[1830 130 1880 190];...
 '输出_SLessV2_i_hat',[1930 150 2120 170];...
 '残差更新值',[1180 490 1315 510];'残差更新许可',[1180 555 1315 575];...
 '残差无效清零',[1180 620 1240 650];'样本残差选择',[1490 480 1540 540];...
 '残差复位清零',[1670 425 1730 455];'残差复位许可',[1655 465 1790 485];...
 '残差复位',[1830 480 1880 540];'输出_SLessV2_residual',[1930 500 2120 520];...
 '注入更新值',[1180 810 1315 830];'注入更新许可',[1180 875 1315 895];...
 '历史注入保持',[1180 940 1340 960];'样本注入选择',[1490 800 1540 860];...
 '注入复位清零',[1670 745 1730 775];'注入复位许可',[1655 785 1790 805];...
 '注入复位',[1830 800 1880 860];'输出_SLessV2_injection',[1930 820 2120 840];...
 '本拍注入反馈',[1180 1020 1400 1040];'注入状态',[1490 1010 1540 1050];...
 '发布_SMO_injection_previous',[1600 1020 1780 1040]};
for k=1:size(rows,1),set_param([p '/' rows{k,1}],'Position',rows{k,2});end
notes=find_system(p,'FindAll','on','SearchDepth',1,'Type','annotation');
for h=notes(:)',delete(get_param(h,'Object'));end
area(p,'1  电流预测与输入',[20 20 1090 375],'[0.94 0.97 0.99]');
area(p,'2  隐式残差校正',[20 390 1090 825],'[0.97 0.97 0.97]');
area(p,'3  滑模注入',[20 855 1090 1085],'[0.94 0.97 0.99]');
area(p,'4  电流估计更新',[1150 20 2160 385],'[0.95 0.98 0.95]');
area(p,'5  残差输出',[1150 405 2160 700],'[0.97 0.97 0.97]');
area(p,'6  注入更新与历史状态',[1150 725 2160 1085],'[0.95 0.98 0.95]');
reroute(p);
turn('电流递推 a','电流预测',1,430);turn('电压递推 b','电流预测',2,445);
turn('线性偏差','线性残差',1,665);turn('隐式分母','线性残差',2,675);
turn('线性残差','分段残差',1,800);turn('处于边界层','分段残差',2,820);
turn('饱和区残差','分段残差',3,835);turn('隐式分段阈值','处于边界层',2,690);
turn('饱和校正 bK','饱和区残差',2,385);turn('饱和解输入','饱和区残差',1,395);
turn('边界层电流','残差归一化',2,370);
turn('历史注入 b','纯模型电流估计',2,1470);
turn('电流更新许可','样本电流选择',2,1545);turn('纯模型电流估计','样本电流选择',3,1565);
turn('零矢量','电流复位',1,1820);turn('电流复位许可','电流复位',2,1800);
turn('样本电流选择','电流复位',3,1740);
turn('残差更新许可','样本残差选择',2,1430);turn('残差无效清零','样本残差选择',3,1460);
turn('残差复位清零','残差复位',1,1820);turn('残差复位许可','残差复位',2,1800);
turn('样本残差选择','残差复位',3,1740);
turn('注入更新许可','样本注入选择',2,1430);turn('历史注入保持','样本注入选择',3,1460);
turn('注入复位清零','注入复位',1,1820);turn('注入复位许可','注入复位',2,1800);
turn('样本注入选择','注入复位',3,1740);
for n={'零矢量','残差无效清零','残差复位清零','注入复位清零'}
 set_param([p '/' n{1}],'ShowName','off');
end

% The observer page keeps its existing algorithms and only gains a grid.
o=[mdl '/无感观测'];
names={'采样输入','区间电压','滑模观测','反电动势','锁相环','有效判断','执行许可','发布许可','观测'};
for k=1:numel(names)
 col=mod(k-1,3);row=floor((k-1)/3);
 set_param([o '/' names{k}],'Position',[430+260*col 65+125*row 630+260*col 135+125*row],...
  'ContentPreviewEnabled','off');
end
constants={'参数','方向','启用','适配参数'};
for k=1:numel(constants)
 b=[o '/' constants{k}];set_param(b,'Position',[35 70+75*(k-1) 155 100+75*(k-1)]);
 ph=get_param(b,'PortHandles');ln=get_param(ph.Outport,'Line');dst=get_param(ln,'DstPortHandle');
 if ~isempty(dst)&&dst(1)>0,set_param(get_param(dst(1),'Parent'),'Position',[205 70+75*(k-1) 385 100+75*(k-1)],'ShowName','off');end
end
vis=sort(find_system(o,'LookUnderMasks','all','SearchDepth',1,'BlockType','GotoTagVisibility'));
assert(~isempty(vis),'Expected the existing observer visibility declarations.');
for k=1:numel(vis)
 col=mod(k-1,5);row=floor((k-1)/5);
 set_param(vis{k},'Position',[35+240*col 515+45*row 255+240*col 540+45*row],'ShowName','off');
end
for k=1:2
 n={'观测数据','观测许可'};y=400+45*(k-1);
 set_param([o '/导出_' n{k}],'Position',[770 y 1000 y+25],'ShowName','off');
 set_param([o '/' n{k}],'Position',[1080 y+2 1110 y+22]);
end
reroute(o);

% Keep the original nine FOC panels intact; move only the added closed loop.
set_param([mdl '/无感观测'],'Position',[160 2150 370 2330],'ContentPreviewEnabled','off');
set_param([mdl '/闭环控制'],'Position',[620 2050 840 2510],'ContentPreviewEnabled','off');
set_param([mdl '/闭环结果观测'],'Position',[1780 2190 2040 2330],'ContentPreviewEnabled','off');
ph=get_param([mdl '/闭环控制'],'PortHandles');
request=[mdl '/无感转速目标'];
g=find_system(mdl,'SearchDepth',1,'BlockType','Goto','GotoTag','nref');assert(numel(g)==1);
gp=get_param(g{1},'PortHandles');gs=get_param(get_param(gp.Inport,'Line'),'SrcPortHandle');
assert(strcmp(get_param(gs,'Parent'),[mdl '/speed_ref']));
if getSimulinkBlockHandle(request)<0
 ln=get_param(ph.Inport(3),'Line');delete_line(ln);
 add_block('simulink/Signal Routing/From',request,'GotoTag','nref','ShowName','off',...
  'Position',[390 2390 545 2415],'FontName','Microsoft YaHei','FontSize','10');
 add_line(mdl,'无感转速目标/1','闭环控制/3','autorouting','on');
end
added{end+1}=request;aliases(end+1,:)={request,{[mdl '/speed_ref'],1}};
keys={'theta_sample','theta_pwm','speed','omega','id_ref','iq_ref','reference','stage','blend','age','pi'};
for k=1:numel(keys)
 pos=get_param(ph.Outport(k),'Position');y=pos(2);
 set_param([mdl '/发布_CL_' keys{k}],'Position',[960 y-11 1130 y+11],'ShowName','off');
 set_param([mdl '/闭环可见域_' keys{k}],'Position',[1170 y-11 1370 y+11],'ShowName','off');
end
pos=get_param(ph.Outport(end),'Position');
set_param([mdl '/发布速度PI观测'],'Position',[960 pos(2)+45 1160 pos(2)+70],'ShowName','off');
set_param([mdl '/无感q电流给定'],'Position',[240 145 410 175],'ShowName','off');
set_param([mdl '/无感转矩换算'],'Position',[475 140 530 180]);
% The old speed-error wire has no consumer after the accepted PI replacement.
ph=get_param([mdl '/Sum4'],'PortHandles');ln=get_param(ph.Outport,'Line');
if ln>0&&all(get_param(ln,'DstPortHandle')<0),delete_line(ln);end
area(mdl,'10  无感闭环接入',[50 1980 1470 2640],'[0.90 0.95 0.93]');
area(mdl,'11  闭环结果',[1510 1980 2710 2640],'[0.90 0.94 0.98]');
moved={'无感观测','闭环控制','无感转速目标','无感q电流给定','无感转矩换算','speed_ref'};
rootLines=[];
for k=1:numel(moved)
 phm=get_param([mdl '/' moved{k}],'PortHandles');
 for h=[phm.Inport phm.Outport]
  ln=get_param(h,'Line');if ln<0,continue;end
  while get_param(ln,'LineParent')~=-1,ln=get_param(ln,'LineParent');end
  rootLines(end+1)=ln;
 end
end
for ln=unique(rootLines),rebuild(mdl,ln);end
for sys={p,o,mdl},set_param(sys{1},'ZoomFactor','FitSystem');end
after=teach_snapshot(mdl);
a=normalize(before);b=normalize(after);
report=struct('passed',isequaln(a,b),'equations_states_parameters_scripts_and_resolved_inputs_equal',isequaln(a,b),...
 'added_routing_and_zero_sources',{added},'new_subsystems',0,'new_masks',0,'physical_simulation_repeated',false);
assert(report.passed,'Layout repair changed model behavior.');

 function s=normalize(s)
  s.blocks=s.blocks(~ismember({s.blocks.path},added));s.regions=[];
  for j=1:numel(s.blocks)
   s.blocks(j).position=[];
   if isfield(s.blocks(j).params,'GotoTag')
    q=find(strcmp(tagMap(:,2),s.blocks(j).params.GotoTag),1);
    if ~isempty(q),s.blocks(j).params.GotoTag=tagMap{q,1};end
   end
   for n=1:numel(s.blocks(j).inputs)
    v=s.blocks(j).inputs{n};if isempty(v),continue;end
    q=find(strcmp(aliases(:,1),v{1}),1);if ~isempty(q),s.blocks(j).inputs{n}=aliases{q,2};end
   end
  end
 end
 function route(name,tag,target,port,source)
  b=[p '/' name];
  if getSimulinkBlockHandle(b)<0
   add_block('simulink/Signal Routing/From',b,'GotoTag',tag,'ShowName','off',...
    'FontName','Microsoft YaHei','FontSize','10');
   ph=get_param([p '/' target],'PortHandles');delete_line(get_param(ph.Inport(port),'Line'));
   add_line(p,[name '/1'],[target '/' num2str(port)]);
  end
  assert(strcmp(get_param(b,'GotoTag'),tag));
  g=find_system(p,'LookUnderMasks','all','SearchDepth',1,'BlockType','Goto','GotoTag',tag);
  assert(numel(g)==1);gp=get_param(g{1},'PortHandles');
  gs=get_param(get_param(gp.Inport,'Line'),'SrcPortHandle');
  assert(strcmp(get_param(gs,'Parent'),[p '/' source])&&get_param(gs,'PortNumber')==1);
  added{end+1}=b;aliases(end+1,:)={b,{[p '/' source],1}};
 end
 function zero(name,target,port)
  b=[p '/' name];
  if getSimulinkBlockHandle(b)<0
   add_block('simulink/Sources/Constant',b,'Value','[0;0]','VectorParams1D','off',...
    'FontName','Microsoft YaHei','FontSize','10');
   ph=get_param([p '/' target],'PortHandles');delete_line(get_param(ph.Inport(port),'Line'));
   add_line(p,[name '/1'],[target '/' num2str(port)]);
  end
  assert(strcmp(get_param(b,'Value'),'[0;0]')&&strcmp(get_param(b,'VectorParams1D'),'off'));
  added{end+1}=b;aliases(end+1,:)={b,{[p '/零矢量'],1}};
 end
 function turn(source,target,port,x)
  sp=get_param([p '/' source],'PortHandles');tp=get_param([p '/' target],'PortHandles');
  assert(get_param(get_param(tp.Inport(port),'Line'),'SrcPortHandle')==sp.Outport,...
   'Routing must follow the actual connected source.');
  a=get_param(sp.Outport,'Position');b=get_param(tp.Inport(port),'Position');
  pts=[a;x a(2);x b(2);b];pts=pts([true;any(diff(pts),2)],:);
  set_param(get_param(tp.Inport(port),'Line'),'Points',pts);
 end
end

function area(p,name,pos,color)
h=find_system(p,'LookUnderMasks','all','FindAll','on','SearchDepth',1,'Type','annotation','Name',name);
if isempty(h),h=add_block('built-in/Area',[p '/' name]);end
assert(numel(h)==1);a=get_param(h,'Object');
a.FontName='Microsoft YaHei';a.FontSize=14;a.FontWeight='bold';
a.ForegroundColor=color;a.BackgroundColor=color;a.DropShadow='off';
a.FixedWidth='on';a.FixedHeight='on';a.Position=pos;a.Tag='SMOPresentationArea';
end
function reroute(p)
lines=find_system(p,'LookUnderMasks','all','FindAll','on','SearchDepth',1,'Type','line');
roots=lines(arrayfun(@(h)get_param(h,'LineParent')==-1,lines));
for h=roots(:)',rebuild(p,h);end
end
function rebuild(p,h)
src=get_param(h,'SrcPortHandle');dst=get_param(h,'DstPortHandle');
if src<0||isempty(dst)||any(dst<0),return;end
name=get_param(h,'Name');delete_line(h);
for d=dst(:)',add_line(p,src,d,'autorouting','on');end
if ~isempty(name),set_param(get_param(src,'Line'),'Name',name);end
end
