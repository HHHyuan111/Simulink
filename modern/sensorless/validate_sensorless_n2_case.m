function result=validate_sensorless_n2_case(testcase,folder)
% One fresh model instance per case; keep driver and case execution separate.
root=fileparts(fileparts(mfilename('fullpath')));mdl='PMSM_FOC_R2026a';
fprintf('N2_CASE_LOAD %s\n',testcase.id);load_system(fullfile(root,[mdl '.slx']));
guard=onCleanup(@()restore_model(mdl));
  fprintf('N2_CASE_RESTORE %s\n',testcase.id);pmsm_reference('restore');
  if strcmp(testcase.timing,'real'),set_param([mdl '/时序设置'],'real_on','on');end
  set_param(mdl,'SimulationCommand','update');
  original=teach_snapshot(mdl);originalState=pmsm_reference('capture');
  installed=~strcmp(testcase.observer,'absent');
  if installed
   pmsm_sensorless_model('install',mdl);
   if strcmp(testcase.observer,'disabled'),set_param([mdl '/无感观测'],'enabled','off');end
   set_param(mdl,'SimulationCommand','update');
   graph=check_sensorless_graph(mdl,original);teach_writejson(fullfile(folder,[testcase.id '_graph.json']),graph);
   assert(graph.passed,'原模块或信号域检查未通过。');
   feval(mdl,[],[],[],'compile');
   paths={'滑模观测/隐式校正','反电动势/滤波校正','锁相环/归一化PLL','有效判断/锁定判断','区间电压/分段累计'};
   compiled=struct('path',{},'sample_time',{});
   for j=1:numel(paths),compiled(j)=struct('path',paths{j},'sample_time',{get_param([mdl '/无感观测/' paths{j}],'CompiledSampleTime')});end
   feval(mdl,[],[],[],'term');
   teach_writejson(fullfile(folder,[testcase.id '_rates.json']),compiled);
   if strcmp(testcase.id,'reference_enabled')
    print(['-s' mdl '/无感观测'],'-dpng','-r140',fullfile(folder,'module_layout.png'));
    print(['-s' mdl '/无感观测/滑模观测'],'-dpng','-r140',fullfile(folder,'smo_layout.png'));
   end
  end
  fprintf('N2_SIM_BEGIN %s duration=%g\n',testcase.id,testcase.duration_s);
  in=Simulink.SimulationInput(mdl);in=in.setModelParameter('StopTime',num2str(testcase.duration_s,17));
  out=sim(in);signals=struct;
  for name=out.who'
   value=out.get(name{1});if ~isa(value,'timeseries'),continue;end
   assert(all(isfinite(value.Data),'all')&&all(isfinite(value.Time),'all'),'非有限日志：%s',name{1});
   signals.(name{1})=value;
  end
  if installed
   theta=signals.obs_sless_theta;truth=signals.obs_sless_truth_theta;
   assert(isequaln(theta.Time,truth.Time));
   difference=teach_values(theta)-teach_values(truth);
   signals.obs_sless_angle_error=timeseries(atan2(sin(difference),cos(difference)),theta.Time);
   speed=signals.obs_sless_speed;speedTruth=signals.obs_sless_truth_speed;assert(isequaln(speed.Time,speedTruth.Time));
   signals.obs_sless_speed_error=timeseries(teach_values(speed)-teach_values(speedTruth),speed.Time);
  end
  filename=[testcase.id '.mat'];save(fullfile(folder,filename),'signals','-v7.3');
  if installed,pmsm_sensorless_model('remove',mdl);end
  after=teach_snapshot(mdl);afterState=pmsm_reference('capture');
  save(fullfile(folder,[testcase.id '_restoration.mat']),'original','after','originalState','afterState');
  restored=isequaln(original,after)&&isequaln(originalState,afterState);
  result=struct('id',testcase.id,'file',filename,'sha256',teach_hash(fullfile(folder,filename)),...
   'installed',installed,'restored',restored);
  assert(restored,'Observer removal did not restore original state.');
  fprintf('N2_SIM_DONE %s logs=%d restored=1\n',testcase.id,numel(fieldnames(signals)));
end
function restore_model(mdl)
if ~bdIsLoaded(mdl),return;end
try,if pmsm_sensorless_model('installed',mdl),pmsm_sensorless_model('remove',mdl);end,catch,end
close_system(mdl,0);
end
