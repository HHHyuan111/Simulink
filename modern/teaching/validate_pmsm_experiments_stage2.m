function record=validate_pmsm_experiments_stage2
% Separate-process integration checks for the added experiments and old packs.
here=fileparts(mfilename('fullpath'));root=fileparts(here);mdl='PMSM_FOC_R2026a';assert(~bdIsLoaded(mdl));
work=fullfile(root,'.build',['experiment_stage2_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);mkdir(work);
old=pwd;cg=onCleanup(@()cd(old));cd(work);addpath(here);candidate=fullfile(work,[mdl '.slx']);copyfile(fullfile(root,[mdl '.slx']),candidate);
load_system(candidate);mg=onCleanup(@()close_system(mdl,0));pmsm_reference('restore');before=pmsm_reference('capture');geometry=teach_snapshot(mdl);
record=struct('all_passed',false,'model_sha256',teach_hash(fullfile(root,[mdl '.slx'])), ...
 'reference_manifest_sha256',teach_hash(fullfile(here,'reference_v1','manifest.json')),'run_folders',struct,'checks',struct);
files={'pmsm_experiment_catalog','pmsm_experiment_plan','run_pmsm_experiment','plot_pmsm_mechanism','open_pmsm_experiments','pmsm_experiment_verify'};
for name=files
 issues=checkcode(fullfile(here,[name{1} '.m']),'-id');assert(~any(strcmp({issues.id},'PARSE')),'语法错误：%s',name{1});
end
invalid={@()pmsm_experiment_plan('digital_filter',0),@()pmsm_experiment_plan('digital_filter',10000), ...
 @()pmsm_experiment_plan('angle_bias',31),@()pmsm_experiment_plan('angle_bias',[1 2]), ...
 @()pmsm_experiment_plan('gate_deadtime',.1),@()pmsm_experiment_plan('gate_deadtime',5.0625), ...
 @()pmsm_experiment_plan('angle_bias','1+2'),@()pmsm_experiment_plan('not_a_scene',1)};
for k=1:numel(invalid),rejected=false;try,invalid{k}();catch,rejected=true;end;assert(rejected);end
record.checks.invalid_inputs_rejected=numel(invalid);
catalog=pmsm_experiment_catalog;assert(numel(catalog)>=12);
for c=catalog(:)'
 if ismember(c.id,{'noise_filter','timing_deadline','sampling_window'}),continue;end % Dedicated three-case acceptance.
 p=pmsm_experiment_plan(c.id);assert(numel(pmsm_check_switches(p.cases(2).configuration))==1);
 if ismember(c.id,{'gate_deadtime_pair','low_speed_compensation'}),assert(p.numerical.reference_fixed_step_s==p.numerical.factor_fixed_step_s);
 else,assert(isequal(p.cases(1).configuration,before.configuration));end
 if ~strcmp(c.id,'low_speed_compensation'),assert(numel(p.cases(2).changes)==2);else,assert(numel(p.cases)==3);end
end
record.checks.all_current_plans_single_factor=true;

fprintf('STAGE2_FILTER_GUI\n');f=open_pmsm_experiments;fg=onCleanup(@()close(f));
selector=findall(f,'Tag','ExperimentSelector');selector.Value=4;cb=selector.Callback;cb(selector,[]);
button=findall(f,'Tag','ExperimentRun');cb=button.Callback;cb(button,[]);report=f.UserData;
assert(isstruct(report)&&strcmp(report.scenario.id,'digital_filter'));pmsm_experiment_verify(report.folder);
record.run_folders.digital_filter=report.folder;
a=load(fullfile(report.folder,'reference.mat'),'signals');reference=a.signals;a=load(fullfile(report.folder,'factor.mat'),'signals');s=a.signals;
input=teach_values(s.log_iabc_adc);actual=teach_values(s.log_iabc_filter);alpha=exp(-2*pi*1500*50e-6);
expected=filter(1-alpha,[1 -alpha],input);assert(max(abs(expected-actual),[],'all')<1e-10);
assert(isequal(s.log_iabc_filter.Data,s.log_iabc_meas.Data));record.checks.filter_recurrence_and_output=true;
mechanism=findall(f,'Tag','ExperimentMechanism');assert(strcmp(mechanism.Enable,'on'));figs=findall(groot,'Type','figure');cb=mechanism.Callback;cb(mechanism,[]);
new=setdiff(findall(groot,'Type','figure'),figs);assert(numel(new)==1);close(new);
record.checks.gui_actual_new_scene_and_mechanism=true;
selector.Value=5;cb=selector.Callback;cb(selector,[]);assert(isempty(f.UserData)&&strcmp(mechanism.Enable,'off'));clear fg;
record.checks.gui_stale_mechanism_cleared=true;

fprintf('STAGE2_ANGLE\n');[r,o]=run_pmsm_experiment('angle_bias');record.run_folders.angle_bias=r.folder;s=o{2};same(reference,o{1});
angleError=teach_values(s.log_theta_error);assert(max(abs(angleError-5*pi/180))<1e-11);
assert(isequal(s.log_iabc_true.Data,s.log_iabc_meas.Data));
theta=teach_values(s.log_theta_meas);i=teach_values(s.log_iabc_meas);al=(2*i(:,1)-i(:,2)-i(:,3))/3;be=(i(:,2)-i(:,3))/sqrt(3);
assert(max(abs(teach_values(s.log_id)-(al.*cos(theta)+be.*sin(theta))))<1e-9);
assert(max(abs(teach_values(s.log_iq)-(-al.*sin(theta)+be.*cos(theta))))<1e-9);
record.checks.angle_bias_wrap_and_dq=true;clear o;

fprintf('STAGE2_GATE\n');[r,o]=run_pmsm_experiment('gate_deadtime');record.run_folders.gate_deadtime=r.folder;s=o{2};same(reference,o{1});
requested=teach_values(s.obs_dead_requested);actual=teach_values(s.obs_dead_gates);t=s.obs_dead_gates.Time;
assert(isequal(t,s.obs_dead_requested.Time)&&numel(t)<=4000);h=median(diff(t));assert(abs(h-62.5e-9)<1e-14);
assert(all(actual(:,1:2:5)+actual(:,2:2:6)<=1,'all'));assert(all(actual<=requested,'all'));
checked=0;
for phase=1:6
 rises=find(diff(requested(:,phase))==1)+1;
 for rise=rises(:)'
  target=rise+32;if target>numel(t),continue;end
  if all(requested(rise:target,phase)==1)
   assert(all(actual(rise:target-1,phase)==0)&&actual(target,phase)==1);checked=checked+1;
  end
 end
 falls=find(diff(requested(:,phase))==-1)+1;assert(all(actual(falls,phase)==0));
end
assert(checked>=6);record.checks.gate_rising_edges_2us=checked;record.checks.gate_fall_immediate_no_overlap=true;
assert(isequal(s.log_iabc_true.Data,s.log_iabc_meas.Data));
assert(strcmp(value(r.cases(2).configuration,'功率设置','comp_on'),'off'));
record.checks.gate_compensation_and_measurement_factors_off=true;clear o;

fprintf('STAGE2_ZERO_ANGLE\n');[r,o]=run_pmsm_experiment('angle_bias',0,.05);record.run_folders.zero_angle=r.folder;same(o{1},o{2});clear o;
record.checks.zero_angle_exact_reference=true;

fprintf('STAGE2_OLD_EXPERIMENT_REGRESSION\n');
for id={'current_bias','current_noise','sample_delay'}
 [r,o]=run_pmsm_experiment(id{1});record.run_folders.(id{1})=r.folder;
 summary=jsondecode(fileread(fullfile(here,'experiments','examples',id{1},'summary.json')));pmsm_experiment_verify(summary.source_run_folder);
 for k=1:2
  labels={'reference','factor'};a=load(fullfile(summary.source_run_folder,[labels{k} '.mat']),'signals');same(a.signals,o{k});
 end
 same(reference,o{1});clear o;
end
record.checks.first_batch_retained_signals_exact_old_results=true;

tampered=fullfile(work,'tampered_mechanism');copyfile(record.run_folders.gate_deadtime,tampered);
fid=fopen(fullfile(tampered,'mechanism.png'),'a');fwrite(fid,uint8(0));fclose(fid);
rejected=false;try,pmsm_experiment_verify(tampered);catch,rejected=true;end;assert(rejected);record.checks.mechanism_tamper_rejected=true;
assert(isequaln(before,pmsm_reference('capture'))&&isequaln(geometry,teach_snapshot(mdl)));record.checks.loaded_reference_geometry_and_pi_preserved=true;
pmsm_reference('verify');assert(strcmp(record.model_sha256,teach_hash(fullfile(root,[mdl '.slx']))));record.checks.main_and_v1_unchanged=true;
record.all_passed=true;teach_writejson(fullfile(here,'experiment_stage2_validation.json'),record);fprintf('STAGE2_ALL_PASS\n');
end
function same(a,b)
for name=fieldnames(a)'
 x=a.(name{1});y=b.(name{1});assert(isequaln(x.Time,y.Time)&&isequaln(x.Data,y.Data),'回归不一致：%s',name{1});
end
end
function v=value(c,section,key)
ix=strcmp({c.rows.section},section)&strcmp({c.rows.key},key);assert(sum(ix)==1);v=c.rows(ix).value;
end
