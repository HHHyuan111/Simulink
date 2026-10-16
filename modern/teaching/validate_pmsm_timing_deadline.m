function report=validate_pmsm_timing_deadline(phase)
% Isolated integration/replay acceptance for the eleventh fixed experiment.
here=fileparts(mfilename('fullpath'));root=fileparts(here);
if nargin<1
 executable=fullfile(matlabroot,'bin','matlab.exe');q=strrep(here,'''','''''');
 for part={'default','repeat','parameters','finish'}
  command=sprintf('"%s" -batch "addpath(''%s''); validate_pmsm_timing_deadline(''%s'')"',executable,q,part{1});
  [status,output]=system(command);fprintf('%s',output);assert(status==0,'更新边界验收阶段失败：%s',part{1});
 end
 report=jsondecode(fileread(fullfile(here,'experiment_timing_deadline_validation.json')));assert(report.all_passed);return
end
assert(ismember(phase,{'default','repeat','parameters','finish'}));mdl='PMSM_FOC_R2026a';assert(~bdIsLoaded(mdl));
work=fullfile(root,'.build',['deadline_check_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);mkdir(work);
old=pwd;cg=onCleanup(@()cd(old));cd(work);addpath(here);copyfile(fullfile(root,[mdl '.slx']),fullfile(work,[mdl '.slx']));
load_system(fullfile(work,[mdl '.slx']));mg=onCleanup(@()close_system(mdl,0));pmsm_reference('restore');before=pmsm_reference('capture');geometry=teach_snapshot(mdl);
checkpoint=fullfile(root,'.build','timing_deadline_validation_checkpoint.json');
if strcmp(phase,'default')
 report=struct('all_passed',false,'matlab_version',version,'model_sha256',teach_hash(fullfile(root,[mdl '.slx'])), ...
  'reference_manifest_sha256',teach_hash(fullfile(here,'reference_v1','manifest.json')),'run_folders',struct,'checks',struct);
else
 report=jsondecode(fileread(checkpoint));assert(~report.all_passed);r=pmsm_experiment_verify(report.run_folders.default_three);
 assert(strcmp(report.model_sha256,teach_hash(fullfile(root,[mdl '.slx'])))&&strcmp(report.reference_manifest_sha256,teach_hash(fullfile(here,'reference_v1','manifest.json'))));
 for file=r.source_files(:)',assert(strcmp(teach_hash(fullfile(here,file.path)),file.sha256),'阶段间运行脚本已改变。');end
end
switch phase
 case 'default'
  for file={'pmsm_experiment_catalog','pmsm_experiment_plan','run_pmsm_experiment','pmsm_timing_deadline_analysis','plot_pmsm_timing_deadline','pmsm_render_timing_deadline_run','pmsm_experiment_verify','open_pmsm_experiments','export_pmsm_experiment_examples','validate_pmsm_timing_deadline'}
   issues=checkcode(fullfile(here,[file{1} '.m']),'-id');assert(~any(strcmp({issues.id},'PARSE')),'语法错误：%s',file{1});
  end
  catalog=pmsm_experiment_catalog;assert(numel(catalog)>=12);p=pmsm_experiment_plan('timing_deadline');assert(p.duration_s==.05&&isequal(p.value,[5 10.5 11]));
  column=pmsm_experiment_plan('timing_deadline',[5;10.5;11]);assert(isequaln(p,column));
  for k=1:3
   assert(isequal(pmsm_check_switches(p.cases(k).configuration),{'时序设置.real_on'}));
   rows=p.cases(k).configuration.rows;
   assert(strcmp(rows(strcmp({rows.key},'trigger_us')).value,'10')&&strcmp(rows(strcmp({rows.key},'sync_us')).value,'0'));
   if k>1
    a=p.cases(1).configuration.rows;different=arrayfun(@(j)~isequaln(a(j),rows(j)),1:numel(a));assert(sum(different)==1&&strcmp(a(different).key,'compute_us'));
   end
  end
  report.checks.only_compute_differs_across_same_architecture_cases=true;
  invalid={0,[5 10 11],[10.5 10.5 11],[5 10.5 10.5],[5 10.5 20.0625],[5.1 10.5 11],[NaN 10.5 11],[5 Inf 11],'5+1 10.5 11'};
  for k=1:numel(invalid),rejected=false;try,pmsm_experiment_plan('timing_deadline',invalid{k});catch,rejected=true;end;assert(rejected);end
  report.checks.invalid_inputs_rejected=numel(invalid);
  f=open_pmsm_experiments;fg=onCleanup(@()close(f));selector=findall(f,'Tag','ExperimentSelector');selector.Value=11;cb=selector.Callback;cb(selector,[]);
  status=findall(f,'Tag','ExperimentStatus');assert(contains(status.String,'0.05'));button=findall(f,'Tag','ExperimentRun');cb=button.Callback;cb(button,[]);
  r=f.UserData;assert(isstruct(r),'窗口实验失败：%s',status.String);pmsm_experiment_verify(r.folder);report.run_folders.default_three=r.folder;
  assert(numel(r.cases)==3&&strcmp(r.scenario.id,'timing_deadline'));o=loadCases(r);
  for k=1:3,assert(numel(fieldnames(o{k}))==24);end
  d=jsondecode(fileread(fullfile(r.folder,'deadline.json')));assert(max(abs([d.cases.write_phase_us]-[19.5 25 25.5]))<1e-8);
  assert(max(abs([d.cases.apply_phase_us]-[25 50 50]))<1e-8&&max(abs([d.cases.jeos_to_apply_us]-[10.5 35.5 35.5]))<1e-8);
  assert(d.cases(2).coincident_write_count>=2&&all([d.cases.applied_command_max_error_s]<1e-14));
  assert(isequal(o{2}.log_Tcm_applied.Time,o{3}.log_Tcm_applied.Time)&&isequal(o{2}.log_Tcm_applied.Data,o{3}.log_Tcm_applied.Data));
  assert(~isequal(o{1}.log_Tcm_applied.Data,o{2}.log_Tcm_applied.Data));
  events=readtable(fullfile(r.folder,'events.csv'),'Encoding','UTF-8');assert(height(events)==numel(d.events));
  report.deadline=d;report.metrics=r.cases;report.checks.events_adc_truth_actual_output_and_same_tick_order=true;
  report.checks.boundary_and_late_outputs_equal_but_early_differs=true;
  mechanism=findall(f,'Tag','ExperimentMechanism');assert(strcmp(mechanism.Enable,'on'));figs=findall(groot,'Type','figure');cb=mechanism.Callback;cb(mechanism,[]);
  extra=setdiff(findall(groot,'Type','figure'),figs);assert(numel(extra)==1);close(extra);
  value=findall(f,'Tag','ExperimentValue');value.String='[4 10.5 12]';cb=value.Callback;cb(value,[]);assert(isempty(f.UserData)&&strcmp(mechanism.Enable,'off'));
  report.checks.gui_three_case_run_page_and_stale_clear=true;clear fg;
 case 'repeat'
  [again,v]=repeat_pmsm_experiment(r.folder);assert(v.same_matlab_version&&v.all_exact&&numel(v.signals)==72);
  report.run_folders.repeated_three=again.folder;report.checks.default_all_72_signals_repeated=true;
 case 'parameters'
  assert(report.checks.default_all_72_signals_repeated);
  set_param([mdl '/时序设置'],'real_on','on','trigger_us','10');set_param(mdl,'SimulationCommand','update');feval(mdl,[],[],[],'compile');
  report.compiled=struct;
  try
   for row={'442','current',50e-6,14.5e-6;'438','speed',100e-6,64.5e-6;'240','svpwm',50e-6,14.5e-6}'
    block=Simulink.ID.getHandle([mdl ':' row{1}]);st=get_param(block,'CompiledSampleTime');if iscell(st),st=vertcat(st{:});end
    assert(all(abs(st(:,1)-row{3})<1e-12)&&all(abs(st(:,2)-row{4})<1e-12));report.compiled.(row{2})=struct('path',getfullname(block),'sample_time',st);
   end
  catch err,feval(mdl,[],[],[],'term');rethrow(err);end
  feval(mdl,[],[],[],'term');pmsm_reference('restore');report.checks.compiled_task_periods_and_offsets=true;
  custom=run_pmsm_experiment('timing_deadline',[4 10.5 12]);report.run_folders.custom_three=custom.folder;
  d=jsondecode(fileread(fullfile(custom.folder,'deadline.json')));assert(max(abs([d.cases.write_phase_us]-[18.5 25 26.5]))<1e-8&&max(abs([d.cases.apply_phase_us]-[25 50 50]))<1e-8);
  report.checks.edited_compute_values_move_actual_write_events=true;
 case 'finish'
  assert(report.checks.default_all_72_signals_repeated&&report.checks.edited_compute_values_move_actual_write_events);
  [legacy,o]=run_pmsm_experiment('current_bias');report.run_folders.legacy_bias=legacy.folder;
  history=jsondecode(fileread(fullfile(here,'experiment_reproducibility_validation.json')));oldPack=pmsm_experiment_verify(history.run_folders.current_bias);oldSignals=loadCases(oldPack);
  for k=1:2,sameAll(oldSignals{k},o{k});end;report.checks.legacy_two_case_21_signals_preserved=true;
  previous=jsondecode(fileread(fullfile(here,'experiment_timing_events_validation.json')));previousPack=pmsm_experiment_verify(previous.run_folders.default_pair);
  oldPlan=jsondecode(fileread(fullfile(previousPack.folder,'plan.json')));oldOutputs=loadCases(previousPack);
  target=fullfile(work,'previous_timing');mkdir(target);plot_pmsm_timing_events(oldOutputs,oldPlan,target);
  oldAnalysis=jsondecode(fileread(fullfile(previousPack.folder,'timing.json')));derived=jsondecode(fileread(fullfile(target,'timing.json')));assert(isequaln(oldAnalysis,derived));
  report.checks.previous_timing_archive_analysis_preserved=true;
  tamper=fullfile(work,'tampered_events');copyfile(r.folder,tamper);fid=fopen(fullfile(tamper,'events.csv'),'a');fwrite(fid,uint8(0));fclose(fid);
  rejected=false;try,pmsm_experiment_verify(tamper);catch,rejected=true;end;assert(rejected);report.checks.event_file_tamper_rejected=true;
end
assert(isequaln(before,pmsm_reference('capture'))&&isequaln(geometry,teach_snapshot(mdl)));pmsm_reference('verify');
assert(strcmp(report.model_sha256,teach_hash(fullfile(root,[mdl '.slx']))));report.checks.main_reference_pi_layout_unchanged=true;
if strcmp(phase,'finish')
 report.all_passed=true;teach_writejson(fullfile(here,'experiment_timing_deadline_validation.json'),report);fprintf('TIMING_DEADLINE_ALL_PASS\n');
else
 teach_writejson(checkpoint,report);fprintf('TIMING_DEADLINE_PHASE_PASS %s\n',phase);
end
end
function o=loadCases(r)
o=cell(1,numel(r.cases));for k=1:numel(r.cases),u=load(fullfile(r.folder,[r.cases(k).id '.mat']),'signals');o{k}=u.signals;end
end
function sameAll(a,b)
assert(isequal(sort(fieldnames(a)),sort(fieldnames(b))));
for name=fieldnames(a)',x=a.(name{1});y=b.(name{1});assert(isequaln(x.Time,y.Time)&&isequaln(x.Data,y.Data),'旧实验改变：%s',name{1});end
end
