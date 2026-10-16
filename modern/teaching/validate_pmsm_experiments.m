function record=validate_pmsm_experiments
% Separate process validation of the fixed scenario workflow and result packs.
here=fileparts(mfilename('fullpath'));root=fileparts(here);mdl='PMSM_FOC_R2026a';assert(~bdIsLoaded(mdl),'请在独立MATLAB进程检查。');
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));work=fullfile(root,'.build',['experiment_check_' stamp]);mkdir(work);
oldFolder=pwd;folderGuard=onCleanup(@()cd(oldFolder));addpath(here);cd(work);candidate=fullfile(work,[mdl '.slx']);copyfile(fullfile(root,[mdl '.slx']),candidate);
load_system(candidate);guard=onCleanup(@()close_system(mdl,0));pmsm_reference('restore');before=pmsm_reference('capture');geometry=teach_snapshot(mdl);
record=struct('all_passed',false,'model_sha256',teach_hash(fullfile(root,[mdl '.slx'])),'reference_manifest_sha256',teach_hash(fullfile(here,'reference_v1','manifest.json')), ...
 'run_folders',struct,'checks',struct);
invalid={@()pmsm_experiment_plan('current_bias',[1 2]),@()pmsm_experiment_plan('current_noise',-.1), ...
 @()pmsm_experiment_plan('sample_delay',1.5),@()pmsm_experiment_plan('sample_delay',0), ...
 @()pmsm_experiment_plan('current_bias','system(''anything'')'),@()pmsm_experiment_plan('current_noise',.02,.05001)};
for k=1:numel(invalid),failed=false;try,invalid{k}();catch,failed=true;end;assert(failed);end
assert(isequaln(before,pmsm_reference('capture')));record.checks.invalid_inputs_rejected=numel(invalid);
fprintf('EXPERIMENT_CHECK_BIAS\n');[r,bias]=run_pmsm_experiment('current_bias');record.run_folders.current_bias=r.folder;checkPack(r);
expected=[.05 -.03 0];err=teach_values(bias{2}.log_iabc_meas)-teach_values(bias{2}.log_iabc_true);
assert(max(abs(err-expected),[],'all')<1e-12,'零偏未按定义施加。');record.checks.bias_identity_passed=true;
reference=bias{1};clear bias;
fprintf('EXPERIMENT_CHECK_NOISE\n');[r,noise]=run_pmsm_experiment('current_noise');record.run_folders.current_noise=r.folder;checkPack(r);same(reference,noise{1});
err=teach_values(noise{2}.log_iabc_meas)-teach_values(noise{2}.log_iabc_true);raw=teach_values(noise{2}.log_iabc_noise);
assert(max(abs(err-raw),[],'all')<1e-12);rmsValue=r.cases(2).metrics.measurement_rms_error_ABC_A;
assert(all(rmsValue>.015&rmsValue<.025));record.checks.noise_identity_passed=true;noiseFactor=noise{2};clear noise;
fprintf('EXPERIMENT_CHECK_DELAY\n');[r,delay]=run_pmsm_experiment('sample_delay');record.run_folders.sample_delay=r.folder;checkPack(r);same(reference,delay{1});
measured=teach_values(delay{2}.log_iabc_meas);truth=teach_values(delay{2}.log_iabc_true);
assert(max(abs(measured(2:end,:)-truth(1:end-1,:)),[],'all')<1e-10,'一拍延迟时序不符。');record.checks.one_cycle_delay_passed=true;clear delay;
fprintf('EXPERIMENT_CHECK_ZERO_BIAS\n');[r,zero]=run_pmsm_experiment('current_bias',[0 0 0],.05);record.run_folders.zero_bias=r.folder;checkPack(r);same(zero{1},zero{2});clear zero;
record.checks.zero_bias_same_as_reference=true;
fprintf('EXPERIMENT_CHECK_NOISE_REPEAT\n');[r,repeated]=run_pmsm_experiment('current_noise');record.run_folders.noise_repeat=r.folder;checkPack(r);same(reference,repeated{1});same(noiseFactor,repeated{2});clear repeated noiseFactor reference;
record.checks.reference_repeated_across_scenarios=true;record.checks.noise_repeated_across_runs=true;
mw=get_param(mdl,'ModelWorkspace');assignin(mw,'n',1100);failed=false;try,run_pmsm_experiment('current_noise');catch,failed=true;end
assert(failed&&getVariable(mw,'n')==1100);pmsm_reference('restore');record.checks.nonreference_not_overwritten=true;
tampered=fullfile(work,'tampered_result');copyfile(r.folder,tampered);fid=fopen(fullfile(tampered,'comparison.png'),'a');fwrite(fid,uint8(0));fclose(fid);
failed=false;try,pmsm_experiment_verify(tampered);catch,failed=true;end;assert(failed);record.checks.mixed_or_tampered_result_rejected=true;
fprintf('EXPERIMENT_CHECK_GUI\n');f=open_pmsm_experiments;fg=onCleanup(@()close(f));
selector=findall(f,'Tag','ExperimentSelector');selector.Value=2;cb=selector.Callback;cb(selector,[]);
edit=findall(f,'Tag','ExperimentValue');edit.String='.03';
button=findall(f,'Tag','ExperimentRun');cb=button.Callback;cb(button,[]);gui=f.UserData;
assert(isstruct(gui)&&strcmp(gui.scenario.id,'current_noise')&&gui.factor_value==.03);checkPack(gui);record.run_folders.gui_noise=gui.folder;
record.checks.gui_actual_run_callback_passed=true;
selector.Value=3;cb=selector.Callback;cb(selector,[]);assert(isempty(f.UserData),'切换实验后仍关联旧结果。');record.checks.gui_stale_report_cleared=true;clear fg;
assert(isequaln(before,pmsm_reference('capture'))&&isequaln(geometry,teach_snapshot(mdl)));record.checks.loaded_reference_preserved=true;
pmsm_reference('verify');assert(strcmp(record.model_sha256,teach_hash(fullfile(root,[mdl '.slx']))));record.checks.main_and_v1_reference_unchanged=true;
record.all_passed=true;teach_writejson(fullfile(here,'experiment_validation.json'),record);
fprintf('EXPERIMENTS_ALL_PASS\n');
end

function same(a,b)
names=fieldnames(a);assert(isequal(names,fieldnames(b)));
for k=1:numel(names),x=a.(names{k});y=b.(names{k});assert(isequaln(x.Time,y.Time)&&isequaln(x.Data,y.Data),'复现不一致：%s',names{k});end
end

function checkPack(r)
pmsm_experiment_verify(r.folder);assert(r.restored_reference&&r.main_model_unchanged);
assert(numel(pmsm_check_switches(r.cases(1).configuration))==0&&numel(pmsm_check_switches(r.cases(2).configuration))==1);
assert(numel(r.cases(2).changes)==2&&r.cases(1).available_signal_count==52&&r.cases(2).available_signal_count==52);
end
