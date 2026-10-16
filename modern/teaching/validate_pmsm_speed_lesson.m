function report=validate_pmsm_speed_lesson
here=fileparts(mfilename('fullpath'));root=fileparts(here);addpath(root,fullfile(root,'layout','appearance'));
m='PMSM_FOC_R2026a';assert(~bdIsLoaded(m));load_system(fullfile(root,[m '.slx']));guard=onCleanup(@()close_system(m,0));
mw=get_param(m,'ModelWorkspace');assignin(mw,'n',1234);before=teach_snapshot(m);cfg=pmsm_config('read');hash=teach_hash(fullfile(root,[m '.slx']));
step=pmsm_speed_step_folder;probe=pmsm_speed_probe_folder;
archiveHashes={teach_hash(fullfile(step,'record.json')),teach_hash(fullfile(probe,'record.json'))};
panel=open_pmsm_speed_lesson;
b=findall(panel,'Tag','speed_lesson_current');b.ButtonPushedFcn(b,[]);assert(pmsm_native_scope('installed'));
d=pmsm_native_scope('install');c=get_param(d.path,'ScopeConfiguration');assert(isequal(c.LayoutDimensions,[2 2]));pmsm_native_scope('remove');
assert(isequaln(before,teach_snapshot(m))&&getVariable(mw,'n')==1234);
b=findall(panel,'Tag','speed_lesson_step');b.ButtonPushedFcn(b,[]);
f=findall(groot,'Type','figure','Name','速度环阶跃基线');assert(isscalar(f));s=load(fullfile(step,'step_1_raw.mat'),'raw');checkTraces(f,s.raw);
folder=fullfile(here,'speed_lesson');if ~isfolder(folder),mkdir(folder);end
exportgraphics(f,fullfile(folder,'step.png'),'Resolution',140);delete(f);
b=findall(panel,'Tag','speed_lesson_sine');b.ButtonPushedFcn(b,[]);
f=findall(groot,'Type','figure','Name','速度环正弦响应');assert(isscalar(f));
a=load(fullfile(probe,'analysis.mat'),'p');s=load(fullfile(probe,'probe_1_raw.mat'),'raw');p=a.p;assert(p.frequency_Hz(2)==80);
seg=p.segments(2);tick=round(s.raw.speed_ref.Time/p.sample_time_s);ix=tick>=seg.end_tick-3*p.samples_per_period(2)&tick<seg.end_tick;
raw=s.raw;for key=fieldnames(raw)',ts=raw.(key{1});v=teach_values(ts);raw.(key{1})=timeseries(v(ix,:),ts.Time(ix));end
checkTraces(f,raw);exportgraphics(f,fullfile(folder,'sine.png'),'Resolution',140);delete(f);
exportapp(panel,fullfile(root,'.build','speed_lesson_ui.png'));delete(panel);
assert(~pmsm_native_scope('installed')&&isequaln(before,teach_snapshot(m))&&isequaln(cfg,pmsm_config('read')));
assert(strcmp(hash,teach_hash(fullfile(root,[m '.slx']))));
assert(isequal(archiveHashes,{teach_hash(fullfile(step,'record.json')),teach_hash(fullfile(probe,'record.json'))}));
report=struct('passed',true,'archive_trace_count',16,'current_scope_reused',true,'callbacks_checked',3,...
 'time_zoom_linked',true,'current_configuration_preserved',true,'model_sha256',hash,'source_folders',{{step,probe}},'archive_record_sha256',{archiveHashes});
teach_writejson(fullfile(folder,'validation.json'),report);disp('SPEED_LESSON_VALIDATED');
end
function checkTraces(f,raw)
state=teach_values(raw.obs_state);t=raw.speed_ref.Time*1000;
names={'转速','q轴电流','转矩','速度误差'};
expected={{teach_values(raw.speed_ref),state(:,3)*30/pi,teach_values(raw.speed_feedback)},...
 {teach_values(raw.speed_iq_ref),state(:,2)}, {teach_values(raw.speed_torque),zeros(size(t))},{teach_values(raw.speed_error)}};
axesList=findall(f,'Type','axes');assert(numel(axesList)==4);
for k=1:4
 ax=axesList(arrayfun(@(a)strcmp(a.Title.String,names{k}),axesList));assert(isscalar(ax));lines=findall(ax,'Type','line');assert(numel(lines)==numel(expected{k}));
 for j=1:numel(expected{k}),match=arrayfun(@(ln)isequal(ln.XData(:),t)&&isequal(ln.YData(:),expected{k}{j}),lines);assert(any(match));end
end
axesList(1).XLim=[t(1) t(1)+(t(end)-t(1))/2];drawnow;
for k=2:4,assert(isequal(axesList(k).XLim,axesList(1).XLim));end
axesList(1).XLim=[t(1) t(end)];
end
