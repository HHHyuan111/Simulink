function report=validate_pmsm_speed_filter(phase)
here=fileparts(mfilename('fullpath'));root=fileparts(here);mdl='PMSM_FOC_R2026a';
if nargin<1
 for part={'default','repeat','parameters','finish'}
  [status,output]=system(sprintf('"%s" -batch "addpath(''%s''); validate_pmsm_speed_filter(''%s'')"',fullfile(matlabroot,'bin','matlab.exe'),strrep(here,'''',''''''),part{1}));fprintf('%s',output);assert(status==0);
 end
 report=jsondecode(fileread(fullfile(here,'experiment_speed_filter_validation.json')));return
end
assert(ismember(phase,{'default','repeat','parameters','finish'})&&~bdIsLoaded(mdl));
work=fullfile(root,'.build',['speed_filter_check_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);mkdir(work);old=pwd;cg=onCleanup(@()cd(old));cd(work);addpath(here);
copyfile(fullfile(root,[mdl '.slx']),fullfile(work,[mdl '.slx']));load_system(fullfile(work,[mdl '.slx']));mg=onCleanup(@()close_system(mdl,0));pmsm_reference('restore');before=pmsm_reference('capture');geometry=teach_snapshot(mdl);
checkpoint=fullfile(root,'.build','speed_filter_validation_checkpoint.json');
if strcmp(phase,'default')
 report=struct('all_passed',false,'matlab_version',version,'model_sha256',teach_hash(fullfile(root,[mdl '.slx'])), ...
  'reference_manifest_sha256',teach_hash(fullfile(here,'reference_v1','manifest.json')),'checks',struct,'run_folders',struct);
else
 report=jsondecode(fileread(checkpoint));assert(~report.all_passed);r=pmsm_experiment_verify(report.run_folders.default_pair);
 for file=r.source_files(:)',assert(strcmp(teach_hash(fullfile(here,file.path)),file.sha256),'阶段间源码改变：%s',file.path);end
end
switch phase
 case 'default'
  for name={'pmsm_speed_filter_model','pmsm_speed_filter_view','pmsm_speed_filter_analysis','plot_pmsm_speed_filter','pmsm_render_speed_filter_run','pmsm_speed_feedback_analysis','run_pmsm_experiment','open_pmsm_experiments','validate_pmsm_speed_filter'}
   issues=checkcode(fullfile(here,[name{1} '.m']),'-id');assert(~any(strcmp({issues.id},'PARSE')));
  end
  pmsm_encoder_model('install',mdl);pmsm_encoder_speed_model('install',mdl);pmsm_speed_feedback_model('install',mdl);original=teach_snapshot(mdl);pmsm_speed_filter_model('install',mdl);extended=teach_snapshot(mdl);
  for b=original.blocks(:)'
   ix=strcmp({extended.blocks.path},b.path);assert(sum(ix)==1);next=extended.blocks(ix);
   if strcmp(b.path,[mdl '/速度反馈/反馈选择']),assert(isequaln(rmfield(b,'inputs'),rmfield(next,'inputs')));else,assert(isequaln(b,next));end
  end
  report.checks.only_count_feedback_route_extended=true;report.fixtures=fixtures(mdl);
  set_param([mdl '/时序设置'],'real_on','on');feval(mdl,[],[],[],'compile');
  try
   st=get_param([mdl '/速度反馈/速度滤波/历史'],'CompiledSampleTime');if iscell(st),st=vertcat(st{:});end
   hold=get_param(Simulink.ID.getHandle([mdl ':190']),'CompiledSampleTime');if iscell(hold),hold=vertcat(hold{:});end
   assert(all(abs(st(:,1)-50e-6)<1e-12)&&all(abs(st(:,2)-28.875e-6)<1e-12));assert(all(abs(hold(:,1)-100e-6)<1e-12)&&all(abs(hold(:,2)-78.875e-6)<1e-12));report.compiled=struct('filter_history',st,'speed_hold',hold);
  catch err,feval(mdl,[],[],[],'term');rethrow(err);end
  feval(mdl,[],[],[],'term');pmsm_speed_filter_model('remove',mdl);set_param([mdl '/时序设置'],'real_on','off');assert(isequaln(original,teach_snapshot(mdl)));
  pmsm_encoder_model('remove',mdl);pmsm_reference('restore');assert(isequaln(geometry,teach_snapshot(mdl)));report.checks.removal_and_task_rates_preserved=true;
  p=pmsm_experiment_plan('speed_filter');assert(isequal(p.value,[10000 2 200])&&p.duration_s==.1&&numel(p.cases)==2&&p.comparison_contract.filter_update_s==50e-6);
  for bad={[10000 2 0],[10000 2 5001],[10000 2.5 200],[10000.5 2 200],[10000 1 200],[19 2 200],[10000 2 Inf]}
   rejected=false;try,pmsm_experiment_plan('speed_filter',bad{1});catch,rejected=true;end;assert(rejected);
  end
  report.checks.invalid_parameters_rejected=true;
  f=open_pmsm_experiments;fg=onCleanup(@()close(f));catalog=pmsm_experiment_catalog;assert(numel(catalog)>=16);sel=findall(f,'Tag','ExperimentSelector');sel.Value=find(strcmp({catalog.id},'speed_filter'));cb=sel.Callback;cb(sel,[]);
  value=findall(f,'Tag','ExperimentValue');window=findall(f,'Tag','ExperimentFilterHz');cutoff=findall(f,'Tag','ExperimentEncoderZero');assert(str2double(value.String)==10000&&str2double(window.String)==2&&str2double(cutoff.String)==200);
  preview=findall(f,'Tag','ExperimentStartup');cb=preview.Callback;cb(preview,[]);assert(pmsm_speed_filter_model('installed',mdl));restore=findall(f,'Tag','ExperimentRestore');cb=restore.Callback;cb(restore,[]);assert(isequaln(geometry,teach_snapshot(mdl)));
  button=findall(f,'Tag','ExperimentRun');cb=button.Callback;cb(button,[]);r=f.UserData;status=findall(f,'Tag','ExperimentStatus');assert(isstruct(r),'实验失败：%s',status.String);pmsm_experiment_verify(r.folder);
  assert(numel(r.cases)==2&&all(arrayfun(@(z)numel(z.retained_signals)==33,r.cases)));report.run_folders.default_pair=r.folder;report.filter=jsondecode(fileread(fullfile(r.folder,'speed_filter.json')));
  report.checks.counts_filter_recursion_decomposition_and_actual_pi_input=true;
  history=jsondecode(fileread(fullfile(here,'experiment_speed_feedback_validation.json')));oldPack=pmsm_experiment_verify(history.run_folders.default_three);a=load(fullfile(oldPack.folder,'factor.mat'),'signals');b=load(fullfile(r.folder,'reference.mat'),'signals');
  names=setdiff(fieldnames(a.signals),{'obs_current_fast','obs_dead_requested','obs_dead_gates','obs_adc_timing','obs_pwm_timing','log_Tcm_applied'});report.previous_50ms_prefix=comparePrefix(a.signals,b.signals,names);assert(numel(names)==26);report.checks.unfiltered_first_50ms_26_signals_preserved=true;
  mechanism=findall(f,'Tag','ExperimentMechanism');figures=findall(groot,'Type','figure');cb=mechanism.Callback;cb(mechanism,[]);extra=setdiff(findall(groot,'Type','figure'),figures);assert(numel(extra)==1);close(extra);
  cutoff.String='500';cb=cutoff.Callback;cb(cutoff,[]);assert(isempty(f.UserData)&&strcmp(mechanism.Enable,'off'));sel.Value=find(strcmp({catalog.id},'speed_feedback'));cb=sel.Callback;cb(sel,[]);assert(str2double(cutoff.String)==8);
  report.checks.gui_preview_restore_run_report_and_stale_clear=true;clear fg;
 case 'repeat'
  [again,v]=repeat_pmsm_experiment(r.folder);assert(v.all_exact&&v.same_matlab_version&&numel(v.signals)==66);report.run_folders.repeated_pair=again.folder;report.checks.all_66_signals_strictly_repeated=true;
 case 'parameters'
  [custom,o]=run_pmsm_experiment('speed_filter',[5000 3 500],.1);report.run_folders.custom_pair=custom.folder;report.custom_filter=jsondecode(fileread(fullfile(custom.folder,'speed_filter.json')));
  assert(all([report.custom_filter.cases.window_ticks]==3)&&all([report.custom_filter.cases.cutoff_hz]==500));
  history=jsondecode(fileread(fullfile(here,'experiment_speed_feedback_validation.json')));oldPack=pmsm_experiment_verify(history.run_folders.custom_three);a=load(fullfile(oldPack.folder,'factor.mat'),'signals');report.previous_custom_32_comparison=compare(a.signals,o{1},fieldnames(a.signals));report.checks.custom_parameters_and_unfiltered_32_signals_preserved=true;
 case 'finish'
  [legacy,o]=run_pmsm_experiment('current_bias');report.run_folders.legacy_bias=legacy.folder;history=jsondecode(fileread(fullfile(here,'experiment_reproducibility_validation.json')));oldPack=pmsm_experiment_verify(history.run_folders.current_bias);
  for k=1:2,a=load(fullfile(oldPack.folder,[oldPack.cases(k).id '.mat']),'signals');compare(a.signals,o{k},fieldnames(a.signals));end
  report.checks.legacy_bias_42_signals_preserved=true;
  history=jsondecode(fileread(fullfile(here,'experiment_speed_feedback_validation.json')));
  for name={'default_three','custom_three'}
   pack=pmsm_experiment_verify(history.run_folders.(name{1}));p=jsondecode(fileread(fullfile(pack.folder,'plan.json')));data=cell(1,3);
   for k=1:3,d=load(fullfile(pack.folder,[pack.cases(k).id '.mat']),'signals');data{k}=d.signals;end
   a=pmsm_speed_feedback_analysis(data,p);file=fullfile(work,[name{1} '.json']);teach_writejson(file,a);assert(isequaln(jsondecode(fileread(file)),jsondecode(fileread(fullfile(pack.folder,'feedback.json')))));
  end
  report.checks.previous_feedback_default_and_custom_analysis_unchanged=true;
  target=fullfile(work,'tampered');copyfile(r.folder,target);fid=fopen(fullfile(target,'filter_samples.csv'),'a');fwrite(fid,uint8(0));fclose(fid);rejected=false;try,pmsm_experiment_verify(target);catch,rejected=true;end;assert(rejected);report.checks.tampered_filter_samples_rejected=true;
end
assert(~pmsm_encoder_model('installed',mdl)&&isequaln(before,pmsm_reference('capture'))&&isequaln(geometry,teach_snapshot(mdl)));pmsm_reference('verify');assert(strcmp(report.model_sha256,teach_hash(fullfile(root,[mdl '.slx']))));report.checks.main_reference_pi_and_layout_unchanged=true;
if strcmp(phase,'finish')
 assert(report.checks.all_66_signals_strictly_repeated&&report.checks.custom_parameters_and_unfiltered_32_signals_preserved);report.all_passed=true;teach_writejson(fullfile(here,'experiment_speed_filter_validation.json'),report);fprintf('SPEED_FILTER_ALL_PASS\n');
else,teach_writejson(checkpoint,report);fprintf('SPEED_FILTER_PHASE_PASS %s\n',phase);end
end
function result=fixtures(mdl)
name='speed_filter_fixture';new_system(name);guard=onCleanup(@()close_system(name,0));path=[name '/滤波'];add_block([mdl '/速度反馈/速度滤波'],path);
dt=50e-6;t=(0:100)'*dt;ws=get_param(name,'ModelWorkspace');assignin(ws,'dt',dt);assignin(ws,'timing_control_sample',dt);assignin(ws,'timing_speed_sample',[2*dt dt]);
valid=ones(size(t));valid(1:3)=0;valid(16:19)=0;x=300*sin((0:100)'*.4);x(~valid)=0;assignin(ws,'input_data',[t x valid]);
add_block('simulink/Sources/From Workspace',[name '/数据'],'VariableName','input_data','SampleTime','dt','Interpolate','off','OutputAfterFinalValue','Holding final value');add_block('simulink/Signal Routing/Demux',[name '/拆分'],'Outputs','2');add_line(name,'数据/1','拆分/1');for k=1:2,add_line(name,['拆分/' num2str(k)],['滤波/' num2str(k)]);end
add_block(Simulink.ID.getHandle([mdl ':190']),[name '/原保持']);add_line(name,'滤波/1','原保持/1');add_block('simulink/Sinks/To Workspace',[name '/实际'],'VariableName','fixture_pi','SaveFormat','Timeseries','SampleTime','timing_speed_sample');add_line(name,'原保持/1','实际/1');
set_param(name,'SolverType','Fixed-step','Solver','FixedStepDiscrete','FixedStep','1e-6','StopTime',num2str(t(end),17));
for fc=[20 200 1000 5000]
 for state={'off','on'}
  set_param(path,'cutoff_hz',num2str(fc),'filter_on',state{1});out=sim(Simulink.SimulationInput(name));f=teach_values(out.get('log_speed_filter'));a=1/(1+2*pi*fc*dt);b=1-a;y=zeros(size(x));memory=0;
  for j=1:numel(x),memory=b*x(j)+a*memory;y(j)=memory;end
  assert(max(abs(f(:,2)-y))<1e-10&&isequal(f(:,1),x));expected=x;if strcmp(state{1},'on'),expected=y;expected(~valid)=0;end
  assert(max(abs(f(:,3)-expected))<1e-10);[found,at]=ismember(round(out.fixture_pi.Time/1e-6),round(out.log_speed_filter.Time/1e-6));assert(all(found));assert(max(abs(out.fixture_pi.Time-out.log_speed_filter.Time(at)))<1e-12);assert(max(abs(teach_values(out.fixture_pi)-expected(at)))<1e-10);
 end
end
result=struct('cutoff_20_200_1000_5000',true,'off_is_exact_bypass',true,'zero_initial_state_and_current_input_term',true,'invalid_zero_input_state_decay_and_zero_publication',true,'positive_negative_inputs',true,'original_speed_hold_samples_output',true);
end
function checks=comparePrefix(a,b,names)
checks=struct('signal',{},'matched_original_samples',{},'exact_time',{},'exact_data',{});
for name=names'
 x=a.(name{1});y=b.(name{1});[found,at]=ismember(x.Time,y.Time);assert(all(found));vx=teach_values(x);vy=teach_values(y);assert(isequaln(vx,vy(at,:)),'旁路前50ms改变：%s',name{1});checks(end+1)=struct('signal',name{1},'matched_original_samples',numel(x.Time),'exact_time',true,'exact_data',true);
end
end
function checks=compare(a,b,names)
checks=struct('signal',{},'same_time',{},'same_data',{},'same_time_grid',{});
for name=names'
 x=a.(name{1});y=b.(name{1});sameTime=isequaln(x.Time,y.Time);sameData=isequaln(x.Data,y.Data);assert(sameData,'原始数据改变：%s',name{1});grid=sameTime;
 if ~sameTime&&strcmp(name{1},'log_Tcm_applied'),h=62.5e-9;grid=isequal(round(x.Time/h),round(y.Time/h))&&max(abs(x.Time-y.Time))<1e-14;end
 assert(grid,'原始时刻改变：%s',name{1});checks(end+1)=struct('signal',name{1},'same_time',sameTime,'same_data',sameData,'same_time_grid',grid);
end
end
