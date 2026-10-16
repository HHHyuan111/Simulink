function report=validate_pmsm_timing_events(phase)
% Acceptance runs in fresh engines; model and complete reference stay frozen.
here=fileparts(mfilename('fullpath'));root=fileparts(here);
if nargin<1
 executable=fullfile(matlabroot,'bin','matlab.exe');quotedHere=strrep(here,'''','''''');
 for part={'default','repeat','parameters','finish'}
  command=sprintf('"%s" -batch "addpath(''%s''); validate_pmsm_timing_events(''%s'')"',executable,quotedHere,part{1});
  [status,output]=system(command);fprintf('%s',output);assert(status==0,'时序验收阶段失败：%s',part{1});
 end
 report=jsondecode(fileread(fullfile(here,'experiment_timing_events_validation.json')));assert(report.all_passed);return
end
assert(ismember(phase,{'default','repeat','parameters','finish'}));mdl='PMSM_FOC_R2026a';assert(~bdIsLoaded(mdl));
work=fullfile(root,'.build',['timing_event_check_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);mkdir(work);
old=pwd;cg=onCleanup(@()cd(old));cd(work);addpath(here);candidate=fullfile(work,[mdl '.slx']);copyfile(fullfile(root,[mdl '.slx']),candidate);
load_system(candidate);mg=onCleanup(@()close_system(mdl,0));pmsm_reference('restore');before=pmsm_reference('capture');geometry=teach_snapshot(mdl);
checkpoint=fullfile(root,'.build','timing_events_validation_checkpoint.json');
if strcmp(phase,'default')
 report=struct('all_passed',false,'matlab_version',version,'model_sha256',teach_hash(fullfile(root,[mdl '.slx'])), ...
  'reference_manifest_sha256',teach_hash(fullfile(here,'reference_v1','manifest.json')),'run_folders',struct,'checks',struct);
else
 report=jsondecode(fileread(checkpoint));assert(~report.all_passed);r=pmsm_experiment_verify(report.run_folders.default_pair);
 assert(strcmp(report.model_sha256,teach_hash(fullfile(root,[mdl '.slx'])))&&strcmp(report.reference_manifest_sha256,teach_hash(fullfile(here,'reference_v1','manifest.json'))));
 for file=r.source_files(:)',assert(strcmp(teach_hash(fullfile(here,file.path)),file.sha256),'阶段间运行脚本已改变。');end
end
switch phase
 case 'default'
  for name={'pmsm_experiment_plan','run_pmsm_experiment','plot_pmsm_timing_events','pmsm_timing_events_analysis','pmsm_render_timing_events_run','pmsm_experiment_verify','open_pmsm_experiments','export_pmsm_experiment_examples','validate_pmsm_timing_events'}
   issues=checkcode(fullfile(here,[name{1} '.m']),'-id');assert(~any(strcmp({issues.id},'PARSE')),'语法错误：%s',name{1});
  end
  catalog=pmsm_experiment_catalog;assert(numel(catalog)>=12);plan=pmsm_experiment_plan('timing_events');assert(plan.duration_s==.05&&plan.value==5);
  a=plan.cases(1).configuration.rows;b=plan.cases(2).configuration.rows;different=arrayfun(@(k)~isequaln(a(k),b(k)),1:numel(a));assert(sum(different)==1&&strcmp(a(different).key,'real_on'));
  assert(isempty(pmsm_check_switches(plan.cases(1).configuration))&&isequal(pmsm_check_switches(plan.cases(2).configuration),{'时序设置.real_on'}));
  report.checks.only_real_mode_switch_differs_in_configuration=true;
  invalid={0,-1,.1,20.0625,[1 2],NaN,Inf,'1+4'};
  for k=1:numel(invalid),rejected=false;try,pmsm_experiment_plan('timing_events',invalid{k});catch,rejected=true;end;assert(rejected);end
  report.checks.invalid_inputs_rejected=numel(invalid);
  for key={'pwm_on','delay_on'}
   config=plan.cases(2).configuration;section='时序设置';if strcmp(key{1},'delay_on'),section='采样设置';end
   ix=strcmp({config.rows.section},section)&strcmp({config.rows.key},key{1});config.rows(ix).value='on';
   rejected=false;try,pmsm_check_switches(config);catch,rejected=true;end;assert(rejected);
  end
  report.checks.legacy_delays_rejected_with_real_mode=true;
  fprintf('TIMING_EVENTS_GUI_DEFAULT\n');f=open_pmsm_experiments;fg=onCleanup(@()close(f));selector=findall(f,'Tag','ExperimentSelector');selector.Value=10;cb=selector.Callback;cb(selector,[]);
  cutoff=findall(f,'Tag','ExperimentFilterHz');assert(strcmp(cutoff.Visible,'off'));status=findall(f,'Tag','ExperimentStatus');assert(contains(status.String,'0.05'));
  button=findall(f,'Tag','ExperimentRun');cb=button.Callback;cb(button,[]);r=f.UserData;assert(isstruct(r),'窗口实验失败：%s',status.String);
  assert(strcmp(r.scenario.id,'timing_events')&&r.duration_s==.05&&numel(r.cases)==2);pmsm_experiment_verify(r.folder);report.run_folders.default_pair=r.folder;
  outputs=loadCases(r);for k=1:2,assert(numel(fieldnames(outputs{k}))==24);end
  timing=jsondecode(fileread(fullfile(r.folder,'timing.json')));report.timing=timing;report.metrics=r.cases;
  assert(abs(timing.jeos_phase_s-28.875e-6)<1e-12&&abs(timing.write_phase_s-33.875e-6)<1e-12&&abs(timing.jeos_to_apply_us-21.125)<1e-8);
  assert(timing.paired_command_count>=2&&max(timing.sample_error_max_ABC_A)<1e-8&&timing.applied_command_max_error_s<1e-14);
  assert(abs(outputs{2}.log_speed.Time(1)-28.875e-6)<1e-12&&outputs{1}.log_speed.Time(1)==0);
  events=readtable(fullfile(r.folder,'events.csv'),'Encoding','UTF-8');assert(height(events)==numel(timing.events));
  report.checks.events_adc_truth_and_applied_command_match=true;report.checks.task_phase_distinct_from_ideal_log_time=true;
  historical=jsondecode(fileread(fullfile(here,'experiment_validation.json')));oldPack=pmsm_experiment_verify(historical.run_folders.zero_bias);
  u=load(fullfile(oldPack.folder,'reference.mat'),'signals');report.historical_current_clock_max_difference_s=sameArchivedWindow(u.signals,outputs{1});report.checks.simplified_mode_historical_16_signal_values_preserved=true;
  mechanism=findall(f,'Tag','ExperimentMechanism');assert(strcmp(mechanism.Enable,'on'));figs=findall(groot,'Type','figure');cb=mechanism.Callback;cb(mechanism,[]);
  extra=setdiff(findall(groot,'Type','figure'),figs);assert(numel(extra)==1);close(extra);
  value=findall(f,'Tag','ExperimentValue');value.String='10';cb=value.Callback;cb(value,[]);assert(isempty(f.UserData)&&strcmp(mechanism.Enable,'off'));
  report.checks.gui_run_event_page_and_stale_clear=true;clear fg;
 case 'repeat'
  fprintf('TIMING_EVENTS_REPEAT\n');[again,v]=repeat_pmsm_experiment(r.folder);assert(v.same_matlab_version&&v.all_exact&&numel(v.signals)==48);
  report.run_folders.repeated_pair=again.folder;report.checks.default_all_48_signals_repeated=true;
 case 'parameters'
  assert(report.checks.default_all_48_signals_repeated);
  fprintf('TIMING_EVENTS_COMPILED_TASKS\n');set_param([mdl '/时序设置'],'real_on','on');set_param(mdl,'SimulationCommand','update');feval(mdl,[],[],[],'compile');
  report.compiled=struct;
  try
   for row={'442','current',50e-6,28.875e-6;'438','speed',100e-6,78.875e-6;'240','svpwm',50e-6,28.875e-6}'
    handle=Simulink.ID.getHandle([mdl ':' row{1}]);st=get_param(handle,'CompiledSampleTime');if iscell(st),st=vertcat(st{:});end
    assert(all(abs(st(:,1)-row{3})<1e-12)&&all(abs(st(:,2)-row{4})<1e-12));report.compiled.(row{2})=struct('path',getfullname(handle),'sample_time',st);
   end
  catch err,feval(mdl,[],[],[],'term');rethrow(err);end
  feval(mdl,[],[],[],'term');pmsm_reference('restore');report.checks.compiled_current_speed_svpwm_periods_and_offsets=true;
  fprintf('TIMING_EVENTS_PARAMETER_CHANGE\n');[custom,o]=run_pmsm_experiment('timing_events',10);report.run_folders.custom_pair=custom.folder;
  t=jsondecode(fileread(fullfile(custom.folder,'timing.json')));assert(abs(t.write_phase_s-38.875e-6)<1e-12&&t.compute_us==10&&abs(t.jeos_to_apply_us-21.125)<1e-8);
  original=load(fullfile(r.folder,'factor.mat'),'signals');sameSignal(original.signals.log_Tcm_applied,o{2}.log_Tcm_applied);
  report.checks.compute_parameter_moves_write_but_same_update_boundary=true;report.custom_timing=t;
 case 'finish'
  assert(report.checks.default_all_48_signals_repeated&&report.checks.compute_parameter_moves_write_but_same_update_boundary);
  fprintf('TIMING_EVENTS_LEGACY_REGRESSION\n');[legacy,o]=run_pmsm_experiment('current_bias');report.run_folders.legacy_bias=legacy.folder;
  history=jsondecode(fileread(fullfile(here,'experiment_reproducibility_validation.json')));oldPack=pmsm_experiment_verify(history.run_folders.current_bias);oldSignals=loadCases(oldPack);
  for k=1:2,sameAll(oldSignals{k},o{k});end;report.checks.legacy_two_case_21_signals_preserved=true;
  tamper=fullfile(work,'tampered_events');copyfile(r.folder,tamper);fid=fopen(fullfile(tamper,'events.csv'),'a');fwrite(fid,uint8(0));fclose(fid);
  rejected=false;try,pmsm_experiment_verify(tamper);catch,rejected=true;end;assert(rejected);report.checks.event_file_tamper_rejected=true;
end
assert(isequaln(before,pmsm_reference('capture'))&&isequaln(geometry,teach_snapshot(mdl)));pmsm_reference('verify');
assert(strcmp(report.model_sha256,teach_hash(fullfile(root,[mdl '.slx']))));report.checks.main_reference_pi_layout_unchanged=true;
if strcmp(phase,'finish')
 report.all_passed=true;teach_writejson(fullfile(here,'experiment_timing_events_validation.json'),report);fprintf('TIMING_EVENTS_ALL_PASS\n');
else
 teach_writejson(checkpoint,report);fprintf('TIMING_EVENTS_PHASE_PASS %s\n',phase);
end
end
function outputs=loadCases(r)
outputs=cell(1,numel(r.cases));for k=1:numel(r.cases),u=load(fullfile(r.folder,[r.cases(k).id '.mat']),'signals');outputs{k}=u.signals;end
end
function clockMax=sameArchivedWindow(archived,actual)
clockMax=0;
for name=fieldnames(archived)'
 x=archived.(name{1});y=actual.(name{1});
 if strcmp(name{1},'obs_current_fast')
  % Changing the logger expression T -> timing_h changes the last time bit,
  % although both evaluate to 1us. Match grid samples without interpolation.
  [found,where]=ismember(round(y.Time/1e-6),round(x.Time/1e-6));assert(all(found));
  clockMax=max(abs(x.Time(where)-y.Time));assert(clockMax<1e-14);
 else
  [found,where]=ismember(y.Time,x.Time);assert(all(found),'原参考未覆盖：%s',name{1});
 end
 a=teach_values(x);b=teach_values(y);assert(isequaln(a(where,:),b),'简化模式变化：%s',name{1});
end
end
function sameAll(a,b)
assert(isequal(sort(fieldnames(a)),sort(fieldnames(b))));for name=fieldnames(a)',sameSignal(a.(name{1}),b.(name{1}));end
end
function sameSignal(a,b)
assert(isequaln(a.Time,b.Time)&&isequaln(a.Data,b.Data));
end
