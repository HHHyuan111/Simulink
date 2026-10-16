function report=validate_pmsm_current_sampling_scope
here=fileparts(mfilename('fullpath'));root=fileparts(fileparts(here));addpath(root,here,fullfile(root,'teaching'));
mdl='PMSM_FOC_R2026a';assert(~bdIsLoaded(mdl));load_system(fullfile(root,[mdl '.slx']));cleanup=onCleanup(@()close_system(mdl,0));
pmsm_reference('restore');before=teach_snapshot(mdl);hash=teach_hash(fullfile(root,[mdl '.slx']));guard=get_param(mdl,'PreSaveFcn');
raw=cell(1,3);inputs=cell(1,3);rates=[];originalChecks=0;sourceChecks=0;
for k=1:3
 in=Simulink.SimulationInput(mdl);in=in.setModelParameter('StopTime','.001');
 if k==2,in=in.setBlockParameter([mdl '/时序设置'],'real_on','on');end
 if k==3
  pairs={'adc_on','on';'adc_bits','8';'delay_on','on';'delay_cycles','1'};
  for j=1:size(pairs,1),in=in.setBlockParameter([mdl '/采样设置'],pairs{j,1},pairs{j,2});end
 end
 inputs{k}=in;raw{k}=sim(in);
end
pmsm_presentation('apply');definition=pmsm_current_sampling_scope('install');
c=get_param(definition.path,'ScopeConfiguration');assert(isequal(c.LayoutDimensions,[2 2])&&~c.DataLoggingDecimateData);
assert(strcmp(get_param(definition.path,'SampleTime'),'timing_h')&&strcmp(c.DataLoggingMaxPoints,'64000'));
for k=1:3
 out=sim(inputs{k});
 names=raw{k}.who;
 for name=names(:)'
  a=raw{k}.get(name{1});if ~isa(a,'timeseries'),continue;end;b=out.get(name{1});
  assert(isequaln(a.Time,b.Time)&&isequaln(a.Data,b.Data),'原日志变化：%s',name{1});originalChecks=originalChecks+1;
 end
 ds=out.native_current_sampling_scope;assert(ds.numElements==4);sig=cell(1,4);
 for j=1:4,sig{j}=ds.getElement(j).Values;assert(isequal(sig{j}.Time,ds.getElement(1).Values.Time));end
 step=median(diff(sig{1}.Time));rates(k)=step;if k==2,assert(abs(step-62.5e-9)<1e-14);else,assert(abs(step-1e-6)<1e-14);end
 assert(numel(sig{1}.Time)>numel(out.log_iabc_true.Time)*20,'观测仍在控制频率抽点');
 check(sig{1},1:3,out.log_iabc_true,1:3);
 check(sig{2},1,out.log_iabc_true,1);
 check(sig{2},3,out.log_iabc_meas,1);
 check(sig{3},1:3,out.log_iabc_meas,1:3);
 check(sig{4},1:2,out.obs_adc_timing,[2 6]);
 if k<=2,check(sig{2},2,out.log_iabc_adc,1);end
 x=teach_values(sig{1});chain=teach_values(sig{2});fb=teach_values(sig{3});
 assert(max(abs(chain(:,1)-x(:,1)))<1e-12&&max(abs(chain(:,3)-fb(:,1)))<1e-12);
 if k==1,assert(isequaln(x,fb),'理想反馈应旁路采样链');end
end
pmsm_presented_call(@pmsm_reference,'restore');assert(pmsm_current_sampling_scope('installed'));
try,pmsm_presented_call(@()error('pmsm:SamplingScopeTest','intentional'));catch err,assert(strcmp(err.identifier,'pmsm:SamplingScopeTest'));end
assert(pmsm_current_sampling_scope('installed'));
pmsm_current_sampling_scope('remove');pmsm_pwm_scope('remove');pmsm_electrical_scope('remove');pmsm_native_scope('remove');pmsm_presentation('remove');
assert(isequaln(before,teach_snapshot(mdl))&&strcmp(guard,get_param(mdl,'PreSaveFcn')));
lines=find_system(mdl,'FindAll','on','LookUnderMasks','all','Type','line');for h=lines(:)',assert(~(isempty(get_param(h,'LineChildren'))&&all(get_param(h,'DstPortHandle')<0)));end
pmsm_reference('restore');assert(strcmp(hash,teach_hash(fullfile(root,[mdl '.slx']))));
f=open_pmsm_teaching('off');assert(isscalar(findall(f,'Type','uimenu','Text','电流与采样')));delete(f);
files={'pmsm_current_sampling_scope.m','pmsm_current_sampling_fit.m','pmsm_scope_style.m','pmsm_presented_call.m','validate_pmsm_current_sampling_scope.m'};
report=struct('passed',true,'model_sha256',hash,'original_log_checks',originalChecks,'source_checks',sourceChecks,'observed_step_seconds',rates,'structure_restored',true,'wrapper_normal_and_exception',true, ...
 'definition',definition,'sources',struct('path',files,'sha256',cellfun(@(f)teach_hash(fullfile(here,f)),files,'UniformOutput',false)), ...
 'scope','Three 1ms cases: ideal, real timing, ideal timing with ADC and legacy one-cycle delay. No full operating-range or physical ADC calibration claim.');
teach_writejson(fullfile(here,'current_sampling_scope_validation.json'),report);fprintf('CURRENT_SAMPLING_SCOPE_VALIDATED %d logs, %d source checks\n',originalChecks,sourceChecks);
 function check(native,ncols,source,scols)
  values=teach_values(native);original=teach_values(source);ix=round(interp1(native.Time,(1:numel(native.Time))',source.Time,'nearest'));
  assert(all(isfinite(ix))&&max(abs(native.Time(ix)-source.Time))<1e-12);
  assert(max(abs(values(ix,ncols)-original(:,scols)),[],'all')<1e-9);sourceChecks=sourceChecks+1;
 end
end
