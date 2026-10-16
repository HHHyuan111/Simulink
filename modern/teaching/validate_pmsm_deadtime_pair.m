function report=validate_pmsm_deadtime_pair(priorDefaultFolder)
% Isolated validation of the matched detailed-bridge experiment and UI.
here=fileparts(mfilename('fullpath'));root=fileparts(here);mdl='PMSM_FOC_R2026a';assert(~bdIsLoaded(mdl));
work=fullfile(root,'.build',['pair_check_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);mkdir(work);
old=pwd;cg=onCleanup(@()cd(old));cd(work);addpath(here);candidate=fullfile(work,[mdl '.slx']);copyfile(fullfile(root,[mdl '.slx']),candidate);
load_system(candidate);mg=onCleanup(@()close_system(mdl,0));pmsm_reference('restore');before=pmsm_reference('capture');geometry=teach_snapshot(mdl);
report=struct('all_passed',false,'model_sha256',teach_hash(fullfile(root,[mdl '.slx'])), ...
 'reference_manifest_sha256',teach_hash(fullfile(here,'reference_v1','manifest.json')),'run_folders',struct,'checks',struct);
for name={'pmsm_experiment_plan','plot_pmsm_deadtime_pair','pmsm_deadtime_pair_alignment','plot_pmsm_experiment','plot_pmsm_mechanism','export_pmsm_experiment_examples','open_pmsm_experiments'}
 issues=checkcode(fullfile(here,[name{1} '.m']),'-id');assert(~any(strcmp({issues.id},'PARSE')),'语法错误：%s',name{1});
end
invalid={@()pmsm_experiment_plan('gate_deadtime_pair',-.0625),@()pmsm_experiment_plan('gate_deadtime_pair',.1), ...
 @()pmsm_experiment_plan('gate_deadtime_pair',5.0625),@()pmsm_experiment_plan('gate_deadtime_pair',[1 2])};
for k=1:numel(invalid),rejected=false;try,invalid{k}();catch,rejected=true;end;assert(rejected);end
report.checks.invalid_inputs_rejected=numel(invalid);p=pmsm_experiment_plan('gate_deadtime_pair');
a=p.cases(1).configuration.rows;b=p.cases(2).configuration.rows;different=arrayfun(@(k)~isequaln(a(k),b(k)),1:numel(a));
assert(sum(different)==1&&strcmp(a(different).key,'gate_us')&&strcmp(a(different).value,'0')&&strcmp(b(different).value,'2'));
assert(isequal(pmsm_check_switches(p.cases(1).configuration),{'功率设置.gate_on'}));
assert(isequal(pmsm_check_switches(p.cases(2).configuration),{'功率设置.gate_on'}));
assert(p.numerical.reference_fixed_step_s==62.5e-9&&p.numerical.factor_fixed_step_s==62.5e-9);
report.checks.only_deadtime_setting_differs=true;

fprintf('PAIR_DEFAULT_GUI\n');f=open_pmsm_experiments;fg=onCleanup(@()close(f));selector=findall(f,'Tag','ExperimentSelector');selector.Value=7;cb=selector.Callback;cb(selector,[]);
button=findall(f,'Tag','ExperimentRun');cb=button.Callback;cb(button,[]);r=f.UserData;
assert(isstruct(r)&&strcmp(r.scenario.id,'gate_deadtime_pair'));pmsm_experiment_verify(r.folder);report.run_folders.default_pair=r.folder;
u=load(fullfile(r.folder,'reference.mat'),'signals');reference=u.signals;u=load(fullfile(r.folder,'factor.mat'),'signals');factor=u.signals;
if nargin>=1
 prior=pmsm_experiment_verify(priorDefaultFolder);assert(strcmp(prior.scenario.id,'gate_deadtime_pair'));
 currentCases={reference,factor};
 for k=1:2
  oldData=load(fullfile(priorDefaultFolder,[prior.cases(k).id '.mat']),'signals');
  for name=fieldnames(oldData.signals)'
   x=oldData.signals.(name{1});y=currentCases{k}.(name{1});assert(isequaln(x.Time,y.Time)&&isequaln(x.Data,y.Data),'配对复现不一致：%s',name{1});
  end
 end
 report.checks.default_pair_all_42_signals_repeated=true;report.prior_default_folder=priorDefaultFolder;
end
for s={reference,factor}
 q=s{1};assert(abs(median(diff(q.obs_dead_gates.Time))-62.5e-9)<1e-14);
 assert(isequal(q.log_theta_true.Time,q.obs_current_fast.Time));assert(abs(median(diff(q.log_theta_true.Time))-1e-6)<1e-14);
end
req=teach_values(reference.obs_dead_requested);act=teach_values(reference.obs_dead_gates);assert(isequal(req,act));
report.checks.zero_deadtime_gates_equal_requests=true;report.checks.both_fine_grid_and_synchronous_angle_current=true;
req=teach_values(factor.obs_dead_requested);act=teach_values(factor.obs_dead_gates);checked=0;
assert(all(act(:,1:2:5)+act(:,2:2:6)<=1,'all')&&all(act<=req,'all'));
for k=1:6
 for ix=(find(diff(req(:,k))==1)+1)'
  target=ix+32;
  if target<=size(req,1)&&all(req(ix:target,k)==1),assert(all(act(ix:target-1,k)==0)&&act(target,k)==1);checked=checked+1;end
 end
 falls=find(diff(req(:,k))==-1)+1;assert(all(act(falls,k)==0));
end
assert(checked>=6);report.checks.nonzero_rising_edges_2us=checked;report.checks.no_overlap_and_fall_immediate=true;
plan=jsondecode(fileread(fullfile(r.folder,'plan.json')));[aligned,info]=pmsm_deadtime_pair_alignment({reference,factor},plan);
for k=1:2
 pairCases={reference,factor};s=pairCases{k};ix=ismember(s.obs_current_fast.Time,aligned(k).time_s);
 raw=teach_values(s.obs_current_fast);assert(isequal(raw(ix,:),aligned(k).current_ABC_A));
 assert(aligned(k).angle_deg(1)>=0&&aligned(k).angle_deg(end)<360);
end
report.checks.alignment_uses_unmodified_original_samples=true;
saved=jsondecode(fileread(fullfile(r.folder,'alignment.json')));assert(saved.cycle_index==info.cycle_index);
assert(abs(saved.startup.final_integration_residual_deg)<.05);report.checks.startup_angle_matches_speed_integral=true;
report.alignment=saved;
startup=findall(f,'Tag','ExperimentStartup');assert(strcmp(startup.Enable,'on'));figures=findall(groot,'Type','figure');cb=startup.Callback;cb(startup,[]);
extra=setdiff(findall(groot,'Type','figure'),figures);assert(numel(extra)==1);close(extra);report.checks.gui_default_and_startup_callback=true;
selector.Value=1;cb=selector.Callback;cb(selector,[]);assert(isempty(f.UserData)&&strcmp(startup.Enable,'off'));clear fg;report.checks.gui_stale_result_cleared=true;

fprintf('PAIR_ZERO_IDENTITY\n');[r,o]=run_pmsm_experiment('gate_deadtime_pair',0,.05);report.run_folders.zero_pair=r.folder;
for name=fieldnames(o{1})'
 x=o{1}.(name{1});y=o{2}.(name{1});assert(isequaln(x.Time,y.Time)&&isequaln(x.Data,y.Data),'零死区配对不一致：%s',name{1});
 if ~ismember(name{1},{'obs_dead_requested','obs_dead_gates'})
  long=reference.(name{1});assert(isequaln(x.Time,long.Time(1:numel(x.Time))));
  aa=teach_values(x);bb=teach_values(long);assert(isequaln(aa,bb(1:size(aa,1),:)),'短时重跑不一致：%s',name{1});
 end
end
report.checks.zero_pair_all_21_signals_exact=true;report.checks.zero_reference_first_50ms_repeated=true;clear o;

fprintf('PAIR_LEGACY_REGRESSION\n');[r,o]=run_pmsm_experiment('current_bias');report.run_folders.legacy_bias=r.folder;
oldIndex=jsondecode(fileread(fullfile(here,'experiment_reproducibility_validation.json')));folder=oldIndex.run_folders.current_bias;pmsm_experiment_verify(folder);
for k=1:2
 labels={'reference','factor'};a=load(fullfile(folder,[labels{k} '.mat']),'signals');
 for name=fieldnames(a.signals)'
  x=a.signals.(name{1});y=o{k}.(name{1});assert(isequaln(x.Time,y.Time)&&isequaln(x.Data,y.Data));
 end
end
report.checks.legacy_bias_all_signals_exact=true;
tamper=fullfile(work,'tampered_alignment');copyfile(report.run_folders.default_pair,tamper);fid=fopen(fullfile(tamper,'alignment.json'),'a');fprintf(fid,' ');fclose(fid);
rejected=false;try,pmsm_experiment_verify(tamper);catch,rejected=true;end;assert(rejected);report.checks.alignment_tamper_rejected=true;
assert(isequaln(before,pmsm_reference('capture'))&&isequaln(geometry,teach_snapshot(mdl)));pmsm_reference('verify');
assert(strcmp(report.model_sha256,teach_hash(fullfile(root,[mdl '.slx']))));report.checks.main_reference_pi_layout_unchanged=true;
report.all_passed=true;teach_writejson(fullfile(here,'experiment_paired_deadtime_validation.json'),report);fprintf('PAIRED_DEADTIME_ALL_PASS\n');
end
