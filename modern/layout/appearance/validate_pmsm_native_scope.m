function report=validate_pmsm_native_scope
% Original-vs-observed simulations, native buffered values and full restoration.
here=fileparts(mfilename('fullpath'));root=fileparts(fileparts(here));teach=fullfile(root,'teaching');
addpath(root,here,teach);mdl='PMSM_FOC_R2026a';assert(~bdIsLoaded(mdl),'请在独立MATLAB进程验证。');
load_system(fullfile(root,[mdl '.slx']));cleanup=onCleanup(@()close_system(mdl,0));
pmsm_reference('restore');before=teach_snapshot(mdl);danglingBefore=danglingCount(mdl);hash=teach_hash(fullfile(root,[mdl '.slx']));
referenceHash=teach_hash(fullfile(teach,'reference_v1','manifest.json'));preSave=get_param(mdl,'PreSaveFcn');
runtime={'pmsm_native_scope.m','pmsm_presented_call.m','validate_pmsm_native_scope.m'};
fingerprints=cellfun(@(x)teach_hash(fullfile(here,x)),runtime,'UniformOutput',false);
raw=cell(1,2);inputs=cell(1,2);names={'ideal','angle_bias'};
for k=1:2
 in=Simulink.SimulationInput(mdl);in=in.setModelParameter('StopTime','.02');
 if k==2,in=in.setBlockParameter([mdl '/角度设置'],'bias_on','on');end
 inputs{k}=in;fprintf('NATIVE_SCOPE_ORIGINAL %s\n',names{k});raw{k}=sim(in);
end
definition=pmsm_native_scope('install');scope=definition.path;c=get_param(scope,'ScopeConfiguration');
assert(isequal(c.LayoutDimensions,[2 2])&&strcmp(c.NumInputPorts,'4')&&strcmp(c.TimeSpan,'Auto'));
for j=1:4,c.ActiveDisplay=num2str(j);assert(strcmp(c.AxesScaling,'Auto'));end
c.ActiveDisplay='1';
assert(strcmp(get_param([mdl '/跟踪观测'],'OpenFcn'),'pmsm_native_scope(''open'');'));
originalChecks=struct('case',{},'signal',{},'time_equal',{},'data_equal',{});
scopeChecks=struct('case',{},'display',{},'time_equal',{},'max_error_A_or_rpm_or_Nm',{});
for k=1:2
 fprintf('NATIVE_SCOPE_OBSERVED %s\n',names{k});out=sim(inputs{k});
 originalNames=raw{k}.who;
 for n=originalNames(:)'
  a=raw{k}.get(n{1});if ~isa(a,'timeseries'),continue;end;b=out.get(n{1});
  originalChecks(end+1)=struct('case',names{k},'signal',n{1},'time_equal',isequaln(a.Time,b.Time),'data_equal',isequaln(a.Data,b.Data));
 end
 data=out.get('native_control_scope');assert(isa(data,'Simulink.SimulationData.Dataset')&&data.numElements==4);
 state=teach_values(out.obs_state);
 expected={[teach_values(out.log_nref) teach_values(out.log_speed)], ...
  [teach_values(out.obs_id_ref) state(:,1) teach_values(out.log_id)], ...
  [teach_values(out.log_Te) teach_values(out.log_TL)], ...
  [teach_values(out.log_iq_ref) state(:,2) teach_values(out.log_iq)]};
 for j=1:4
  sig=data.getElement(j).Values;valueError=max(abs(teach_values(sig)-expected{j}),[],'all');
  sameTime=isequal(sig.Time,out.log_speed.Time);assert(sameTime&&valueError<1e-12,'Scope显示数据与模型原日志不符。');
  scopeChecks(end+1)=struct('case',names{k},'display',j,'time_equal',sameTime,'max_error_A_or_rpm_or_Nm',valueError);
 end
end
assert(numel(originalChecks)>=50&&all([originalChecks.time_equal])&&all([originalChecks.data_equal]));
pmsm_native_scope('remove');assert(isequaln(before,teach_snapshot(mdl))&&strcmp(get_param(mdl,'PreSaveFcn'),preSave));
danglingAfter=danglingCount(mdl);assert(danglingAfter==danglingBefore,'撤销观测后出现残留连线。');
pmsm_reference('restore');
% Exercise the same restoration wrapper used by the existing experiment GUI.
fprintf('NATIVE_SCOPE_LAYOUT_APPLY\n');pmsm_presentation('apply');
fprintf('NATIVE_SCOPE_LAYOUT_INSTALL\n');pmsm_native_scope('install');
fprintf('NATIVE_SCOPE_WRAPPED_RESTORE\n');pmsm_presented_call(@pmsm_reference,'restore');
assert(pmsm_presentation('installed')&&pmsm_native_scope('installed'));
try,pmsm_presented_call(@()error('pmsm:ScopeTest','intentional'));catch err
 assert(strcmp(err.identifier,'pmsm:ScopeTest'),'异常恢复失败：%s',getReport(err,'extended','hyperlinks','off'));
end
assert(pmsm_native_scope('installed'));pmsm_native_scope('remove');pmsm_presentation('remove');
assert(isequaln(before,teach_snapshot(mdl)));pmsm_reference('restore');
f=open_pmsm_teaching('off');assert(isscalar(findall(f,'Tag','native_scope_entry'))&&isempty(findall(f,'Tag','vector_lesson_entry')));delete(f);
assert(strcmp(hash,teach_hash(fullfile(root,[mdl '.slx'])))&&strcmp(referenceHash,teach_hash(fullfile(teach,'reference_v1','manifest.json'))));
assert(isequal(fingerprints,cellfun(@(x)teach_hash(fullfile(here,x)),runtime,'UniformOutput',false)),'验收期间源码发生变化。');
report=struct('schema',1,'kind','native_control_scope_v1','matlab_version',version,'passed',true, ...
 'model_sha256',hash,'definition',definition,'original_checks',originalChecks,'scope_checks',scopeChecks, ...
 'original_structure_restored',true,'fixed_reference_unchanged',true,'gui_reference_wrapper_passed',true, ...
 'dangling_lines_before',danglingBefore,'dangling_lines_after',danglingAfter, ...
 'source_files',struct('path',runtime,'sha256',fingerprints),'scope','Two 20ms cases; exact original numerical logs, 10 native Scope channels, wrapper and restoration.');
teach_writejson(fullfile(here,'native_scope_validation.json'),report);
fprintf('NATIVE_SCOPE_VALIDATED %d original logs, %d displays\n',numel(originalChecks),numel(scopeChecks));
end
function n=danglingCount(mdl)
lines=find_system(mdl,'FindAll','on','LookUnderMasks','all','FollowLinks','off','Type','line');n=0;
for h=lines(:)'
 if isempty(get_param(h,'LineChildren'))&&all(get_param(h,'DstPortHandle')<0),n=n+1;end
end
end
