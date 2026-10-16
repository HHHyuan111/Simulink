function report=validate_pmsm_deadtime_effects_scope
here=fileparts(mfilename('fullpath'));root=fileparts(fileparts(here));addpath(root,here,fullfile(root,'teaching'));
m='PMSM_FOC_R2026a';assert(~bdIsLoaded(m));source=fullfile(root,[m '.slx']);hash=teach_hash(source);
load_system(source);closer=onCleanup(@()close_system(m,0));pmsm_reference('restore');
original=cell(1,2);inputs=cell(1,2);
for k=1:2
 in=Simulink.SimulationInput(m);in=in.setModelParameter('StopTime','.003');in=in.setVariable('n',600,'Workspace',m);
 in=in.setBlockParameter([m '/功率设置'],'gate_on','on');in=in.setBlockParameter([m '/功率设置'],'gate_us',num2str(2*(k-1)));
 in=in.setBlockParameter([m '/功率设置'],'comp_on','off');inputs{k}=in;original{k}=sim(in);
end
pmsm_reference('restore');before=teach_snapshot(m);cfg=pmsm_config('read');mw=get_param(m,'ModelWorkspace');code=mw.MATLABCode;
pmsm_deadtime_scope('install',m,'gates');definition=pmsm_deadtime_scope('open',m,'effects');
assert(strcmp(pmsm_deadtime_scope('mode'),'effects')&&strcmp(get_param(definition.path,'SampleTime'),'T'));
assert(numel(find_system(m,'SearchDepth',1,'Name','死区教学'))==1);
c=get_param(definition.path,'ScopeConfiguration');assert(isequal(c.LayoutDimensions,[2 2])&&strcmp(c.TimeSpan,'0.02'));
style=pmsm_scope_style(definition.path,'deadtime_effects');assert(size(style.LineColor,1)==9&&isequal(style.AxesColor,[1 1 1]));
originalChecks=0;sourceChecks=0;
for k=1:2
 out=sim(inputs{k});names=original{k}.who;
 for name=names(:)'
  x=original{k}.get(name{1});if ~isa(x,'timeseries'),continue;end;y=out.get(name{1});
  assert(isequal(x.Time,y.Time)&&isequal(x.Data,y.Data),'观测影响原日志：%s',name{1});originalChecks=originalChecks+1;
 end
 data=out.native_deadtime_scope;assert(data.numElements==4);s=cell(1,4);
 for j=1:4,s{j}=data.getElement(j).Values;assert(isequal(s{j}.Time,data.getElement(1).Values.Time));end
 assert(abs(median(diff(s{1}.Time))-1e-6)<1e-14);
 for j=1:3,check(s{1},j,out.obs_current_fast,j);end
 check(s{2},1,out.obs_id_ref,1);check(s{2},2,out.obs_state,1);
 check(s{3},1,out.log_iq_ref,1);check(s{3},2,out.obs_state,2);
 check(s{4},1,out.log_TL,1);check(s{4},2,out.log_Te,1);
end
pmsm_deadtime_scope('remove');pmsm_reference('restore');assert(isequaln(before,teach_snapshot(m))&&isequaln(cfg,pmsm_config('read'))&&strcmp(code,mw.MATLABCode));
pmsm_observation_view('install');pmsm_deadtime_scope('install',m,'effects');
pmsm_presented_call(@pmsm_reference,'restore');assert(strcmp(pmsm_deadtime_scope('mode'),'effects'));
try,pmsm_presented_call(@()error('pmsm:DeadtimeEffectsTest','intentional'));catch err,assert(strcmp(err.identifier,'pmsm:DeadtimeEffectsTest'));end
assert(strcmp(pmsm_deadtime_scope('mode'),'effects'));
pmsm_deadtime_scope('open',m,'gates');assert(strcmp(pmsm_deadtime_scope('mode'),'gates'));
pmsm_deadtime_scope('open',m,'effects');assert(strcmp(pmsm_deadtime_scope('mode'),'effects'));
pmsm_deadtime_scope('remove');pmsm_observation_view('remove');assert(isequaln(before,teach_snapshot(m)));
fig=open_pmsm_deadtime_lesson;drawnow;
buttons=findall(fig,'Type','uibutton');assert(all(ismember({'功率设置','门极与电压','电流与转矩'},{buttons.Text})));
exportapp(fig,fullfile(root,'.build','deadtime_lesson_effects_ui.png'));delete(fig);
assert(strcmp(hash,teach_hash(source)));report=struct('passed',true,'model_sha256',hash,'original_log_checks',originalChecks,...
 'source_checks',sourceChecks,'scope_channels',9,'sample_time_s',1e-6,'one_topic_scope',true,'mode_switch_roundtrip',true,...
 'wrapper_mode_preserved_normal_and_exception',true,'structure_restored',true,'definition',definition,...
 'scope','同一详细桥0/2us、600rpm给定各3ms；验证观测接线与结构恢复，不评价稳态畸变或补偿效果');
files={'pmsm_deadtime_scope.m','pmsm_scope_style.m','pmsm_scope_theme.m','pmsm_presented_call.m','validate_pmsm_deadtime_effects_scope.m'};
for k=1:numel(files),report.sources(k)=struct('path',files{k},'sha256',teach_hash(fullfile(here,files{k})));end
teach_writejson(fullfile(here,'deadtime_effects_scope_validation.json'),report);
fprintf('DEADTIME_EFFECTS_VALIDATED %d original logs / %d source checks\n',originalChecks,sourceChecks);
 function check(native,ncol,raw,rcol)
  nt=native.Time;rt=raw.Time;[found,ix]=ismember(round(rt/1e-10),round(nt/1e-10));assert(all(found)&&max(abs(nt(ix)-rt))<1e-12);
  n=teach_values(native);r=teach_values(raw);assert(max(abs(n(ix,ncol)-r(:,rcol)))<1e-10);sourceChecks=sourceChecks+1;
 end
end
