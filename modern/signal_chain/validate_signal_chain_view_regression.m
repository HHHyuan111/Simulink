function report=validate_signal_chain_view_regression
root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'teaching'),fullfile(root,'layout','appearance'));
cached=load(fullfile(root,'.build','signal_chain','audit_runs.mat'),'out','cases','report');assert(cached.report.passed);
m='PMSM_FOC_R2026a';assert(~bdIsLoaded(m));assert(strcmp(cached.report.model_sha256,teach_hash(fullfile(root,[m '.slx']))));
load_system(fullfile(root,[m '.slx']));guard=onCleanup(@()close_system(m,0));pmsm_reference('restore');before=teach_snapshot(m);
pmsm_presentation('apply');pmsm_signal_chain_view('apply');checks=0;
for k=[1 8 15]
 c=cached.cases{k};in=Simulink.SimulationInput(m);in=in.setModelParameter('StopTime','.002');
 in=in.setBlockParameter([m '/采样设置/记录_obs_adc_timing'],'MaxDataPoints','inf');in=in.setBlockParameter([m '/输出延迟/记录_obs_pwm_timing'],'MaxDataPoints','inf');
 for j=1:size(c.sampling,1),in=in.setBlockParameter([m '/采样设置'],c.sampling{j,1},c.sampling{j,2});end
 for j=1:size(c.timing,1),in=in.setBlockParameter([m '/时序设置'],c.timing{j,1},c.timing{j,2});end
 s=sim(in);names=cached.out{k}.who;
 for name=names(:)'
  a=cached.out{k}.get(name{1});if ~isa(a,'timeseries'),continue;end;b=s.get(name{1});
  assert(isequaln(a.Time,b.Time)&&isequaln(a.Data,b.Data));checks=checks+1;
 end
end
pmsm_signal_chain_view('remove');pmsm_presentation('remove');assert(isequaln(before,teach_snapshot(m)));
report=struct('passed',true,'exact_original_logs',checks,'original_graph_restored',true,...
 'view_sha256',teach_hash(fullfile(root,'layout','appearance','pmsm_signal_chain_view.m')));
teach_writejson(fullfile(root,'signal_chain','view_regression.json'),report);disp('SIGNAL_CHAIN_VIEW_REGRESSION_VALIDATED');
end
