function report=validate_pmsm_encoder_speed(phase)
% Four isolated stages for the observation-only, parallel-window experiment.
here=fileparts(mfilename('fullpath'));root=fileparts(here);mdl='PMSM_FOC_R2026a';
if nargin<1
 for part={'default','repeat','parameters','finish'}
  command=sprintf('"%s" -batch "addpath(''%s''); validate_pmsm_encoder_speed(''%s'')"',fullfile(matlabroot,'bin','matlab.exe'),strrep(here,'''',''''''),part{1});
  [status,output]=system(command);fprintf('%s',output);assert(status==0,'测速验收阶段失败：%s',part{1});
 end
 report=jsondecode(fileread(fullfile(here,'experiment_encoder_speed_validation.json')));return;
end
assert(ismember(phase,{'default','repeat','parameters','finish'})&&~bdIsLoaded(mdl));
work=fullfile(root,'.build',['encoder_speed_check_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);mkdir(work);
old=pwd;cg=onCleanup(@()cd(old));cd(work);addpath(here);copyfile(fullfile(root,[mdl '.slx']),fullfile(work,[mdl '.slx']));
load_system(fullfile(work,[mdl '.slx']));mg=onCleanup(@()close_system(mdl,0));pmsm_reference('restore');before=pmsm_reference('capture');geometry=teach_snapshot(mdl);
checkpoint=fullfile(root,'.build','encoder_speed_validation_checkpoint.json');
if strcmp(phase,'default')
 report=struct('all_passed',false,'matlab_version',version,'model_sha256',teach_hash(fullfile(root,[mdl '.slx'])), ...
  'reference_manifest_sha256',teach_hash(fullfile(here,'reference_v1','manifest.json')),'checks',struct,'run_folders',struct);
else
 report=jsondecode(fileread(checkpoint));assert(~report.all_passed);r=pmsm_experiment_verify(report.run_folders.default_parallel);
 for f=r.source_files(:)',assert(strcmp(teach_hash(fullfile(here,f.path)),f.sha256),'阶段间源码改变：%s',f.path);end
end
switch phase
 case 'default'
  for name={'pmsm_encoder_speed_model','pmsm_encoder_speed_view','pmsm_encoder_speed_analysis','plot_pmsm_encoder_speed','pmsm_render_encoder_speed_run','run_pmsm_experiment','open_pmsm_experiments','validate_pmsm_encoder_speed'}
   issues=checkcode(fullfile(here,[name{1} '.m']),'-id');assert(~any(strcmp({issues.id},'PARSE')),'语法错误：%s',name{1});
  end
  pmsm_encoder_model('install',mdl);original=teach_snapshot(mdl);pmsm_encoder_speed_model('install',mdl);extended=teach_snapshot(mdl);
  for block=original.blocks(:)',ix=strcmp({extended.blocks.path},block.path);assert(sum(ix)==1&&isequaln(block,extended.blocks(ix)));end
  report.checks.original_block_parameters_and_inputs_unchanged=true;report.fixtures=fixtures(mdl);
  pmsm_encoder_speed_model('remove',mdl);assert(isequaln(original,teach_snapshot(mdl)));pmsm_encoder_model('remove',mdl);
  assert(isequaln(geometry,teach_snapshot(mdl)));report.checks.extension_removal_restores_original_graph=true;
  p=pmsm_experiment_plan('encoder_speed');assert(isequal(p.value,[10000 2 8])&&p.duration_s==.05&&numel(p.cases)==1);
  assert(isequaln(p,pmsm_experiment_plan('encoder_speed',[10000;2;8]))&&isequal(p.comparison_contract.rpm_per_count_step,[120 60 15]));
  report.checks.one_simulation_three_windows_same_source=true;
  bad={[10000 2 2],[10000 2.5 8],[10000 8 9],[10000 2 33],[19 2 8],[10000 1 8],[Inf 2 8],'10000 2+1 8'};
  for k=1:numel(bad),rejected=false;try,pmsm_experiment_plan('encoder_speed',bad{k});catch,rejected=true;end;assert(rejected);end
  report.checks.invalid_inputs_rejected=numel(bad);
  pmsm_encoder_model('install',mdl);pmsm_encoder_speed_model('install',mdl);set_param([mdl '/时序设置'],'real_on','on');set_param(mdl,'SimulationCommand','update');
  feval(mdl,[],[],[],'compile');
  try
   report.compiled=struct;
   for name={'单拍','窗口','长窗'}
    st=get_param([mdl '/角度设置/编码器/测速/' name{1} '/窗口历史'],'CompiledSampleTime');if iscell(st),st=vertcat(st{:});end
    assert(all(abs(st(:,1)-50e-6)<1e-12)&&all(abs(st(:,2)-28.875e-6)<1e-12));
   end
   st=get_param([mdl '/角度设置/编码器/测速/输入记录'],'CompiledSampleTime');if iscell(st),st=vertcat(st{:});end
   assert(all(abs(st(:,1)-100e-6)<1e-12)&&all(abs(st(:,2)-78.875e-6)<1e-12));report.compiled.speed_input=st;
  catch err,feval(mdl,[],[],[],'term');rethrow(err);end
  feval(mdl,[],[],[],'term');pmsm_encoder_model('remove',mdl);pmsm_reference('restore');report.checks.compiled_read_and_speed_task_rates=true;
  f=open_pmsm_experiments;fg=onCleanup(@()close(f));catalog=pmsm_experiment_catalog;assert(numel(catalog)>=14);
  sel=findall(f,'Tag','ExperimentSelector');sel.Value=find(strcmp({catalog.id},'encoder_speed'));cb=sel.Callback;cb(sel,[]);
  value=findall(f,'Tag','ExperimentValue');window=findall(f,'Tag','ExperimentFilterHz');long=findall(f,'Tag','ExperimentEncoderZero');
  assert(str2double(value.String)==10000&&str2double(window.String)==2&&str2double(long.String)==8&&strcmp(long.Visible,'on'));
  preview=findall(f,'Tag','ExperimentStartup');cb=preview.Callback;cb(preview,[]);assert(pmsm_encoder_speed_model('installed',mdl));
  restore=findall(f,'Tag','ExperimentRestore');cb=restore.Callback;cb(restore,[]);assert(~pmsm_encoder_model('installed',mdl)&&isequaln(geometry,teach_snapshot(mdl)));
  button=findall(f,'Tag','ExperimentRun');cb=button.Callback;cb(button,[]);r=f.UserData;status=findall(f,'Tag','ExperimentStatus');assert(isstruct(r),'实验失败：%s',status.String);
  pmsm_experiment_verify(r.folder);assert(numel(r.cases)==1&&numel(r.cases.retained_signals)==31);report.run_folders.default_parallel=r.folder;
  report.speed=jsondecode(fileread(fullfile(r.folder,'speed.json')));assert(isequal([report.speed.windows.invalid_initial_samples],[1 2 8]));
  report.checks.actual_counts_windows_timestamps_and_error_decomposition=true;
  mechanism=findall(f,'Tag','ExperimentMechanism');figures=findall(groot,'Type','figure');cb=mechanism.Callback;cb(mechanism,[]);extra=setdiff(findall(groot,'Type','figure'),figures);assert(numel(extra)==1);close(extra);
  long.String='12';cb=long.Callback;cb(long,[]);assert(isempty(f.UserData)&&strcmp(mechanism.Enable,'off'));
  sel.Value=find(strcmp({catalog.id},'encoder_angle'));cb=sel.Callback;cb(sel,[]);assert(str2double(long.String)==0&&str2double(window.String)==2);
  report.checks.gui_three_fields_preview_restore_report_and_stale_clear=true;clear fg;
 case 'repeat'
  [again,v]=repeat_pmsm_experiment(r.folder);assert(v.all_exact&&v.same_matlab_version&&numel(v.signals)==31);
  report.run_folders.repeated_parallel=again.folder;report.checks.all_31_raw_signals_strictly_repeated=true;
 case 'parameters'
  [custom,o]=run_pmsm_experiment('encoder_speed',[5000 3 12]);report.run_folders.custom_parallel=custom.folder;
  a=jsondecode(fileread(fullfile(custom.folder,'speed.json')));assert(isequal([a.windows.window_ticks],[1 3 12])&&isequal([a.windows.rpm_per_count],[240 80 20]));report.custom_speed=a;
  default=load(fullfile(r.folder,'reference.mat'),'signals');names=setdiff(fieldnames(default.signals),{'log_encoder','log_speed_short','log_speed_window','log_speed_long'});
  compare(default.signals,o{1},names);report.checks.parameters_change_observation_without_changing_physics=true;
  history=jsondecode(fileread(fullfile(here,'experiment_encoder_validation.json')));oldPack=pmsm_experiment_verify(history.run_folders.default_three);data=load(fullfile(oldPack.folder,'reference.mat'),'signals');
  report.history_comparison=compare(data.signals,default.signals,fieldnames(data.signals));report.checks.old_encoder_ideal_27_signals_preserved=true;
  p=pmsm_experiment_plan('encoder_speed');pmsm_encoder_model('install',mdl);pmsm_encoder_speed_model('install',mdl);input=makeInput(mdl,p);input=input.setBlockParameter([mdl '/角度设置/编码器/测速'],'speed_on','off');
  out=sim(input);disabled=struct;for name=fieldnames(default.signals)',disabled.(name{1})=out.get(name{1});end
  names=setdiff(fieldnames(default.signals),{'log_speed_short','log_speed_window','log_speed_long'});compare(default.signals,disabled,names);
  for name={'log_speed_short','log_speed_window','log_speed_long'},v=teach_values(disabled.(name{1}));assert(all(v(:,1:2)==0,'all'));end
  file=fullfile(work,'disabled.mat');save(file,'disabled','-v7.3');report.disabled_probe=struct('path',file,'sha256',teach_hash(file));
  pmsm_encoder_model('remove',mdl);pmsm_reference('restore');report.checks.observation_off_zero_invalid_and_physics_unchanged=true;
 case 'finish'
  [legacy,o]=run_pmsm_experiment('current_bias');report.run_folders.legacy_bias=legacy.folder;
  history=jsondecode(fileread(fullfile(here,'experiment_reproducibility_validation.json')));oldPack=pmsm_experiment_verify(history.run_folders.current_bias);
  for k=1:2,data=load(fullfile(oldPack.folder,[oldPack.cases(k).id '.mat']),'signals');compare(data.signals,o{k},fieldnames(data.signals));end
  report.checks.legacy_current_bias_42_signals_preserved=true;
  history=jsondecode(fileread(fullfile(here,'experiment_encoder_validation.json')));oldPack=pmsm_experiment_verify(history.run_folders.default_three);oldPlan=jsondecode(fileread(fullfile(oldPack.folder,'plan.json')));oldOutputs=cell(1,3);
  for k=1:3,d=load(fullfile(oldPack.folder,[oldPack.cases(k).id '.mat']),'signals');oldOutputs{k}=d.signals;end
  a=pmsm_encoder_analysis(oldOutputs,oldPlan);file=fullfile(work,'old_encoder.json');teach_writejson(file,a);
  assert(isequaln(jsondecode(fileread(file)),jsondecode(fileread(fullfile(oldPack.folder,'encoder.json')))));report.checks.previous_encoder_archive_analysis_unchanged=true;
  target=fullfile(work,'tampered');copyfile(r.folder,target);fid=fopen(fullfile(target,'speed_samples.csv'),'a');fwrite(fid,uint8(0));fclose(fid);
  rejected=false;try,pmsm_experiment_verify(target);catch,rejected=true;end;assert(rejected);report.checks.tampered_speed_samples_rejected=true;
end
assert(~pmsm_encoder_model('installed',mdl)&&isequaln(before,pmsm_reference('capture'))&&isequaln(geometry,teach_snapshot(mdl)));pmsm_reference('verify');
assert(strcmp(report.model_sha256,teach_hash(fullfile(root,[mdl '.slx']))));report.checks.main_reference_pi_and_layout_unchanged=true;
if strcmp(phase,'finish')
 assert(report.checks.all_31_raw_signals_strictly_repeated&&report.checks.observation_off_zero_invalid_and_physics_unchanged);report.all_passed=true;
 teach_writejson(fullfile(here,'experiment_encoder_speed_validation.json'),report);fprintf('ENCODER_SPEED_ALL_PASS\n');
else,teach_writejson(checkpoint,report);fprintf('ENCODER_SPEED_PHASE_PASS %s\n',phase);end
end
function result=fixtures(mdl)
name='encoder_speed_fixture';new_system(name);g=onCleanup(@()close_system(name,0));base=[name '/编码器'];add_block('built-in/SubSystem',base);mask=Simulink.Mask.create(base);mask.addParameter('Name','counts','Type','edit','Value','10000');
path=[base '/测速'];add_block([mdl '/角度设置/编码器/测速'],path);
for k=1:3,add_block('built-in/Inport',[base '/输入' num2str(k)],'Port',num2str(k));add_line(base,['输入' num2str(k) '/1'],['测速/' num2str(k)]);end
add_block('simulink/Sources/From Workspace',[name '/输入'],'VariableName','fixture_data','SampleTime','dt','Interpolate','off','OutputAfterFinalValue','Holding final value');
add_block('simulink/Signal Routing/Demux',[name '/拆分'],'Outputs','3');add_line(name,'输入/1','拆分/1');for k=1:3,add_line(name,['拆分/' num2str(k)],['编码器/' num2str(k)]);end
add_block('simulink/Sources/Constant',[name '/速度输入'],'Value','0');add_block('simulink/Signal Routing/Goto',[name '/原输入'],'GotoTag','speed_control_observed','TagVisibility','global');add_line(name,'速度输入/1','原输入/1');
ws=get_param(name,'ModelWorkspace');dt=50e-6;t=(0:60)'*dt;assignin(ws,'dt',dt);assignin(ws,'timing_control_sample',dt);assignin(ws,'timing_speed_sample',2*dt);
set_param(name,'SolverType','Fixed-step','Solver','FixedStepDiscrete','FixedStep','1e-6','StopTime',num2str(t(end),17));
for test=1:8
 N=10000;W=2;L=8;count=mod(N-5+(0:60)',N);valid=ones(size(t));on='on';
 if test==2,count=mod(3-(0:60)',N);elseif test==3,count(:)=42;elseif test==4,count=mod((0:60)'*(N/2),N);elseif test==5,valid(15)=0;
 elseif test==6,on='off';elseif test==7,N=1237;W=3;L=12;count=mod(N-5+(0:60)',N);elseif test==8,N=1237;W=7;L=32;count=mod(N-5+14*(0:60)',N);end
 set_param(base,'counts',num2str(N));set_param(path,'window_ticks',num2str(W),'long_ticks',num2str(L),'speed_on',on);assignin(ws,'fixture_data',[t count t valid]);
 out=sim(Simulink.SimulationInput(name));logs={'log_speed_short','log_speed_window','log_speed_long'};windows=[1 W L];
 for k=1:3
  n=windows(k);ix=(n+1:numel(t))';old=ix-n;delta=count(ix)-count(old);delta=delta-N*floor((delta+N/2)/N);
  ok=valid(ix)>.5&valid(old)>.5&abs(delta)<N/2&strcmp(on,'on');expected=zeros(size(t));flags=false(size(t));flags(ix)=ok;expected(ix(ok))=delta(ok)*60/(N*n*dt);
  a=teach_values(out.get(logs{k}));assert(isequal(a(:,2)>.5,flags)&&max(abs(a(:,1)-expected))<1e-9);
 end
end
result=struct('forward_reverse_wrap_and_rest',true,'non_power_of_two_counts',true,'full_history_initialization',true,'half_turn_ambiguity_invalid',true,'invalid_endpoints_not_replaced_by_truth',true,'disabled_outputs_zero_invalid',true,'windows_1_2_3_7_8_12_32',true);
end
function input=makeInput(mdl,p)
input=Simulink.SimulationInput(mdl);input=input.setModelParameter('StopTime',num2str(p.duration_s,17));
for change=p.cases.changes(:)',input=input.setBlockParameter([mdl '/' change.section],change.parameter,change.value);end
cfg=p.encoder_configurations;for key=fieldnames(cfg)',input=input.setBlockParameter([mdl '/角度设置/编码器'],key{1},cfg.(key{1}));end
cfg=p.speed_configuration;for key=fieldnames(cfg)',input=input.setBlockParameter([mdl '/角度设置/编码器/测速'],key{1},cfg.(key{1}));end
for change=p.logging_overrides(:)',block=find_system(mdl,'LookUnderMasks','all','FollowLinks','off','BlockType','ToWorkspace','VariableName',change.signal);assert(isscalar(block));input=input.setBlockParameter(block{1},change.parameter,change.value);end
end
function checks=compare(a,b,names)
checks=struct('signal',{},'same_time',{},'same_data',{},'same_time_grid',{});
for name=names'
 x=a.(name{1});y=b.(name{1});sameTime=isequaln(x.Time,y.Time);sameData=isequaln(x.Data,y.Data);assert(sameData,'原始信号值改变：%s',name{1});
 grid=sameTime;
 if ~sameTime&&strcmp(name{1},'log_Tcm_applied'),h=62.5e-9;grid=isequal(round(x.Time/h),round(y.Time/h))&&max(abs(x.Time-y.Time))<1e-14;end
 assert(grid,'原始信号时刻改变：%s',name{1});checks(end+1)=struct('signal',name{1},'same_time',sameTime,'same_data',sameData,'same_time_grid',grid);
end
end
