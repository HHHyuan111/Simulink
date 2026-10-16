function report=validate_pmsm_sampling_window(phase)
% Acceptance of the twelfth experiment; keep simulation phases isolated.
here=fileparts(mfilename('fullpath'));root=fileparts(here);
if nargin<1
 executable=fullfile(matlabroot,'bin','matlab.exe');q=strrep(here,'''','''''');
 for part={'default','repeat','parameters','finish'}
  command=sprintf('"%s" -batch "addpath(''%s''); validate_pmsm_sampling_window(''%s'')"',executable,q,part{1});
  [status,output]=system(command);fprintf('%s',output);assert(status==0,'采样窗口验收阶段失败：%s',part{1});
 end
 report=jsondecode(fileread(fullfile(here,'experiment_sampling_window_validation.json')));assert(report.all_passed);return
end
assert(ismember(phase,{'default','repeat','parameters','finish'}));mdl='PMSM_FOC_R2026a';assert(~bdIsLoaded(mdl));
work=fullfile(root,'.build',['sampling_window_check_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);mkdir(work);
old=pwd;cg=onCleanup(@()cd(old));cd(work);addpath(here);copyfile(fullfile(root,[mdl '.slx']),fullfile(work,[mdl '.slx']));
load_system(fullfile(work,[mdl '.slx']));mg=onCleanup(@()close_system(mdl,0));pmsm_reference('restore');before=pmsm_reference('capture');geometry=teach_snapshot(mdl);
checkpoint=fullfile(root,'.build','sampling_window_validation_checkpoint.json');
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
  for file={'pmsm_experiment_catalog','pmsm_experiment_plan','run_pmsm_experiment','pmsm_sampling_window_analysis','plot_pmsm_sampling_window','pmsm_render_sampling_window_run','pmsm_experiment_verify','open_pmsm_experiments','export_pmsm_experiment_examples','validate_pmsm_sampling_window'}
   issues=checkcode(fullfile(here,[file{1} '.m']),'-id');assert(~any(strcmp({issues.id},'PARSE')),'语法错误：%s',file{1});
  end
  report.components=components(fullfile(root,'timing'));report.checks.whole_aperture_guard_initial_zero_and_past_sample_fixtures=true;
  catalog=pmsm_experiment_catalog;assert(numel(catalog)>=12);p=pmsm_experiment_plan('sampling_window');assert(p.duration_s==.05&&isequal(p.value,[31.25 .5]));
  column=pmsm_experiment_plan('sampling_window',[31.25;.5]);assert(isequaln(p,column));
  for k=1:3
   assert(numel(pmsm_check_switches(p.cases(k).configuration))==k);
   if k>1
    a=p.cases(k-1).configuration.rows;b=p.cases(k).configuration.rows;different=arrayfun(@(j)~isequaln(a(j),b(j)),1:numel(a));
    expected='window_on';if k==3,expected='invalid_hold_on';end
    assert(sum(different)==1&&strcmp(a(different).key,expected));
   end
  end
  report.checks.only_adjacent_window_or_hold_switch_differs=true;
  invalid={31.25,[40.5 .5],[31.25 -.0625],[31.25 .1],[31.25 10.0625],[NaN .5],[31.25 Inf],'31.25+1 .5'};
  for k=1:numel(invalid),rejected=false;try,pmsm_experiment_plan('sampling_window',invalid{k});catch,rejected=true;end;assert(rejected);end
  rejected=false;try,pmsm_experiment_plan('sampling_window',[],.10005);catch,rejected=true;end;assert(rejected);
  report.checks.invalid_inputs_rejected=numel(invalid)+1;
  for pair={'real_on','off';'window_on','off'}'
   config=p.cases(3).configuration;ix=strcmp({config.rows.section},'时序设置')&strcmp({config.rows.key},pair{1});config.rows(ix).value=pair{2};
   rejected=false;try,pmsm_check_switches(config);catch,rejected=true;end;assert(rejected);
  end
  report.checks.missing_real_or_window_dependency_rejected=true;
  f=open_pmsm_experiments;fg=onCleanup(@()close(f));selector=findall(f,'Tag','ExperimentSelector');selector.Value=12;cb=selector.Callback;cb(selector,[]);
  value=findall(f,'Tag','ExperimentValue');settle=findall(f,'Tag','ExperimentFilterHz');status=findall(f,'Tag','ExperimentStatus');
  assert(strcmp(settle.Visible,'on')&&str2double(value.String)==31.25&&str2double(settle.String)==.5&&contains(status.String,'0.05'));
  button=findall(f,'Tag','ExperimentRun');cb=button.Callback;cb(button,[]);r=f.UserData;assert(isstruct(r),'窗口实验失败：%s',status.String);
  pmsm_experiment_verify(r.folder);assert(numel(r.cases)==3&&strcmp(r.scenario.id,'sampling_window'));report.run_folders.default_three=r.folder;
  o=loadCases(r);for k=1:3,assert(numel(fieldnames(o{k}))==24&&numel(o{k}.obs_adc_timing.Time)==1000&&o{k}.obs_current_fast.Time(1)==0);end
  a=jsondecode(fileread(fullfile(r.folder,'window.json')));report.window=a;report.metrics=r.cases;
  assert(any(a.cases(2).invalid_count_ABC>0)&&any(a.cases(3).invalid_count_ABC>0));
  assert(all([a.cases.aperture_flag_mismatch_count]==0)&&all([a.cases.accepted_sample_max_error_A]<1e-8)&&all([a.cases.policy_max_error_A]<1e-12)&&all([a.cases.controller_path_max_error_A]<1e-10));
  samples=readtable(fullfile(r.folder,'samples.csv'),'Encoding','UTF-8');assert(height(samples)==3000);
  assert(any(a.cases(3).max_known_source_age_us_ABC>0));report.checks.full_apertures_adc_truth_history_and_controller_path_match=true;
  mechanism=findall(f,'Tag','ExperimentMechanism');assert(strcmp(mechanism.Enable,'on'));figs=findall(groot,'Type','figure');cb=mechanism.Callback;cb(mechanism,[]);
  extra=setdiff(findall(groot,'Type','figure'),figs);assert(numel(extra)==1);close(extra);
  settle.String='1';cb=settle.Callback;cb(settle,[]);assert(isempty(f.UserData)&&strcmp(mechanism.Enable,'off'));
  selector.Value=9;cb=selector.Callback;cb(selector,[]);assert(str2double(value.String)==.02&&str2double(settle.String)==1500);
  selector.Value=12;cb(selector,[]);assert(str2double(value.String)==31.25&&str2double(settle.String)==.5);
  report.checks.gui_two_inputs_page_stale_clear_and_scene_switch=true;clear fg;
 case 'repeat'
  [again,v]=repeat_pmsm_experiment(r.folder);assert(v.same_matlab_version&&v.all_exact&&numel(v.signals)==72);
  report.run_folders.repeated_three=again.folder;report.checks.default_all_72_signals_repeated=true;
 case 'parameters'
  assert(report.checks.default_all_72_signals_repeated);
  set_param([mdl '/时序设置'],'real_on','on','trigger_us','31.25');set_param(mdl,'SimulationCommand','update');feval(mdl,[],[],[],'compile');report.compiled=struct;
  try
   for row={'442','current',50e-6,35.75e-6;'438','speed',100e-6,85.75e-6;'240','svpwm',50e-6,35.75e-6}'
    block=Simulink.ID.getHandle([mdl ':' row{1}]);st=get_param(block,'CompiledSampleTime');if iscell(st),st=vertcat(st{:});end
    assert(all(abs(st(:,1)-row{3})<1e-12)&&all(abs(st(:,2)-row{4})<1e-12));report.compiled.(row{2})=struct('path',getfullname(block),'sample_time',st);
   end
  catch err,feval(mdl,[],[],[],'term');rethrow(err);end
  feval(mdl,[],[],[],'term');pmsm_reference('restore');report.checks.compiled_task_periods_and_offsets=true;
  [custom,o]=run_pmsm_experiment('sampling_window',[24.375 1]);report.run_folders.custom_three=custom.folder;
  a=jsondecode(fileread(fullfile(custom.folder,'window.json')));assert(a.trigger_us==24.375&&a.settle_us==1&&abs(a.jeos_phase_us-28.875)<1e-9);
  report.custom_window=a;report.checks.edited_trigger_and_settle_parameters_verified=true;
  assert(all(vertcat(a.cases.valid_fraction_full_ABC)==1,'all'));sameAll(o{1},o{2});sameAll(o{1},o{3});report.checks.all_valid_three_case_bypass_exact=true;
  oldIndex=jsondecode(fileread(fullfile(here,'experiment_timing_events_validation.json')));oldPack=pmsm_experiment_verify(oldIndex.run_folders.default_pair);
  u=load(fullfile(oldPack.folder,'factor.mat'),'signals');report.checks.normal_window_off_old_24_signals_match=compareTimingArchive(u.signals,o{1});
 case 'finish'
  assert(report.checks.default_all_72_signals_repeated&&report.checks.all_valid_three_case_bypass_exact);
  previous=jsondecode(fileread(fullfile(here,'experiment_timing_deadline_validation.json')));previousPack=pmsm_experiment_verify(previous.run_folders.default_three);
  oldPlan=jsondecode(fileread(fullfile(previousPack.folder,'plan.json')));oldOutputs=loadCases(previousPack);
  derived=pmsm_timing_deadline_analysis(oldOutputs,oldPlan);path=fullfile(work,'old_deadline.json');teach_writejson(path,derived);
  assert(isequaln(jsondecode(fileread(fullfile(previousPack.folder,'deadline.json'))),jsondecode(fileread(path))));report.checks.previous_deadline_archive_analysis_preserved=true;
  [legacy,o]=run_pmsm_experiment('current_bias');report.run_folders.legacy_bias=legacy.folder;
  history=jsondecode(fileread(fullfile(here,'experiment_reproducibility_validation.json')));oldPack=pmsm_experiment_verify(history.run_folders.current_bias);oldSignals=loadCases(oldPack);
  for k=1:2,sameAll(oldSignals{k},o{k});end;report.checks.legacy_two_case_21_signals_preserved=true;
  tamper=fullfile(work,'tampered_samples');copyfile(r.folder,tamper);fid=fopen(fullfile(tamper,'samples.csv'),'a');fwrite(fid,uint8(0));fclose(fid);
  rejected=false;try,pmsm_experiment_verify(tamper);catch,rejected=true;end;assert(rejected);report.checks.sample_file_tamper_rejected=true;
end
assert(isequaln(before,pmsm_reference('capture'))&&isequaln(geometry,teach_snapshot(mdl)));pmsm_reference('verify');
assert(strcmp(report.model_sha256,teach_hash(fullfile(root,[mdl '.slx']))));report.checks.main_reference_pi_layout_unchanged=true;
if strcmp(phase,'finish')
 report.all_passed=true;teach_writejson(fullfile(here,'experiment_sampling_window_validation.json'),report);fprintf('SAMPLING_WINDOW_ALL_PASS\n');
else
 teach_writejson(checkpoint,report);fprintf('SAMPLING_WINDOW_PHASE_PASS %s\n',phase);
end
end
function r=components(folder)
addpath(folder);h=62.5e-9;Ts=50e-6;tr=31.25e-6;rank=1.5e-6;ap=1.1875e-6;guard=.5e-6;N=round(Ts/h);time=(0:3*N)'*h;
cfg=[1 0 0 h Ts tr ap rank 0 guard 2];jphase=round((tr+3*rank)/h);startA=round((tr+2*rank)/h);startB=round((tr+rank)/h);startC=round(tr/h);
results=cell(1,3);diags=cell(1,3);
for mode=1:3
 clear timing_adc;cfg(2)=mode>=2;cfg(3)=mode==3;y=zeros(numel(time),3);d=zeros(numel(time),15);
 for i=1:numel(time)
  tick=i-1;cycle=floor(tick/N);phase=mod(tick,N);gate=[0 1 0 1 0 1];
  if cycle==0&&phase>=startB-1&&phase<=startB+round(ap/h)+1,gate(4)=0;end
  if cycle==1&&phase>=startC+4&&phase<=startC+7,gate(6)=0;end
  if cycle==2&&phase>=startC-1&&phase<=startC+round(ap/h)+1,gate(6)=0;end
  if cycle==2&&phase<startA-7,gate(2)=0;end
  current=[1 2 -3]*(1+floor(max(time(i)-h,0)/Ts));[y(i,:),d(i,:)]=timing_adc(time(i),current,gate,cfg);
 end
 indices=(0:2)'*N+jphase+1;results{mode}=y(indices,:);diags{mode}=d(indices,:);
end
assert(isequal(diags{2}(:,7:9),[1 0 1;1 1 0;0 1 0]));
assert(isequal(results{1},[1 2 -3;2 4 -6;3 6 -9]));
assert(isequal(results{2},[1 0 -3;2 4 0;0 6 0]));
assert(isequal(results{3},[1 0 -3;2 4 -3;2 6 -3]));
r=struct('invalid_even_if_end_gate_on',true,'guard_checked_before_aperture',true, ...
 'initial_invalid_uses_zero',true,'hold_skips_multiple_invalid_samples',true,'no_truth_or_future_fallback',true, ...
 'delivered_off',results{1},'delivered_zero',results{2},'delivered_hold',results{3});
clear timing_adc;
end
function o=loadCases(r)
o=cell(1,numel(r.cases));for k=1:numel(r.cases),u=load(fullfile(r.folder,[r.cases(k).id '.mat']),'signals');o{k}=u.signals;end
end
function sameAll(a,b)
assert(isequal(sort(fieldnames(a)),sort(fieldnames(b))));
for name=fieldnames(a)'
 x=a.(name{1});y=b.(name{1});
 if strcmp(name{1},'log_Tcm_applied')
  % The logged variable Ts uses two equivalent expressions. Their binary
  % clocks can differ by one double ULP; compare the original event grid.
  h=62.5e-9;[found,where]=ismember(round(x.Time/h),round(y.Time/h));
  assert(all(found)&&max(abs(x.Time-y.Time(where)))<1e-14&&isequaln(x.Data,y.Data(where,:)), ...
   '输出阈值或其事件网格改变。');
 else
  assert(isequaln(x.Time,y.Time)&&isequaln(x.Data,y.Data),'信号改变：%s',name{1});
 end
end
end
function count=compareTimingArchive(old,actual)
count=0;h=62.5e-9;
for name=fieldnames(old)'
 x=old.(name{1});y=actual.(name{1});a=teach_values(x);b=teach_values(y);
 if strcmp(name{1},'obs_adc_timing')
  keep=a(:,6)>0;[found,where]=ismember(round(x.Time(keep)/h),round(y.Time/h));assert(all(found));
  assert(isequaln(a(keep,:),b(where,:)));
 elseif ismember(name{1},{'obs_current_fast','obs_dead_requested','obs_dead_gates'})
  [found,where]=ismember(round(x.Time/h),round(y.Time/h));assert(all(found));assert(max(abs(x.Time-y.Time(where)))<1e-14);
  assert(isequaln(a,b(where,:)));
 elseif strcmp(name{1},'log_Tcm_applied')
  [found,where]=ismember(round(x.Time/h),round(y.Time/h));assert(all(found));
  assert(max(abs(x.Time-y.Time(where)))<1e-14&&isequaln(a,b(where,:)), ...
   '实际输出阈值或事件网格改变。');
 else
  assert(isequaln(x.Time,y.Time)&&isequaln(x.Data,y.Data),'旧真实时序改变：%s',name{1});
 end
 count=count+1;
end
assert(count==24);
end
