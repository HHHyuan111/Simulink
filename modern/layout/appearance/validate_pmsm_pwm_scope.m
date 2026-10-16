function report=validate_pmsm_pwm_scope
here=fileparts(mfilename('fullpath'));root=fileparts(fileparts(here));addpath(root,here,fullfile(root,'teaching'));
mdl='PMSM_FOC_R2026a';assert(~bdIsLoaded(mdl));load_system(fullfile(root,[mdl '.slx']));cleanup=onCleanup(@()close_system(mdl,0));
pmsm_reference('restore');before=teach_snapshot(mdl);hash=teach_hash(fullfile(root,[mdl '.slx']));preSave=get_param(mdl,'PreSaveFcn');
files={'pmsm_pwm_scope.m','pmsm_presented_call.m','validate_pmsm_pwm_scope.m'};
fingerprints=cellfun(@(f)teach_hash(fullfile(here,f)),files,'UniformOutput',false);
raw=cell(1,2);inputs=cell(1,2);
for k=1:2
 in=Simulink.SimulationInput(mdl);in=in.setModelParameter('StopTime','.001');
 if k==2,in=in.setBlockParameter([mdl '/时序设置'],'real_on','on');end
 inputs{k}=in;raw{k}=sim(in);
end
pmsm_presentation('apply');definition=pmsm_pwm_scope('install');
c=get_param(definition.path,'ScopeConfiguration');assert(isequal(c.LayoutDimensions,[2 2])&&strcmp(c.TimeSpan,'0.0002'));
assert(strcmp(get_param(definition.path,'SampleTime'),'timing_h'));
assert(strcmp(c.TimeSpanOverrunAction,'Scroll'));
for j=2:4,c.ActiveDisplay=num2str(j);assert(isequal(c.YLimits,[-.1 1.1])&&strcmp(c.AxesScaling,'Manual'));end
originalCount=0;sourceChecks=0;events=[];
for k=1:2
 out=sim(inputs{k});names=raw{k}.who;
 for name=names(:)'
  a=raw{k}.get(name{1});if ~isa(a,'timeseries'),continue;end;b=out.get(name{1});
  assert(isequaln(a.Time,b.Time)&&isequaln(a.Data,b.Data),'原日志发生变化：%s',name{1});originalCount=originalCount+1;
 end
 ds=out.native_pwm_scope;assert(ds.numElements==4);
 sig=cell(1,4);for j=1:4,sig{j}=ds.getElement(j).Values;assert(isequal(sig{j}.Time,sig{1}.Time));end
 check(sig{1},1,out.obs_carrier_fast,1,1e6);
 check(sig{1},2,out.log_Tcm_requested,1,1e6);
 check(sig{1},3,out.log_Tcm_applied,1,1e6);
 check(sig{2},[1 2],out.obs_dead_gates,[1 2],1);
 check(sig{3},[1 2],out.obs_adc_timing,[2 6],1);
 check(sig{4},[1 2 3],out.obs_pwm_timing,[3 4 5],1);
 a=teach_values(sig{3});p=teach_values(sig{4});h=median(diff(sig{1}.Time));
 if k==1,assert(all(a==0,'all')&&all(p==0,'all'));
 else
  assert(abs(h-62.5e-9)<1e-14,'事件观测网格不够细');
  events=[sum(a>0,1) sum(p>0,1)];assert(all(events>0),'事件脉冲遗漏');
 end
end
pmsm_presented_call(@pmsm_reference,'restore');assert(pmsm_pwm_scope('installed'));
try,pmsm_presented_call(@()error('pmsm:PWMTest','intentional'));catch err,assert(strcmp(err.identifier,'pmsm:PWMTest'));end
assert(pmsm_pwm_scope('installed'));
pmsm_pwm_scope('remove');pmsm_electrical_scope('remove');pmsm_native_scope('remove');pmsm_presentation('remove');
assert(isequaln(before,teach_snapshot(mdl))&&strcmp(preSave,get_param(mdl,'PreSaveFcn')));
lines=find_system(mdl,'FindAll','on','LookUnderMasks','all','Type','line');
for h=lines(:)',assert(~(isempty(get_param(h,'LineChildren'))&&all(get_param(h,'DstPortHandle')<0)),'残留悬空连线');end
pmsm_reference('restore');assert(strcmp(hash,teach_hash(fullfile(root,[mdl '.slx']))));
assert(isequal(fingerprints,cellfun(@(f)teach_hash(fullfile(here,f)),files,'UniformOutput',false)));
f=open_pmsm_teaching('off');assert(isscalar(findall(f,'Tag','pwm_scope_entry')));delete(f);
report=struct('passed',true,'matlab_version',version,'model_sha256',hash,'original_log_checks',originalCount, ...
 'source_checks',sourceChecks,'real_event_counts_trigger_JEOS_UEV_write_latch',events, ...
 'structure_restored',true,'wrapper_normal_and_exception',true,'definition',definition, ...
 'sources',struct('path',files,'sha256',fingerprints),'scope','Ideal and real timing, 1ms each. Native grid checked at 62.5ns. Not full operating-range validation.');
teach_writejson(fullfile(here,'pwm_scope_validation.json'),report);
fprintf('PWM_SCOPE_VALIDATED %d original logs, %d source checks\n',originalCount,sourceChecks);
 function check(native,ncols,source,scols,scale)
  n=teach_values(native);s=teach_values(source);
  indices=round(interp1(native.Time,(1:numel(native.Time))',source.Time,'nearest'));
  assert(all(isfinite(indices))&&max(abs(native.Time(indices)-source.Time))<1e-12);
  assert(max(abs(n(indices,ncols)-s(:,scols)*scale),[],'all')<1e-9,'Scope显示与原日志不符');sourceChecks=sourceChecks+1;
 end
end
