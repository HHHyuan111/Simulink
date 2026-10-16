function report=validate_pmsm_deadtime_scope
here=fileparts(mfilename('fullpath'));root=fileparts(fileparts(here));addpath(root,here,fullfile(root,'teaching'));
m='PMSM_FOC_R2026a';assert(~bdIsLoaded(m));source=fullfile(root,[m '.slx']);hash=teach_hash(source);
load_system(source);guard=onCleanup(@()close_system(m,0));pmsm_reference('restore');
inputs=cell(1,3);original=cell(1,3);
for k=1:3
 in=Simulink.SimulationInput(m);in=in.setModelParameter('StopTime','.0015');in=in.setVariable('n',600,'Workspace',m);
 in=in.setBlockParameter([m '/功率设置'],'gate_on',onoff(k>1));in=in.setBlockParameter([m '/功率设置'],'gate_us',num2str(2*(k==3)));
 in=in.setBlockParameter([m '/功率设置'],'comp_on','off');inputs{k}=in;original{k}=sim(in);
end
pmsm_reference('restore');before=teach_snapshot(m);cfg=pmsm_config('read');mw=get_param(m,'ModelWorkspace');code=mw.MATLABCode;
definition=pmsm_deadtime_scope('install');assert(isequaln(cfg,pmsm_config('read'))&&strcmp(code,mw.MATLABCode));
c=get_param(definition.path,'ScopeConfiguration');assert(isequal(c.LayoutDimensions,[2 2])&&strcmp(c.TimeSpan,'0.0001'));
assert(strcmp(get_param(definition.path,'SampleTime'),'dead_h'));sourceChecks=0;originalChecks=0;edgeChecks=0;
pmsm_deadtime_scope('open');style=pmsm_scope_style(definition.path,'deadtime');assert(isequal(style.BackgroundColor,[1 1 1])&&size(style.LineColor,1)==7);
for k=1:3
 o=sim(inputs{k});
 names=original{k}.who;for name=names(:)'
  x=original{k}.get(name{1});if ~isa(x,'timeseries'),continue;end;y=o.get(name{1});
  assert(isequal(x.Time,y.Time)&&isequal(x.Data,y.Data),'原日志受到观测影响：%s',name{1});originalChecks=originalChecks+1;
 end
 ds=o.native_deadtime_scope;assert(ds.numElements==4);s=cell(1,4);
 for j=1:4,s{j}=ds.getElement(j).Values;assert(isequal(s{j}.Time,ds.getElement(1).Values.Time));end
 check(s{1},1,o.obs_dead_requested,1);check(s{1},2,o.obs_dead_gates,1);
 check(s{3},1,o.obs_dead_requested,2);check(s{3},2,o.obs_dead_gates,2);check(s{2},1,o.obs_current_fast,1);
 v=teach_values(s{4});if k==1,assert(all(isnan(v),'all'));
 else,check(s{4},1,o.obs_dead_requested,1,getVariable(mw,'Vdc'));check(s{4},2,o.obs_dead_bridge,4);end
 req=teach_values(s{1});low=teach_values(s{3});act=[req(:,2) low(:,2)];
 assert(all(sum(act,2)<=1),'出现上下管重叠');
 if k==2,assert(isequal(req(:,1),req(:,2))&&isequal(low(:,1),low(:,2)));
 elseif k==3
  t=s{1}.Time;h=median(diff(t));assert(abs(h-62.5e-9)<1e-14);
  requests=[req(:,1) low(:,1)];delay=round(2e-6/h);
  for phase=1:2
   rises=find(diff(act(:,phase))>0)+1;rises=rises(rises>delay);
   for edge=rises'
    assert(requests(edge-delay,phase)==1&&requests(edge-delay-1,phase)==0);
    assert(all(act(edge-delay:edge-1,:)==0,'all'));edgeChecks=edgeChecks+1;
   end
   falls=find(diff(requests(:,phase))<0)+1;assert(all(act(falls,phase)==0));
  end
 end
end
assert(edgeChecks>0);pmsm_deadtime_scope('remove');pmsm_reference('restore');
assert(isequaln(before,teach_snapshot(m))&&isequaln(cfg,pmsm_config('read'))&&strcmp(code,mw.MATLABCode));
% Exercise the presentation wrapper and its exception path with the new observer.
pmsm_observation_view('install');pmsm_deadtime_scope('install');
pmsm_presented_call(@pmsm_reference,'restore');assert(pmsm_deadtime_scope('installed')&&pmsm_observation_view('installed'));
try,pmsm_presented_call(@()error('pmsm:DeadtimeObserverTest','intentional'));catch err,assert(strcmp(err.identifier,'pmsm:DeadtimeObserverTest'));end
assert(pmsm_deadtime_scope('installed'));pmsm_deadtime_scope('remove');pmsm_observation_view('remove');assert(isequaln(before,teach_snapshot(m)));
assert(strcmp(hash,teach_hash(source)));report=struct('passed',true,'model_sha256',hash,'original_log_checks',originalChecks,...
 'source_checks',sourceChecks,'deadtime_edges_checked',edgeChecks,'disabled_bridge_voltage_is_nan',true,...
 'scope','原理想桥、详细桥0/2us各1.5ms；只验证观测接线与短时门极，不评价稳态补偿效果',...
 'structure_restored',true,'wrapper_normal_and_exception',true,'definition',definition);
teach_writejson(fullfile(here,'deadtime_scope_validation.json'),report);fprintf('DEADTIME_SCOPE_VALIDATED %d original logs / %d sources / %d edges\n',originalChecks,sourceChecks,edgeChecks);
 function check(native,ncol,raw,rcol,scale)
  if nargin<5,scale=1;end
  nt=native.Time;rt=raw.Time;[found,ix]=ismember(round(rt/1e-10),round(nt/1e-10));assert(all(found)&&max(abs(nt(ix)-rt))<1e-12);
  n=teach_values(native);r=teach_values(raw);assert(max(abs(n(ix,ncol)-r(:,rcol)*scale))<1e-10);sourceChecks=sourceChecks+1;
 end
end
function s=onoff(b)
if b,s='on';else,s='off';end
end
