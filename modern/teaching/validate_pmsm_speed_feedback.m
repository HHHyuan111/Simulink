function report=validate_pmsm_speed_feedback(phase)
here=fileparts(mfilename('fullpath'));root=fileparts(here);mdl='PMSM_FOC_R2026a';
if nargin<1
 for part={'default','repeat','parameters','finish'}
  command=sprintf('"%s" -batch "addpath(''%s''); validate_pmsm_speed_feedback(''%s'')"',fullfile(matlabroot,'bin','matlab.exe'),strrep(here,'''',''''''),part{1});
  [status,output]=system(command);fprintf('%s',output);assert(status==0,'测速反馈验收失败：%s',part{1});
 end
 report=jsondecode(fileread(fullfile(here,'experiment_speed_feedback_validation.json')));return
end
assert(ismember(phase,{'default','repeat','parameters','finish'})&&~bdIsLoaded(mdl));
work=fullfile(root,'.build',['speed_feedback_check_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);mkdir(work);
old=pwd;cg=onCleanup(@()cd(old));cd(work);addpath(here);copyfile(fullfile(root,[mdl '.slx']),fullfile(work,[mdl '.slx']));
load_system(fullfile(work,[mdl '.slx']));mg=onCleanup(@()close_system(mdl,0));pmsm_reference('restore');before=pmsm_reference('capture');geometry=teach_snapshot(mdl);
checkpoint=fullfile(root,'.build','speed_feedback_validation_checkpoint.json');
if strcmp(phase,'default')
 report=struct('all_passed',false,'matlab_version',version,'model_sha256',teach_hash(fullfile(root,[mdl '.slx'])), ...
  'reference_manifest_sha256',teach_hash(fullfile(here,'reference_v1','manifest.json')),'checks',struct,'run_folders',struct);
else
 report=jsondecode(fileread(checkpoint));assert(~report.all_passed);r=pmsm_experiment_verify(report.run_folders.default_three);
 for file=r.source_files(:)',assert(strcmp(teach_hash(fullfile(here,file.path)),file.sha256),'阶段间源码改变：%s',file.path);end
end
switch phase
 case 'default'
  for name={'pmsm_speed_feedback_model','pmsm_speed_feedback_view','pmsm_speed_feedback_analysis','plot_pmsm_speed_feedback','pmsm_render_speed_feedback_run','run_pmsm_experiment','open_pmsm_experiments','validate_pmsm_speed_feedback'}
   issues=checkcode(fullfile(here,[name{1} '.m']),'-id');assert(~any(strcmp({issues.id},'PARSE')));
  end
  pmsm_encoder_model('install',mdl);pmsm_encoder_speed_model('install',mdl);original=teach_snapshot(mdl);pmsm_speed_feedback_model('install',mdl);extended=teach_snapshot(mdl);
  for b=original.blocks(:)'
   ix=strcmp({extended.blocks.path},b.path);assert(sum(ix)==1);next=extended.blocks(ix);
   if strcmp(b.sid,[mdl ':190']),assert(isequaln(rmfield(b,'inputs'),rmfield(next,'inputs')));else,assert(isequaln(b,next));end
  end
  report.checks.only_original_speed_hold_input_rewired=true;report.fixtures=fixtures(mdl);
  set_param([mdl '/时序设置'],'real_on','on');feval(mdl,[],[],[],'compile');
  try
   hold=get_param(Simulink.ID.getHandle([mdl ':190']),'CompiledSampleTime');if iscell(hold),hold=vertcat(hold{:});end
   history=get_param([mdl '/角度设置/编码器/测速/窗口/窗口历史'],'CompiledSampleTime');if iscell(history),history=vertcat(history{:});end
   assert(all(abs(hold(:,1)-100e-6)<1e-12)&&all(abs(hold(:,2)-78.875e-6)<1e-12));
   assert(all(abs(history(:,1)-50e-6)<1e-12)&&all(abs(history(:,2)-28.875e-6)<1e-12));report.compiled=struct('speed_hold',hold,'count_history',history);
  catch err,feval(mdl,[],[],[],'term');rethrow(err);end
  feval(mdl,[],[],[],'term');pmsm_speed_feedback_model('remove',mdl);set_param([mdl '/时序设置'],'real_on','off');
  assert(isequaln(original,teach_snapshot(mdl)));pmsm_encoder_model('remove',mdl);pmsm_reference('restore');assert(isequaln(geometry,teach_snapshot(mdl)));
  report.checks.remove_restores_graph_and_compiled_rates=true;
  p=pmsm_experiment_plan('speed_feedback');assert(numel(p.cases)==3&&isequal(p.value,[10000 2 8])&&p.duration_s==.05);
  assert(isequal([p.feedback_configurations.window_choice],['2' '2' '3'])&&strcmp(p.comparison_contract.speed_filter,'off'));
  for bad={[10000 2 2],[10000 2.5 8],[10000 8 9],[10000 2 33],[19 2 8],[10000 1 8]}
   rejected=false;try,pmsm_experiment_plan('speed_feedback',bad{1});catch,rejected=true;end;assert(rejected);
  end
  report.checks.invalid_inputs_rejected=true;
  f=open_pmsm_experiments;fg=onCleanup(@()close(f));catalog=pmsm_experiment_catalog;assert(numel(catalog)>=15);
  sel=findall(f,'Tag','ExperimentSelector');sel.Value=find(strcmp({catalog.id},'speed_feedback'));cb=sel.Callback;cb(sel,[]);
  value=findall(f,'Tag','ExperimentValue');window=findall(f,'Tag','ExperimentFilterHz');long=findall(f,'Tag','ExperimentEncoderZero');
  assert(str2double(value.String)==10000&&str2double(window.String)==2&&str2double(long.String)==8);
  preview=findall(f,'Tag','ExperimentStartup');cb=preview.Callback;cb(preview,[]);assert(pmsm_speed_feedback_model('installed',mdl));
  restore=findall(f,'Tag','ExperimentRestore');cb=restore.Callback;cb(restore,[]);assert(~pmsm_encoder_model('installed',mdl)&&isequaln(geometry,teach_snapshot(mdl)));
  button=findall(f,'Tag','ExperimentRun');cb=button.Callback;cb(button,[]);r=f.UserData;status=findall(f,'Tag','ExperimentStatus');assert(isstruct(r),'实验失败：%s',status.String);
  pmsm_experiment_verify(r.folder);assert(numel(r.cases)==3&&all(arrayfun(@(z)numel(z.retained_signals)==32,r.cases)));report.run_folders.default_three=r.folder;
  report.feedback=jsondecode(fileread(fullfile(r.folder,'feedback.json')));assert(isequal([report.feedback.cases.invalid_speed_task_samples],[1 1 4]));
  report.checks.actual_count_window_and_pi_input_provenance=true;
  oldReport=jsondecode(fileread(fullfile(here,'experiment_encoder_speed_validation.json')));oldPack=pmsm_experiment_verify(oldReport.run_folders.default_parallel);
  a=load(fullfile(oldPack.folder,'reference.mat'),'signals');b=load(fullfile(r.folder,'reference.mat'),'signals');report.old_shadow_comparison=compare(a.signals,b.signals,fieldnames(a.signals));report.checks.bypass_matches_previous_31_signals=true;
  mechanism=findall(f,'Tag','ExperimentMechanism');figures=findall(groot,'Type','figure');cb=mechanism.Callback;cb(mechanism,[]);extra=setdiff(findall(groot,'Type','figure'),figures);assert(numel(extra)==1);close(extra);
  long.String='12';cb=long.Callback;cb(long,[]);assert(isempty(f.UserData)&&strcmp(mechanism.Enable,'off'));
  sel.Value=find(strcmp({catalog.id},'encoder_speed'));cb=sel.Callback;cb(sel,[]);assert(contains(findall(f,'Tag','ExperimentRun').String,'并行观测'));
  report.checks.gui_preview_restore_run_report_and_stale_clear=true;clear fg;
 case 'repeat'
  [again,v]=repeat_pmsm_experiment(r.folder);assert(v.all_exact&&v.same_matlab_version&&numel(v.signals)==96);report.run_folders.repeated_three=again.folder;report.checks.all_96_signals_strictly_repeated=true;
 case 'parameters'
  [custom,o]=run_pmsm_experiment('speed_feedback',[5000 3 12],.1);report.run_folders.custom_three=custom.folder;report.custom_feedback=jsondecode(fileread(fullfile(custom.folder,'feedback.json')));
  assert(isequal([report.custom_feedback.cases.window_ticks],[3 3 12]));
  d=load(fullfile(r.folder,'reference.mat'),'signals');names=setdiff(fieldnames(d.signals),{'log_encoder','log_speed_short','log_speed_window','log_speed_long','log_speed_feedback','obs_current_fast','obs_dead_requested','obs_dead_gates','obs_adc_timing','obs_pwm_timing','log_Tcm_applied'});
  report.custom_bypass_prefix=comparePrefix(d.signals,o{1},names);report.checks.custom_counts_windows_and_ideal_bypass_physics=true;
  [again,v]=repeat_pmsm_experiment(custom.folder);assert(v.all_exact&&v.same_matlab_version&&numel(v.signals)==96);report.run_folders.repeated_custom_three=again.folder;report.checks.custom_100ms_96_signals_strictly_repeated=true;
 case 'finish'
  history=jsondecode(fileread(fullfile(here,'experiment_encoder_speed_validation.json')));[legacy,v]=repeat_pmsm_experiment(history.run_folders.default_parallel);assert(v.all_exact&&numel(v.signals)==31);
  report.run_folders.legacy_shadow=legacy.folder;report.checks.previous_shadow_31_signals_strictly_preserved=true;
  oldPack=pmsm_experiment_verify(history.run_folders.default_parallel);d=load(fullfile(oldPack.folder,'reference.mat'),'signals');p=jsondecode(fileread(fullfile(oldPack.folder,'plan.json')));a=pmsm_encoder_speed_analysis({d.signals},p);
  file=fullfile(work,'old_speed.json');teach_writejson(file,a);assert(isequaln(jsondecode(fileread(file)),jsondecode(fileread(fullfile(oldPack.folder,'speed.json')))));report.checks.old_shadow_analysis_unchanged=true;
  target=fullfile(work,'tampered');copyfile(r.folder,target);fid=fopen(fullfile(target,'feedback_samples.csv'),'a');fwrite(fid,uint8(0));fclose(fid);
  rejected=false;try,pmsm_experiment_verify(target);catch,rejected=true;end;assert(rejected);report.checks.tampered_feedback_samples_rejected=true;
end
assert(~pmsm_encoder_model('installed',mdl)&&isequaln(before,pmsm_reference('capture'))&&isequaln(geometry,teach_snapshot(mdl)));pmsm_reference('verify');
assert(strcmp(report.model_sha256,teach_hash(fullfile(root,[mdl '.slx']))));report.checks.main_reference_pi_and_layout_unchanged=true;
if strcmp(phase,'finish')
 assert(report.checks.all_96_signals_strictly_repeated&&report.checks.custom_counts_windows_and_ideal_bypass_physics&&report.checks.custom_100ms_96_signals_strictly_repeated);report.all_passed=true;
 teach_writejson(fullfile(here,'experiment_speed_feedback_validation.json'),report);fprintf('SPEED_FEEDBACK_ALL_PASS\n');
else,teach_writejson(checkpoint,report);fprintf('SPEED_FEEDBACK_PHASE_PASS %s\n',phase);end
end
function checks=comparePrefix(a,b,names)
checks=struct('signal',{},'matched_original_samples',{},'exact_time',{},'exact_data',{});
for name=names'
 x=a.(name{1});y=b.(name{1});[found,at]=ismember(x.Time,y.Time);assert(all(found));vx=teach_values(x);vy=teach_values(y);assert(isequaln(vx,vy(at,:)),'旁路前50ms物理数据改变：%s',name{1});
 checks(end+1)=struct('signal',name{1},'matched_original_samples',numel(x.Time),'exact_time',true,'exact_data',true);
end
end
function result=fixtures(mdl)
name='speed_feedback_fixture';new_system(name);guard=onCleanup(@()close_system(name,0));path=[name '/选择'];add_block([mdl '/速度反馈'],path);
dt=50e-6;t=(0:30)'*dt;ws=get_param(name,'ModelWorkspace');assignin(ws,'timing_speed_sample',[2*dt dt]);
for k=1:3
 valid=ones(size(t));valid(1:k)=0;valid(16)=0;speed=(-1)^k*k*111*ones(size(t));pack=[speed valid zeros(size(t)) ones(size(t))*k*dt t-k*dt t zeros(size(t))];
 assignin(ws,['packet' num2str(k)],[t pack]);add_block('simulink/Sources/From Workspace',[name '/包' num2str(k)],'VariableName',['packet' num2str(k)],'SampleTime',num2str(dt,17),'Interpolate','off','OutputAfterFinalValue','Holding final value');
 add_block('simulink/Signal Routing/Goto',[name '/发送' num2str(k)],'GotoTag',['speed_candidate_' num2str(k)],'TagVisibility','global');add_line(name,['包' num2str(k) '/1'],['发送' num2str(k) '/1']);
end
add_block('simulink/Sources/Constant',[name '/真值'],'Value','777');add_line(name,'真值/1','选择/1');
add_block(Simulink.ID.getHandle([mdl ':190']),[name '/原保持']);add_line(name,'选择/1','原保持/1');
add_block('simulink/Sinks/To Workspace',[name '/实际'],'VariableName','fixture_pi','SaveFormat','Timeseries','SampleTime','timing_speed_sample');add_line(name,'原保持/1','实际/1');
set_param(name,'SolverType','Fixed-step','Solver','FixedStepDiscrete','FixedStep','1e-6','StopTime',num2str(t(end),17));
for choice=1:3
 for state={'off','on'}
  set_param(path,'window_choice',num2str(choice),'feedback_on',state{1});out=sim(Simulink.SimulationInput(name));a=teach_values(out.get('log_speed_feedback'));piInput=teach_values(out.get('fixture_pi'));
  expected=777*ones(size(piInput));if strcmp(state{1},'on'),expected=a(:,1);expected(a(:,2)<.5)=0;assert(any(a(:,2)<.5)&&all(piInput(a(:,2)<.5)==0));end
  assert(isequal(expected,piInput)&&isequal(piInput,a(:,6))&&all(a(:,4)==choice));
 end
end
result=struct('all_three_window_choices_and_reverse_values',true,'off_is_exact_truth_bypass',true,'invalid_is_zero_without_truth_fallback',true,'original_speed_hold_samples_selection',true);
end
function checks=compare(a,b,names)
checks=struct('signal',{},'same_time',{},'same_data',{},'same_time_grid',{});
for name=names'
 x=a.(name{1});y=b.(name{1});sameTime=isequaln(x.Time,y.Time);sameData=isequaln(x.Data,y.Data);assert(sameData,'信号数值改变：%s',name{1});grid=sameTime;
 if ~sameTime&&strcmp(name{1},'log_Tcm_applied'),h=62.5e-9;grid=isequal(round(x.Time/h),round(y.Time/h))&&max(abs(x.Time-y.Time))<1e-14;end
 assert(grid,'信号时刻改变：%s',name{1});checks(end+1)=struct('signal',name{1},'same_time',sameTime,'same_data',sameData,'same_time_grid',grid);
end
end
