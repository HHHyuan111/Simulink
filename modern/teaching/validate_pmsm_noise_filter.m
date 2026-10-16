function report=validate_pmsm_noise_filter(phase)
% Independent engines for GUI/default, numeric replay, parameters, regression.
here=fileparts(mfilename('fullpath'));root=fileparts(here);
if nargin<1
 executable=fullfile(matlabroot,'bin','matlab.exe');quotedHere=strrep(here,'''','''''');
 for part={'default','repeat','parameters','finish'}
  command=sprintf('"%s" -batch "addpath(''%s''); validate_pmsm_noise_filter(''%s'')"',executable,quotedHere,part{1});
  [status,output]=system(command);fprintf('%s',output);assert(status==0,'噪声滤波验收阶段失败：%s',part{1});
 end
 report=jsondecode(fileread(fullfile(here,'experiment_noise_filter_validation.json')));assert(report.all_passed);return
end
assert(ismember(phase,{'default','repeat','parameters','finish'}));mdl='PMSM_FOC_R2026a';assert(~bdIsLoaded(mdl));
work=fullfile(root,'.build',['noise_filter_check_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);mkdir(work);
old=pwd;cg=onCleanup(@()cd(old));cd(work);addpath(here);candidate=fullfile(work,[mdl '.slx']);copyfile(fullfile(root,[mdl '.slx']),candidate);
load_system(candidate);mg=onCleanup(@()close_system(mdl,0));pmsm_reference('restore');before=pmsm_reference('capture');geometry=teach_snapshot(mdl);
checkpoint=fullfile(root,'.build','noise_filter_validation_checkpoint.json');
if strcmp(phase,'default')
 report=struct('all_passed',false,'matlab_version',version,'model_sha256',teach_hash(fullfile(root,[mdl '.slx'])), ...
  'reference_manifest_sha256',teach_hash(fullfile(here,'reference_v1','manifest.json')),'run_folders',struct,'checks',struct);
else
 report=jsondecode(fileread(checkpoint));assert(~report.all_passed);
 assert(strcmp(report.model_sha256,teach_hash(fullfile(root,[mdl '.slx'])))&&strcmp(report.reference_manifest_sha256,teach_hash(fullfile(here,'reference_v1','manifest.json'))));
 r=pmsm_experiment_verify(report.run_folders.default_three);
 for file=r.source_files(:)',assert(strcmp(teach_hash(fullfile(here,file.path)),file.sha256),'阶段间运行脚本已改变。');end
end
switch phase
 case 'default'
  for name={'pmsm_experiment_catalog','pmsm_experiment_plan','run_pmsm_experiment','plot_pmsm_noise_filter','pmsm_noise_filter_analysis','pmsm_experiment_verify','open_pmsm_experiments','export_pmsm_experiment_examples','validate_pmsm_noise_filter'}
   issues=checkcode(fullfile(here,[name{1} '.m']),'-id');assert(~any(strcmp({issues.id},'PARSE')),'语法错误：%s',name{1});
  end
  catalog=pmsm_experiment_catalog;assert(numel(catalog)>=12);p=pmsm_experiment_plan('noise_filter');assert(numel(p.cases)==3&&isequal(p.value,[.02 1500]));
  column=pmsm_experiment_plan('noise_filter',[.02;1500]);assert(isequal(p,column));
  for k=1:2
   a=p.cases(k).configuration.rows;b=p.cases(k+1).configuration.rows;differs=arrayfun(@(j)~isequaln(a(j),b(j)),1:numel(a));
   expected={'noise_on','filter_on'};assert(sum(differs)==1&&strcmp(a(differs).key,expected{k}));
  end
  for k=1:3,assert(numel(pmsm_check_switches(p.cases(k).configuration))==k-1);end
  report.checks.only_adjacent_noise_then_filter_switch_changes=true;
  invalid={[-.01 1500],[2.01 1500],[.02 99],[.02 9001],[.02 10000],[NaN 1500],[.02 Inf],[.02 1500 1],.02,'0.02+1 1500'};
  for k=1:numel(invalid),rejected=false;try,pmsm_experiment_plan('noise_filter',invalid{k});catch,rejected=true;end;assert(rejected);end
  report.checks.invalid_inputs_rejected=numel(invalid);
  fprintf('NOISE_FILTER_GUI_DEFAULT\n');f=open_pmsm_experiments;fg=onCleanup(@()close(f));selector=findall(f,'Tag','ExperimentSelector');selector.Value=9;cb=selector.Callback;cb(selector,[]);
  noise=findall(f,'Tag','ExperimentValue');cutoff=findall(f,'Tag','ExperimentFilterHz');assert(strcmp(cutoff.Visible,'on')&&str2double(noise.String)==.02&&str2double(cutoff.String)==1500);
  button=findall(f,'Tag','ExperimentRun');noise.String='0.02+1';cb=button.Callback;cb(button,[]);assert(isempty(f.UserData)&&strcmp(get_param(mdl,'SimulationStatus'),'stopped'));
  noise.String='.02';cutoff.String='1500';cb(button,[]);r=f.UserData;assert(isstruct(r)&&strcmp(r.scenario.id,'noise_filter')&&numel(r.cases)==3&&isequal(r.factor_value,[.02 1500]));
  pmsm_experiment_verify(r.folder);report.run_folders.default_three=r.folder;outputs=loadCases(r);
  for k=1:3
   s=outputs{k};assert(numel(fieldnames(s))==21&&all(teach_values(s.log_nref)==3000)&&all(abs(teach_values(s.log_TL)-.207)<1e-12));
   assert(abs(median(diff(s.log_iabc_true.Time))-50e-6)<1e-12&&abs(median(diff(s.obs_current_fast.Time))-1e-6)<1e-12);
  end
  a=jsondecode(fileread(fullfile(r.folder,'analysis.json')));report.analysis=a;report.metrics=r.cases;
  assert(a.same_injected_sequence&&max([a.cases.decomposition_max_abs_error_A])<1e-10);
  s=outputs{3};x=teach_values(s.log_iabc_adc);y=teach_values(s.log_iabc_filter);expected=zeros(size(x));last=zeros(1,3);alpha=exp(-2*pi*1500*50e-6);
  for row=1:size(x,1),last=(1-alpha)*x(row,:)+alpha*last;expected(row,:)=last;end
  assert(max(abs(expected-y),[],'all')<1e-10);theta=teach_values(s.log_theta_meas);alphaCurrent=(2*y(:,1)-y(:,2)-y(:,3))/3;betaCurrent=(y(:,2)-y(:,3))/sqrt(3);
  truth=teach_values(s.log_iabc_true);injected=teach_values(s.log_iabc_noise);
  assert(isequal(outputs{2}.log_iabc_noise.Data,s.log_iabc_noise.Data));
  assert(max(abs(y-filter(1-alpha,[1 -alpha],truth)-filter(1-alpha,[1 -alpha],injected)),[],'all')<1e-10);
  assert(max(abs(teach_values(s.log_id)-(alphaCurrent.*cos(theta)+betaCurrent.*sin(theta))))<1e-9);
  assert(max(abs(teach_values(s.log_iq)-(-alphaCurrent.*sin(theta)+betaCurrent.*cos(theta))))<1e-9);
  report.checks.existing_filter_recurrence_and_park_path=true;report.checks.same_noise_and_linear_decomposition=true;
  historical=jsondecode(fileread(fullfile(here,'experiment_reproducibility_validation.json')));legacy=pmsm_experiment_verify(historical.run_folders.current_noise);oldSignals=loadCases(legacy);
  same(oldSignals{1},outputs{1});same(oldSignals{2},outputs{2});report.checks.historical_noise_two_cases_21_signals_preserved=true;
  mechanism=findall(f,'Tag','ExperimentMechanism');assert(strcmp(mechanism.Enable,'on'));figs=findall(groot,'Type','figure');cb=mechanism.Callback;cb(mechanism,[]);
  extra=setdiff(findall(groot,'Type','figure'),figs);assert(numel(extra)==1);close(extra);
  cutoff.String='750';cb=cutoff.Callback;cb(cutoff,[]);assert(isempty(f.UserData)&&strcmp(mechanism.Enable,'off'));
  selector.Value=1;cb=selector.Callback;cb(selector,[]);assert(strcmp(cutoff.Visible,'off'));
  report.checks.gui_two_fields_run_page_and_stale_clear=true;clear fg;
 case 'repeat'
  fprintf('NOISE_FILTER_REPEAT\n');[again,v]=repeat_pmsm_experiment(r.folder);assert(v.same_matlab_version&&v.all_exact&&numel(v.signals)==63);
  report.run_folders.repeated_three=again.folder;report.checks.default_all_63_signals_repeated=true;
 case 'parameters'
  assert(report.checks.default_all_63_signals_repeated);fprintf('NOISE_FILTER_PARAMETER_CHANGE\n');[custom,o]=run_pmsm_experiment('noise_filter',[.04 750],.05);
  report.run_folders.custom_three=custom.folder;a=jsondecode(fileread(fullfile(custom.folder,'analysis.json')));
  assert(a.filter_hz==750&&a.same_injected_sequence);original=load(fullfile(r.folder,'factor.mat'),'signals');oldNoise=teach_values(original.signals.log_iabc_noise);newNoise=teach_values(o{2}.log_iabc_noise);
  assert(isequal(newNoise,2*oldNoise(1:size(newNoise,1),:)),'同种子噪声幅值未按设置缩放。');
  report.checks.changed_noise_amplitude_and_cutoff_take_effect=true;report.custom_analysis=a;
 case 'finish'
  assert(report.checks.default_all_63_signals_repeated&&report.checks.changed_noise_amplitude_and_cutoff_take_effect);
  fprintf('NOISE_FILTER_ZERO_NOISE\n');[zero,o]=run_pmsm_experiment('noise_filter',[0 1500],.05);report.run_folders.zero_noise=zero.folder;same(o{1},o{2});
  a=jsondecode(fileread(fullfile(zero.folder,'analysis.json')));assert(all(a.cases(3).noise_component_rms_ABC_A==0));
  filteredZero=o{3};referenceZero=o{1};clear o;
  fprintf('NOISE_FILTER_STANDALONE_FILTER\n');[legacy,o]=run_pmsm_experiment('digital_filter',1500,.05);report.run_folders.standalone_filter=legacy.folder;
  same(referenceZero,o{1});same(filteredZero,o{2});report.checks.zero_noise_bypass_and_standalone_filter_match=true;
  assert(~isequaln(filteredZero.log_id.Data,referenceZero.log_id.Data),'零噪声时滤波仍应保留其确定性影响。');
  tamper=fullfile(work,'tampered_filtered');copyfile(r.folder,tamper);fid=fopen(fullfile(tamper,'filtered.mat'),'a');fwrite(fid,uint8(0));fclose(fid);
  rejected=false;try,pmsm_experiment_verify(tamper);catch,rejected=true;end;assert(rejected);report.checks.third_case_tamper_rejected=true;
end
assert(isequaln(before,pmsm_reference('capture'))&&isequaln(geometry,teach_snapshot(mdl)));pmsm_reference('verify');
assert(strcmp(report.model_sha256,teach_hash(fullfile(root,[mdl '.slx']))));report.checks.main_reference_pi_layout_unchanged=true;
if strcmp(phase,'finish')
 report.all_passed=true;teach_writejson(fullfile(here,'experiment_noise_filter_validation.json'),report);fprintf('NOISE_FILTER_ALL_PASS\n');
else
 teach_writejson(checkpoint,report);fprintf('NOISE_FILTER_PHASE_PASS %s\n',phase);
end
end
function outputs=loadCases(r)
outputs=cell(1,numel(r.cases));for k=1:numel(r.cases),u=load(fullfile(r.folder,[r.cases(k).id '.mat']),'signals');outputs{k}=u.signals;end
end
function same(a,b)
names=fieldnames(a);assert(isequal(sort(names),sort(fieldnames(b))));
for name=names',x=a.(name{1});y=b.(name{1});assert(isequaln(x.Time,y.Time)&&isequaln(x.Data,y.Data),'信号不一致：%s',name{1});end
end
