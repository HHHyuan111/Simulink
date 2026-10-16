function report=validate_pmsm_deadtime_comp_scope
here=fileparts(mfilename('fullpath'));root=fileparts(fileparts(here));addpath(root,here,fullfile(root,'teaching'));
m='PMSM_FOC_R2026a';assert(~bdIsLoaded(m));source=fullfile(root,[m '.slx']);hash=teach_hash(source);
load_system(source);closer=onCleanup(@()close_system(m,0));pmsm_reference('restore');
mw=get_param(m,'ModelWorkspace');Vdc=getVariable(mw,'Vdc');Ts=getVariable(mw,'Ts');
hys=str2double(get_param([m '/功率设置'],'hysteresis_A'));original=cell(1,3);inputs=cell(1,3);
for k=1:3
 in=Simulink.SimulationInput(m);in=in.setModelParameter('StopTime','.004');in=in.setVariable('n',600,'Workspace',m);
 in=in.setBlockParameter([m '/功率设置'],'gate_on','on');in=in.setBlockParameter([m '/功率设置'],'gate_us','2');
 in=in.setBlockParameter([m '/功率设置'],'comp_on',onoff(k>1));in=in.setBlockParameter([m '/功率设置'],'comp_us',num2str(2*(k==2)));
 inputs{k}=in;original{k}=sim(in);
end
for key={'obs_state','log_iq_ref','log_Te','obs_current_fast','obs_dead_gates'}
 x=original{1}.get(key{1});y=original{3}.get(key{1});assert(isequal(x.Time,y.Time)&&isequal(x.Data,y.Data),'零幅值补偿物理回归失败。');
end
pmsm_reference('restore');before=teach_snapshot(m);cfg=pmsm_config('read');code=mw.MATLABCode;
definition=pmsm_deadtime_scope('open',m,'compensation');c=get_param(definition.path,'ScopeConfiguration');
assert(isequal(c.LayoutDimensions,[2 2])&&strcmp(c.TimeSpan,'0.02')&&strcmp(get_param(definition.path,'SampleTime'),'timing_control_sample'));
c.ActiveDisplay='3';assert(isequal(c.YLimits,[-1.2 1.2]));c.ActiveDisplay='1';
style=pmsm_scope_style(definition.path,'deadtime_compensation');assert(size(style.LineColor,1)==7&&isequal(style.AxesColor,[1 1 1]));
originalChecks=0;sourceChecks=0;maxVoltageError=0;signCounts=zeros(1,3);
for k=1:3
 out=sim(inputs{k});names=original{k}.who;
 for name=names(:)'
  x=original{k}.get(name{1});if ~isa(x,'timeseries'),continue;end;y=out.get(name{1});
  assert(isequal(x.Time,y.Time)&&isequal(x.Data,y.Data),'原日志受到补偿观测影响：%s',name{1});originalChecks=originalChecks+1;
 end
 data=out.native_deadtime_scope;assert(data.numElements==4);s=cell(1,4);
 for j=1:4,s{j}=data.getElement(j).Values;assert(isequal(s{j}.Time,out.obs_dead_comp.Time));end
 assert(abs(median(diff(s{1}.Time))-50e-6)<1e-12);
 check(s{1},1,out.log_iabc_meas,1);v=teach_values(s{1});assert(all(v(:,2)==hys)&&all(v(:,3)==-hys));sourceChecks=sourceChecks+2;
 check(s{2},1,out.obs_dead_comp,1);check(s{3},1,out.obs_dead_comp,6);
 check(s{4},1,out.log_iq_ref,1);check(s{4},2,out.obs_state,2);
 diag=teach_values(out.obs_dead_comp);meas=teach_values(out.log_iabc_meas);
 if k==1,assert(all(diag==0,'all'));
 else
  expected=zeros(size(meas));last=zeros(1,3);
  for row=1:size(meas,1),last(meas(row,:)>hys)=1;last(meas(row,:)<-hys)=-1;expected(row,:)=last;end
  assert(isequal(diag(:,6:8),expected));
  voltage=Vdc*(2e-6*(k==2))/Ts*expected;voltage=voltage-mean(voltage,2);
  err=max(abs(voltage-diag(:,1:3)),[],'all');assert(err<1e-10);maxVoltageError=max(maxVoltageError,err);
  if k==2,assert(any(abs(diag(:,1))>0));signCounts=[sum(expected(:,1)<0) sum(expected(:,1)==0) sum(expected(:,1)>0)];end
 end
end
pmsm_deadtime_scope('remove');pmsm_reference('restore');assert(isequaln(before,teach_snapshot(m))&&isequaln(cfg,pmsm_config('read'))&&strcmp(code,mw.MATLABCode));
pmsm_observation_view('install');pmsm_deadtime_scope('install',m,'compensation');
pmsm_presented_call(@pmsm_reference,'restore');assert(strcmp(pmsm_deadtime_scope('mode'),'compensation'));
try,pmsm_presented_call(@()error('pmsm:DeadtimeCompViewTest','intentional'));catch err,assert(strcmp(err.identifier,'pmsm:DeadtimeCompViewTest'));end
assert(strcmp(pmsm_deadtime_scope('mode'),'compensation'));
for view={'gates','effects','compensation'},pmsm_deadtime_scope('open',m,view{1});assert(strcmp(pmsm_deadtime_scope('mode'),view{1}));end
pmsm_deadtime_scope('remove');pmsm_observation_view('remove');assert(isequaln(before,teach_snapshot(m)));
fig=open_pmsm_deadtime_lesson;drawnow;buttons=findall(fig,'Type','uibutton');assert(all(ismember({'功率设置','门极与电压','电流与转矩','补偿作用'},{buttons.Text})));
exportapp(fig,fullfile(root,'.build','deadtime_lesson_comp_ui.png'));delete(fig);
assert(strcmp(hash,teach_hash(source)));report=struct('passed',true,'model_sha256',hash,'original_log_checks',originalChecks,...
 'source_checks',sourceChecks,'scope_channels',7,'sample_time_s',50e-6,'max_compensation_voltage_formula_error_V',maxVoltageError,...
 'polarity_sample_counts_negative_zero_positive',signCounts,'zero_magnitude_physical_regression',true,'three_mode_roundtrip',true,...
 'wrapper_mode_preserved_normal_and_exception',true,'structure_restored',true,'definition',definition,...
 'scope','详细桥2us、600rpm给定：补偿关/匹配2us/零补偿幅值，各4ms；只验证观测与算法诊断来源，不评价稳态补偿改善');
files={'pmsm_deadtime_scope.m','pmsm_scope_style.m','pmsm_scope_theme.m','pmsm_presented_call.m','validate_pmsm_deadtime_comp_scope.m'};
for k=1:numel(files),report.sources(k)=struct('path',files{k},'sha256',teach_hash(fullfile(here,files{k})));end
teach_writejson(fullfile(here,'deadtime_comp_scope_validation.json'),report);fprintf('DEADTIME_COMP_SCOPE_VALIDATED %d original logs / %d sources\n',originalChecks,sourceChecks);
 function check(native,ncol,raw,rcol)
  assert(isequal(native.Time,raw.Time));n=teach_values(native);r=teach_values(raw);assert(max(abs(n(:,ncol)-r(:,rcol)))<1e-10);sourceChecks=sourceChecks+1;
 end
end
function s=onoff(b)
if b,s='on';else,s='off';end
end
