function [fig,view]=pmsm_frequency_time_view(pack,frequency,openBode)
% Shared native presentation; callers verify archive and choose axis data.
p=pack.plan;
if ~isfield(pack,'title'),pack.title='电流环时域响应';end
validateattributes(frequency,{'double'},{'scalar','real','finite','positive'});
[distance,k]=min(abs(p.frequency_Hz-frequency));
assert(distance<max(1e-8,frequency*1e-9),'请选择档案已有实际频点；图窗频点菜单列出所有可选值。');
fig=figure('Name',pack.title,'NumberTitle','off','Color','white','Units','pixels','Position',[80 60 1120 800]);
setappdata(fig,'CurrentFrequencyTimePack',pack);
menu=uimenu(fig,'Text','频点');items=gobjects(size(p.frequency_Hz));
for n=1:numel(items)
 items(n)=uimenu(menu,'Text',sprintf('%g Hz',p.frequency_Hz(n)),...
  'MenuSelectedFcn',@(~,~)render(fig,n),'UserData',n);
end
setappdata(fig,'CurrentFrequencyTimeMenus',items);
uimenu(fig,'Text','频率响应','MenuSelectedFcn',@(~,~)openBode());
render(fig,k);view=fig.UserData;
end
function render(fig,k)
pack=getappdata(fig,'CurrentFrequencyTimePack');p=pack.plan;seg=p.segments(k);
periods=3;lo=seg.end_tick-periods*p.samples_per_period(k);assert(lo>=seg.measure_tick);
ix=find(pack.cases(1).ticks>=lo&pack.cases(1).ticks<seg.end_tick);
assert(numel(ix)==periods*p.samples_per_period(k));
t=pack.cases(1).time_s(ix)*1e3;
old=getappdata(fig,'CurrentFrequencyTimeLayout');
if ~isempty(old)&&isgraphics(old),delete(old);end
layout=tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');setappdata(fig,'CurrentFrequencyTimeLayout',layout);
blue=[0 .447 .741];red=[.84 .15 .16];gray=[.5 .5 .5];colors=[blue;red];
topics={'真实电流','反馈电流','PI误差','反馈−真实'};tags={'true','feedback','error','difference'};axesList=gobjects(1,4);
mechanical=isfield(pack,'mechanical_view')&&pack.mechanical_view;
if mechanical,topics={'q轴电流','电磁转矩','机械转速','机械加速度'};tags={'q_current','torque','speed','acceleration'};end
units={'电流 [A]','电流 [A]','电流 [A]','电流 [A]'};
if mechanical,units={'电流 [A]','转矩 [N·m]','转速 [rad/s]','加速度 [rad/s²]'};end
for panel=1:4
 ax=nexttile(layout,panel);axesList(panel)=ax;ax.Tag=tags{panel};hold(ax,'on');
 if (~mechanical&&panel<=2)||(mechanical&&panel==1),stairs(ax,t,pack.cases(1).reference_A(ix),'--','Color',gray,'LineWidth',1.2,'DisplayName','给定','Tag','reference');end
 if mechanical&&panel==4,plot(ax,t,pack.cases(1).locked_accel_rad_s2(ix),'--','Color',gray,'LineWidth',1.2,'DisplayName','锁轴实际','Tag','locked_acceleration');end
 for c=1:2
  d=pack.cases(c);
  label=d.label;
  if mechanical
   switch panel
    case 1,y=d.true_A(ix);
    case 2,y=d.torque_Nm(ix);
    case 3,y=d.speed_rad_s(ix);
    case 4,y=d.free_accel_rad_s2(ix);label=['未约束：' d.label];
   end
  else
  switch panel
   case 1,y=d.true_A(ix);
   case 2,y=d.feedback_A(ix);
   case 3,y=d.error_A(ix);
   case 4,y=d.feedback_A(ix)-d.true_A(ix);
  end
  end
  line=plot(ax,t,y,'Color',colors(c,:),'LineWidth',1.4,'DisplayName',label,'Tag',[tags{panel} '_' d.id]);
  if numel(ix)<=100,line.Marker='.';line.MarkerSize=7;end
 end
 ax.Color='white';ax.XColor='black';ax.YColor='black';ax.FontSize=11;
 grid(ax,'on');title(ax,topics{panel});xlabel(ax,'时间 [ms]');ylabel(ax,units{panel});
 legend(ax,'show','Location','best');xlim(ax,[t(1) t(end)]);
end
linkaxes(axesList,'x');setappdata(fig,'CurrentFrequencyTimeAxes',axesList);
set(fig,'Name',sprintf('%s · %g Hz',pack.title,seg.frequency_Hz),...
 'UserData',struct('source_folder',pack.folder,'source_record_sha256',pack.record_sha256,...
 'scope',pack.scope,'frequency_Hz',seg.frequency_Hz,'sample_time_s',p.sample_time_s,...
 'amplitude_A',pack.amplitude_A,'sample_count',numel(ix),'source_indices',ix,...
 'tick_window_end_exclusive',[lo seg.end_tick],'actual_window_s',t([1 end])/1e3,...
 'signal_identity','PI error=reference-feedback; difference=feedback-true',...
 'data_policy','Original samples at original times; no interpolation, rephasing, normalization or new run.'));
items=getappdata(fig,'CurrentFrequencyTimeMenus');set(items,'Checked','off');items(k).Checked='on';
fig.UserData.view_kind='current';
if mechanical
 fig.UserData.view_kind='mechanics';
 fig.UserData.signal_identity='Original Te and constrained rotor speed; unconstrained acceleration evaluated on locked trajectory, not a separate free-rotor run.';
end
end
