function report=validate_switch_baseline
% Independent worker: no numerical source edits, all overrides are temporary.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'teaching'));
m='PMSM_FOC_R2026a';assert(~bdIsLoaded(m));load_system(fullfile(root,[m '.slx']));guard=onCleanup(@()close_system(m,0));pmsm_reference('restore');
original=teach_snapshot(m);hash=teach_hash(fullfile(root,[m '.slx']));cfg=pmsm_config('read');cases={};
cases{end+1}=make_case('off',{});
cases{end+1}=make_case('dormant_parameters',{'采样设置','phase_gain','[1.07 .95 1.02]';'采样设置','bias_A','[.2 -.1 .05]';'采样设置','noise_rms','.04';'采样设置','noise_seed','123';'采样设置','adc_bits','8';'采样设置','adc_span','2';'采样设置','filter_hz','700';'采样设置','analog_hz','1300';'采样设置','delay_cycles','3';'角度设置','bias_deg','7';'角度设置','step_deg','3';'角度设置','delay_cycles','3';'功率设置','dead_us','2';'功率设置','gate_us','2';'功率设置','comp_us','2';'功率设置','ron','.08';'功率设置','vf','.7';'时序设置','speed_divider','4';'时序设置','pwm_cycles','3';'时序设置','trigger_us','10';'时序设置','compute_us','15';'时序设置','sync_us','1';'时序设置','settle_us','1';'时序设置','update_mode','仅谷底（对照）';'时序设置','grid_divider','2'});
cases{end+1}=make_case('noise_zero',{'采样设置','noise_on','on';'采样设置','noise_rms','0'});
cases{end+1}=make_case('angle_bias_zero',{'角度设置','bias_on','on';'角度设置','bias_deg','0'});
cases{end+1}=make_case('average_dead_zero',{'功率设置','dead_on','on';'功率设置','dead_us','0'});
cases{end+1}=make_case('drop_zero_ideal',{'功率设置','drop_on','on';'功率设置','ron','0';'功率设置','vf','0'});
cases{end+1}=make_case('measurement_neutral_combination',{'采样设置','gain_on','on';'采样设置','phase_gain','[1 1 1]';'采样设置','bias_on','on';'采样设置','bias_A','[0 0 0]';'采样设置','noise_on','on';'采样设置','noise_rms','0'});
cases{end+1}=make_case('gate_zero',{'功率设置','gate_on','on';'功率设置','gate_us','0'});
cases{end+1}=make_case('gate_two',{'功率设置','gate_on','on';'功率设置','gate_us','2'});
cases{end+1}=make_case('comp_zero',{'功率设置','gate_on','on';'功率设置','gate_us','2';'功率设置','comp_on','on';'功率设置','comp_us','0'});
cases{end+1}=make_case('drop_zero_detailed',{'功率设置','gate_on','on';'功率设置','gate_us','2';'功率设置','drop_on','on';'功率设置','ron','0';'功率设置','vf','0'});
cases{end+1}=make_case('measurement_combination',{'采样设置','gain_on','on';'采样设置','phase_gain','[1.03 .98 1.01]';'采样设置','bias_on','on';'采样设置','bias_A','[.1 -.2 .05]';'采样设置','noise_on','on';'采样设置','noise_rms','.02';'采样设置','adc_on','on';'采样设置','adc_bits','8';'采样设置','adc_span','2';'采样设置','filter_on','on';'采样设置','filter_hz','700'});
out=cell(1,numel(cases));rows=cell(size(out));physical={'obs_state','log_speed','log_Te','log_Tcm_requested','log_Tcm_applied'};comparisons=0;
for k=1:numel(cases)
 fprintf('SWITCH_BASELINE %s\n',cases{k}.id);in=Simulink.SimulationInput(m);in=in.setModelParameter('StopTime','.002');
 changes=cases{k}.changes;for j=1:size(changes,1),in=in.setBlockParameter([m '/' changes{j,1}],changes{j,2},changes{j,3});end
 out{k}=sim(in);s=out{k};names=s.who;
 for name=names(:)',v=s.get(name{1});if isa(v,'timeseries'),assert(all(isfinite(v.Data),'all'),'非有限记录：%s/%s',cases{k}.id,name{1});end,end
 baseline=0;
 if ismember(k,2:7),baseline=1;elseif ismember(k,[10 11]),baseline=9;end
 if baseline
  for name=physical,a=out{baseline}.get(name{1});b=s.get(name{1});assert(isequaln(a.Time,b.Time)&&isequaln(a.Data,b.Data),'物理回归不符：%s/%s',cases{k}.id,name{1});comparisons=comparisons+1;end
 end
 if k==3||k==7,assert(all(s.log_iabc_noise.Data==0,'all'));end
 if k==4,assert(all(s.log_theta_error.Data==0,'all'));end
 if k==8,assert(isequal(s.obs_dead_requested.Time,s.obs_dead_gates.Time)&&isequal(s.obs_dead_requested.Data,s.obs_dead_gates.Data),'零死区门极不一致。');end
 if k==10,v=teach_values(s.obs_dead_comp);assert(all(v(:,1:3)==0,'all'),'零补偿仍注入电压。');end
 if k==12
  truth=teach_values(s.log_iabc_true);noise=teach_values(s.log_iabc_noise);adc=teach_values(s.log_iabc_adc);v=truth.*[1.03 .98 1.01]+[.1 -.2 .05]+noise;
  q=4/256;expected=min(2-q,max(-2,round(v/q)*q));assert(max(abs(adc-expected),[],'all')<1e-12);
  alpha=exp(-2*pi*700*50e-6);expected=filter(1-alpha,[1 -alpha],adc);actual=teach_values(s.log_iabc_meas);assert(max(abs(expected-actual),[],'all')<1e-12);
 end
 rows{k}=struct('id',cases{k}.id,'physical_reference_case',baseline,'duration_s',.002);
end
assert(isequaln(original,teach_snapshot(m))&&isequaln(cfg,pmsm_config('read')));
contract=check_switch_contracts(m,cfg,original);
assert(strcmp(hash,teach_hash(fullfile(root,[m '.slx'])))&&isequaln(original,teach_snapshot(m)));
target=fullfile(root,'signal_chain','switch_baseline');if ~isfolder(target),mkdir(target);end
cache=fullfile(root,'.build','switch_baseline');if ~isfolder(cache),mkdir(cache);end
save(fullfile(cache,'runs.mat'),'out','cases','-v7.3');
report=struct('passed',true,'model_sha256',hash,'cases',{rows},'exact_physical_record_comparisons',comparisons,'combination_tests',contract.combination_tests,'accepted_combinations',contract.accepted,'rejected_combinations',contract.rejected,'transactional_rejections',contract.transactional_rejections,'original_state_preserved',true,'raw_cache_sha256',teach_hash(fullfile(cache,'runs.mat')),'scope','2ms zero/disabled/combined behavior; zero gate uses detailed bridge, not ideal baseline; not long-term stability or exhaustive combinations.');
teach_writejson(fullfile(target,'validation.json'),report);disp('SWITCH_BASELINE_VALIDATED');
end
function c=make_case(id,changes)
c=struct('id',id,'changes',{changes});
end
function result=check_switch_contracts(m,cfg,original)
% Combination rules are independently enumerated, not copied from catalog rows.
catalog=pmsm_switch_catalog;ids=strcat({catalog.section},'.',{catalog.key});assert(numel(ids)==19);
tests={[]};for a=1:19,tests{end+1}=a;for b=a+1:19,tests{end+1}=[a b];end,end
tests{end+1}=find(ismember(ids,{'时序设置.real_on','时序设置.window_on','时序设置.invalid_hold_on'}));
tests{end+1}=find(ismember(ids,{'功率设置.gate_on','功率设置.comp_on','功率设置.drop_on'}));
accepted=0;rejected=0;
for indices=tests
 enabled=ids(indices{1});c=cfg;for j=1:19,c=setcfg(c,catalog(j).section,catalog(j).key,onoff(ismember(ids{j},enabled)));end
 real=ismember('时序设置.real_on',enabled);window=ismember('时序设置.window_on',enabled);holdInvalid=ismember('时序设置.invalid_hold_on',enabled);
 comp=ismember('功率设置.comp_on',enabled);gate=ismember('功率设置.gate_on',enabled);average=ismember('功率设置.dead_on',enabled);
 pwm=ismember('时序设置.pwm_on',enabled);delay=ismember('采样设置.delay_on',enabled);
 valid=~((window&&~real)||(holdInvalid&&(~real||~window))||(comp&&~gate)||(real&&(pwm||delay))||(average&&gate));
 ok=true;try,pmsm_check_switches(c);catch err,assert(ismember(err.identifier,{'pmsm:SwitchDependency','pmsm:SwitchConflict'}));ok=false;end
 assert(ok==valid,'组合规则不一致。');if ok,accepted=accepted+1;else,rejected=rejected+1;end
end
% Exercise actual transactional apply, not only the pure preflight function.
invalid={{'时序设置','real_on','on';'采样设置','delay_on','on'}, {'时序设置','real_on','on';'时序设置','pwm_on','on'}, {'功率设置','gate_on','on';'功率设置','dead_on','on'}, {'功率设置','comp_on','on'}, {'时序设置','window_on','on'}, {'时序设置','invalid_hold_on','on'}};
for changes=invalid,c=cfg;v=changes{1};for j=1:size(v,1),c=setcfg(c,v{j,1},v{j,2},v{j,3});end;rejectApply(c,m,cfg,original);end
% Zero is not a legal delay length or quantization/filter setting in this model.
invalidZero={'采样设置','delay_cycles';'角度设置','delay_cycles';'时序设置','pwm_cycles';'角度设置','step_deg';'采样设置','filter_hz';'采样设置','analog_hz';'采样设置','adc_span'};
for j=1:size(invalidZero,1),rejectApply(setcfg(cfg,invalidZero{j,1},invalidZero{j,2},'0'),m,cfg,original);end
result=struct('combination_tests',numel(tests),'accepted',accepted,'rejected',rejected,'transactional_rejections',numel(invalid)+size(invalidZero,1));
end
function rejectApply(c,m,cfg,original)
failed=false;try,pmsm_config('apply',c);catch,failed=true;end
assert(failed,'无效配置未拒绝。');assert(isequaln(cfg,pmsm_config('read'))&&isequaln(original,teach_snapshot(m)),'拒绝配置后未恢复。');
end
function c=setcfg(c,section,key,value)
i=find(strcmp({c.rows.section},section)&strcmp({c.rows.key},key));assert(isscalar(i));c.rows(i).value=value;
end
function s=onoff(v)
if v,s='on';else,s='off';end
end
