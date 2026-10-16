function report=validate_pmsm_electrical_scope
here=fileparts(mfilename('fullpath'));root=fileparts(fileparts(here));addpath(root,here,fullfile(root,'teaching'));
mdl='PMSM_FOC_R2026a';assert(~bdIsLoaded(mdl));load_system(fullfile(root,[mdl '.slx']));cleanup=onCleanup(@()close_system(mdl,0));
pmsm_reference('restore');before=teach_snapshot(mdl);hash=teach_hash(fullfile(root,[mdl '.slx']));preSave=get_param(mdl,'PreSaveFcn');
files={'pmsm_electrical_scope.m','pmsm_presented_call.m','validate_pmsm_electrical_scope.m'};
fingerprints=cellfun(@(f)teach_hash(fullfile(here,f)),files,'UniformOutput',false);
raw=cell(1,2);inputs=cell(1,2);
for k=1:2
 in=Simulink.SimulationInput(mdl);in=in.setModelParameter('StopTime','.01');
 if k==2,in=in.setBlockParameter([mdl '/角度设置'],'bias_on','on');end
 inputs{k}=in;raw{k}=sim(in);
end
pmsm_presentation('apply');pmsm_native_scope('install');definition=pmsm_electrical_scope('install');
c=get_param(definition.path,'ScopeConfiguration');assert(isequal(c.LayoutDimensions,[2 2]));
for j=1:4,c.ActiveDisplay=num2str(j);assert(strcmp(c.AxesScaling,'Auto'));end
originalCount=0;displayCount=0;
for k=1:2
 out=sim(inputs{k});
 names=raw{k}.who;
 for name=names(:)'
  a=raw{k}.get(name{1});if ~isa(a,'timeseries'),continue;end;b=out.get(name{1});
  assert(isequaln(a.Time,b.Time)&&isequaln(a.Data,b.Data),'原日志发生变化：%s',name{1});originalCount=originalCount+1;
 end
 v=teach_values(out.obs_voltage);expected={teach_values(out.log_iabc_true),v(:,[1 3]),teach_values(out.log_iabc_meas),v(:,[2 4])};
 ds=out.native_electrical_scope;assert(ds.numElements==4);
 for j=1:4
  sig=ds.getElement(j).Values;assert(isequal(sig.Time,out.obs_voltage.Time));
  assert(isequaln(teach_values(sig),expected{j}),'电气Scope来源不一致');displayCount=displayCount+1;
 end
end
pmsm_presented_call(@pmsm_reference,'restore');assert(pmsm_electrical_scope('installed')&&pmsm_native_scope('installed'));
try,pmsm_presented_call(@()error('pmsm:ElectricalTest','intentional'));catch err,assert(strcmp(err.identifier,'pmsm:ElectricalTest'));end
assert(pmsm_electrical_scope('installed'));
pmsm_electrical_scope('remove');pmsm_native_scope('remove');pmsm_presentation('remove');
assert(isequaln(before,teach_snapshot(mdl))&&strcmp(preSave,get_param(mdl,'PreSaveFcn')));
lines=find_system(mdl,'FindAll','on','LookUnderMasks','all','Type','line');
for h=lines(:)',assert(~(isempty(get_param(h,'LineChildren'))&&all(get_param(h,'DstPortHandle')<0)),'残留悬空连线');end
pmsm_reference('restore');assert(strcmp(hash,teach_hash(fullfile(root,[mdl '.slx']))));
assert(isequal(fingerprints,cellfun(@(f)teach_hash(fullfile(here,f)),files,'UniformOutput',false)));
report=struct('passed',true,'matlab_version',version,'model_sha256',hash,'original_log_checks',originalCount, ...
 'display_checks',displayCount,'structure_restored',true,'wrapper_normal_and_exception',true, ...
 'definition',definition,'sources',struct('path',files,'sha256',fingerprints),'scope','Two 10ms cases; ideal and angle bias. Not full operating-range validation.');
teach_writejson(fullfile(here,'electrical_scope_validation.json'),report);
fprintf('ELECTRICAL_SCOPE_VALIDATED %d original logs, %d display matrices\n',originalCount,displayCount);
end
