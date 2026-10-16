function report=validate_pmsm_encoder(phase)
% Isolated acceptance stages; no model or fixed-reference files are saved.
here=fileparts(mfilename('fullpath'));root=fileparts(here);mdl='PMSM_FOC_R2026a';
if nargin<1
 for part={'default','repeat','parameters','finish'}
  command=sprintf('"%s" -batch "addpath(''%s''); validate_pmsm_encoder(''%s'')"',fullfile(matlabroot,'bin','matlab.exe'),strrep(here,'''',''''''),part{1});
  [status,output]=system(command);fprintf('%s',output);assert(status==0,'编码器验收失败：%s',part{1});
 end
 report=jsondecode(fileread(fullfile(here,'experiment_encoder_validation.json')));return;
end
assert(ismember(phase,{'default','repeat','parameters','finish'})&&~bdIsLoaded(mdl));
work=fullfile(root,'.build',['encoder_check_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);mkdir(work);
old=pwd;cg=onCleanup(@()cd(old));cd(work);addpath(here);copyfile(fullfile(root,[mdl '.slx']),fullfile(work,[mdl '.slx']));
load_system(fullfile(work,[mdl '.slx']));mg=onCleanup(@()close_system(mdl,0));pmsm_reference('restore');before=pmsm_reference('capture');geometry=teach_snapshot(mdl);
checkpoint=fullfile(root,'.build','encoder_validation_checkpoint.json');
if strcmp(phase,'default')
 report=struct('all_passed',false,'matlab_version',version,'model_sha256',teach_hash(fullfile(root,[mdl '.slx'])), ...
  'reference_manifest_sha256',teach_hash(fullfile(here,'reference_v1','manifest.json')),'checks',struct,'run_folders',struct);
else
 report=jsondecode(fileread(checkpoint));assert(~report.all_passed);r=pmsm_experiment_verify(report.run_folders.default_three);
 for f=r.source_files(:)',assert(strcmp(teach_hash(fullfile(here,f.path)),f.sha256),'阶段间脚本已改变：%s',f.path);end
end
switch phase
 case 'default'
  for name={'pmsm_encoder_model','pmsm_encoder_view','pmsm_experiment_plan','run_pmsm_experiment','open_pmsm_experiments','pmsm_encoder_analysis','plot_pmsm_encoder','pmsm_render_encoder_run','validate_pmsm_encoder'}
   issues=checkcode(fullfile(here,[name{1} '.m']),'-id');assert(~any(strcmp({issues.id},'PARSE')),'语法错误：%s',name{1});
  end
  pmsm_encoder_model('install',mdl);report.fixtures=fixtures(mdl);pmsm_encoder_model('remove',mdl);
  assert(isequaln(geometry,teach_snapshot(mdl)));report.checks.reversible_module_and_forward_reverse_wrap_fixtures=true;
  p=pmsm_experiment_plan('encoder_angle');assert(isequal(p.value,[10000 2 0])&&p.duration_s==.05&&numel(p.cases)==3);
  assert(isequaln(p,pmsm_experiment_plan('encoder_angle',[10000;2;0])));
  assert(isequaln(p.cases(1).configuration,p.cases(2).configuration)&&isequaln(p.cases(2).configuration,p.cases(3).configuration));
  report.checks.same_baseline_and_only_encoder_or_delay_differs=true;
  bad={[10000 1.5 0],[10000.5 2 0],[19 2 0],[10000 -1 0],[10000 21 0],[10000 2 181],[NaN 2 0],'10000 2 0+1'};
  for k=1:numel(bad),rejected=false;try,pmsm_experiment_plan('encoder_angle',bad{k});catch,rejected=true;end;assert(rejected);end
  report.checks.invalid_inputs_rejected=numel(bad);
  % Compile the actual model tasks and new read/delay blocks.
  pmsm_encoder_model('install',mdl);set_param([mdl '/时序设置'],'real_on','on');set_param([mdl '/角度设置/编码器'],'encoder_on','on');
  set_param(mdl,'SimulationCommand','update');feval(mdl,[],[],[],'compile');
  try
   report.compiled=struct;
   paths={[mdl '/角度设置/编码器/读取'],[mdl '/角度设置/编码器/传递延迟'],getfullname(Simulink.ID.getHandle([mdl ':191'])),getfullname(Simulink.ID.getHandle([mdl ':235']))};
   for k=1:numel(paths)
    st=get_param(paths{k},'CompiledSampleTime');if iscell(st),st=vertcat(st{:});end
    assert(all(abs(st(:,1)-50e-6)<1e-12)&&all(abs(st(:,2)-28.875e-6)<1e-12));report.compiled.(['block' num2str(k)])=st;
   end
  catch err,feval(mdl,[],[],[],'term');rethrow(err);end
  feval(mdl,[],[],[],'term');pmsm_encoder_model('remove',mdl);pmsm_reference('restore');report.checks.actual_read_delay_park_sample_times=true;
  f=open_pmsm_experiments;fg=onCleanup(@()close(f));catalog=pmsm_experiment_catalog;assert(numel(catalog)>=13);
  sel=findall(f,'Tag','ExperimentSelector');sel.Value=find(strcmp({catalog.id},'encoder_angle'));cb=sel.Callback;cb(sel,[]);
  value=findall(f,'Tag','ExperimentValue');delay=findall(f,'Tag','ExperimentFilterHz');zero=findall(f,'Tag','ExperimentEncoderZero');
  assert(str2double(value.String)==10000&&str2double(delay.String)==2&&str2double(zero.String)==0&&strcmp(zero.Visible,'on'));
  preview=findall(f,'Tag','ExperimentStartup');cb=preview.Callback;cb(preview,[]);assert(pmsm_encoder_model('installed',mdl));
  restore=findall(f,'Tag','ExperimentRestore');cb=restore.Callback;cb(restore,[]);assert(~pmsm_encoder_model('installed',mdl)&&isequaln(geometry,teach_snapshot(mdl)));
  button=findall(f,'Tag','ExperimentRun');cb=button.Callback;cb(button,[]);r=f.UserData;
  status=findall(f,'Tag','ExperimentStatus');assert(isstruct(r),'窗口实验失败：%s',status.String);pmsm_experiment_verify(r.folder);report.run_folders.default_three=r.folder;
  o=loadCases(r);assert(all(cellfun(@(s)numel(fieldnames(s))==27,o)));
  report.encoder=jsondecode(fileread(fullfile(r.folder,'encoder.json')));assert(report.encoder.cases(3).invalid_initial_samples==2);
  report.checks.raw_counts_history_actual_park_and_inverse_verified=true;
  mechanism=findall(f,'Tag','ExperimentMechanism');assert(strcmp(mechanism.Enable,'on'));figures=findall(groot,'Type','figure');cb=mechanism.Callback;cb(mechanism,[]);
  extra=setdiff(findall(groot,'Type','figure'),figures);assert(numel(extra)==1);close(extra);
  zero.String='1';cb=zero.Callback;cb(zero,[]);assert(isempty(f.UserData)&&strcmp(mechanism.Enable,'off'));
  sel.Value=find(strcmp({catalog.id},'sampling_window'));cb=sel.Callback;cb(sel,[]);assert(strcmp(zero.Visible,'off')&&str2double(value.String)==31.25&&str2double(delay.String)==.5);
  report.checks.gui_three_inputs_preview_restore_reports_and_stale_clear=true;clear fg;
 case 'repeat'
  [again,v]=repeat_pmsm_experiment(r.folder);assert(v.all_exact&&v.same_matlab_version&&numel(v.signals)==81);
  report.run_folders.repeated_three=again.folder;report.checks.default_all_81_signals_repeated=true;
 case 'parameters'
  [custom,o]=run_pmsm_experiment('encoder_angle',[500 0 7.5]);report.run_folders.custom_three=custom.folder;
  a=jsondecode(fileread(fullfile(custom.folder,'encoder.json')));assert(a.contract.counts_per_mechanical_turn==500&&a.contract.delay_cycles==0&&a.contract.electrical_zero_deg==7.5);
  report.custom_encoder=a;
  names=setdiff(fieldnames(o{2}),{'log_encoder'});same(o{2},o{3},names);
  x=teach_values(o{2}.log_encoder);y=teach_values(o{3}.log_encoder);keep=setdiff(1:12,10);assert(isequaln(x(:,keep),y(:,keep))&&all(x(:,10)==0)&&all(y(:,10)==1));
  report.checks.edited_counts_zero_offset_and_zero_delay_bypass=true;
  history=jsondecode(fileread(fullfile(here,'experiment_timing_events_validation.json')));old=pmsm_experiment_verify(history.run_folders.default_pair);data=load(fullfile(old.folder,'factor.mat'),'signals');
  report.archive_comparison=compareTimingArchive(data.signals,o{1});report.checks.ideal_angle_old_22_signals_exact_and_two_common_grid=true;
 case 'finish'
  [legacy,o]=run_pmsm_experiment('current_bias');report.run_folders.legacy_bias=legacy.folder;
  history=jsondecode(fileread(fullfile(here,'experiment_reproducibility_validation.json')));old=pmsm_experiment_verify(history.run_folders.current_bias);archive=loadCases(old);
  for k=1:2,same(archive{k},o{k},fieldnames(archive{k}));end
  report.checks.legacy_current_bias_42_signals_preserved=true;
  window=jsondecode(fileread(fullfile(here,'experiment_sampling_window_validation.json')));w=pmsm_experiment_verify(window.run_folders.default_three);wp=jsondecode(fileread(fullfile(w.folder,'plan.json')));
  [a,~,~]=pmsm_sampling_window_analysis(loadCases(w),wp);old=jsondecode(fileread(fullfile(w.folder,'window.json')));file=fullfile(work,'window.json');teach_writejson(file,a);assert(isequaln(old,jsondecode(fileread(file))));
  report.checks.previous_sampling_window_archive_preserved=true;
  target=fullfile(work,'tampered');copyfile(r.folder,target);fid=fopen(fullfile(target,'encoder_samples.csv'),'a');fwrite(fid,uint8(0));fclose(fid);
  rejected=false;try,pmsm_experiment_verify(target);catch,rejected=true;end;assert(rejected);report.checks.tampered_source_samples_rejected=true;
end
assert(~pmsm_encoder_model('installed',mdl)&&isequaln(before,pmsm_reference('capture'))&&isequaln(geometry,teach_snapshot(mdl)));pmsm_reference('verify');
assert(strcmp(report.model_sha256,teach_hash(fullfile(root,[mdl '.slx']))));report.checks.main_pi_reference_and_layout_unchanged=true;
if strcmp(phase,'finish')
 assert(report.checks.default_all_81_signals_repeated&&report.checks.edited_counts_zero_offset_and_zero_delay_bypass);report.all_passed=true;
 teach_writejson(fullfile(here,'experiment_encoder_validation.json'),report);fprintf('ENCODER_ALL_PASS\n');
else,teach_writejson(checkpoint,report);fprintf('ENCODER_PHASE_PASS %s\n',phase);end
end
function out=fixtures(mdl)
name='pmsm_encoder_fixture';new_system(name);g=onCleanup(@()close_system(name,0));
add_block('built-in/SubSystem',[name '/角度设置']);mask=Simulink.Mask.create([name '/角度设置']);
for key={'bias_on','quant_on','delay_on'},mask.addParameter('Name',key{1},'Type','checkbox','Value','off');end
path=[name '/角度设置/编码器'];add_block([mdl '/角度设置/编码器'],path);
add_block('simulink/Signal Routing/From',[name '/角度设置/原角度'],'GotoTag','fixture_ideal');
add_line([name '/角度设置'],'原角度/1','编码器/1');
for row={'encoder_park_angle','Park';'encoder_inverse_angle','Inverse'}'
 add_block('simulink/Signal Routing/Goto',[name '/角度设置/' row{2}],'GotoTag',row{1},'TagVisibility','global');add_line([name '/角度设置'],'编码器/1',[row{2} '/1']);
end
add_block('simulink/Sources/From Workspace',[name '/机械输入'],'VariableName','fixture_input','SampleTime','dt','Interpolate','off','OutputAfterFinalValue','Holding final value');
add_block('simulink/Signal Routing/Goto',[name '/机械真值'],'GotoTag','encoder_mechanical_truth','TagVisibility','global');add_line(name,'机械输入/1','机械真值/1');
add_block('simulink/Math Operations/Gain',[name '/极对数'],'Gain','p');add_line(name,'机械输入/1','极对数/1');
add_block('simulink/User-Defined Functions/Fcn',[name '/电角度'],'Expr','u-2*pi*floor(u/(2*pi))');add_line(name,'极对数/1','电角度/1');
add_block('simulink/Signal Routing/Goto',[name '/理想角度'],'GotoTag','fixture_ideal','TagVisibility','global');add_line(name,'电角度/1','理想角度/1');
ws=get_param(name,'ModelWorkspace');dt=50e-6;time=(0:100)'*dt;theta=[.37+(0:50)'*.17;8.8-(1:50)'*.23];
assignin(ws,'dt',dt);assignin(ws,'timing_control_sample',dt);assignin(ws,'timing_h',1e-6);assignin(ws,'p',5);assignin(ws,'fixture_input',[time theta]);
set_param(name,'SolverType','Fixed-step','Solver','FixedStepDiscrete','FixedStep','1e-6','StopTime',num2str(time(end),17));
settings={10000,-1,-1,0,0,'on';1237,1,1,2,7.5,'on';10000,-1,1,3,-3,'on';1237,-1,-1,2,7.5,'off'};
for k=1:size(settings,1)
 N=settings{k,1};sd=settings{k,2};direction=settings{k,3};n=settings{k,4};zero=settings{k,5};enabled=settings{k,6};
 set_param(path,'counts',num2str(N),'sensor_dir',num2str(sd),'direction',num2str(direction),'delay_on','on','delay_cycles',num2str(n),'zero_deg',num2str(zero),'encoder_on',enabled);
 o=sim(Simulink.SimulationInput(name));v=teach_values(o.log_encoder);raw=mod(floor(theta*(sd*N/(2*pi))),N);expected=mod(mod(direction*raw,N)*(2*pi/N)*5+zero*pi/180,2*pi);
 expected=[zeros(n,1);expected(1:end-n)];if strcmp(enabled,'off'),expected=mod(theta*5,2*pi);end
 assert(isequal(v(:,1),raw)&&max(abs(atan2(sin(v(:,5)-expected),cos(v(:,5)-expected))))<1e-10);
 assert(all(v(:,1)>=0&v(:,1)<N&v(:,1)==round(v(:,1))));
end
set_param(path,'encoder_on','on');set_param([name '/角度设置'],'quant_on','on');rejected=false;try,set_param(name,'SimulationCommand','update');catch,rejected=true;end;assert(rejected);
out=struct('positive_negative_and_mechanical_wrap',true,'counts_not_divisible_by_poles',true,'direction_mismatch_not_hidden',true,'nonzero_zero_offset',true,'delay_0_2_3',true,'ideal_bypass',true,'legacy_angle_double_application_rejected',true);
end
function o=loadCases(r)
o=cell(1,numel(r.cases));for k=1:numel(r.cases),d=load(fullfile(r.folder,[r.cases(k).id '.mat']),'signals');o{k}=d.signals;end
end
function same(a,b,names)
for name=names'
 x=a.(name{1});y=b.(name{1});
 if strcmp(name{1},'log_Tcm_applied')
  h=62.5e-9;assert(isequal(round(x.Time/h),round(y.Time/h))&&max(abs(x.Time-y.Time))<1e-14&&isequaln(x.Data,y.Data));
 else,assert(isequaln(x.Time,y.Time)&&isequaln(x.Data,y.Data),'旧信号或旁路不一致：%s',name{1});end
end
end
function report=compareTimingArchive(a,b)
report=struct('scope','22路完整Time/Data严格相同；物理高频电流与生效阈值日志采样密度不同，仅比较重叠区间的全部共同原始采样点，不插值。','signals',struct([]));
h=62.5e-9;
for name=fieldnames(a)'
 x=a.(name{1});y=b.(name{1});strict=~ismember(name{1},{'obs_current_fast','log_Tcm_applied'});
 if strict
  same(a,b,name);count=numel(x.Time);
 else
  [found,where]=ismember(round(x.Time/h),round(y.Time/h));count=sum(found);
  overlap=y.Time>=x.Time(1)-1e-14&y.Time<=x.Time(end)+1e-14;
  minimum=10;if strcmp(name{1},'obs_current_fast'),minimum=500;end
  assert(count>=minimum&&count==sum(overlap),'共同原始时刻覆盖不足：%s',name{1});
  assert(max(abs(x.Time(found)-y.Time(where(found))))<1e-14);
  xx=teach_values(x);yy=teach_values(y);assert(isequaln(xx(found,:),yy(where(found),:)),'共同格点上的信号值改变：%s',name{1});
 end
 row=struct('signal',name{1},'old_sample_count',numel(x.Time),'new_sample_count',numel(y.Time),'compared_sample_count',count,'strict_full_time_data',strict,'max_value_error',0);
 if isempty(report.signals),report.signals=row;else,report.signals(end+1)=row;end
end
assert(numel(report.signals)==24&&sum([report.signals.strict_full_time_data])==22);
end
