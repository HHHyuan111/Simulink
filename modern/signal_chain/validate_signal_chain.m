function report=validate_signal_chain
root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'teaching'),fullfile(root,'layout','appearance'));
m='PMSM_FOC_R2026a';assert(~bdIsLoaded(m));load_system(fullfile(root,[m '.slx']));guard=onCleanup(@()close_system(m,0));
pmsm_reference('restore');original=teach_snapshot(m);hash=teach_hash(fullfile(root,[m '.slx']));referenceHash=teach_hash(fullfile(root,'teaching','reference_v1','manifest.json'));
folder=fullfile(root,'.build','signal_chain');cases={};
add('off',{});add('gain_neutral',{'gain_on','on';'phase_gain','[1 1 1]'});
add('bias_neutral',{'bias_on','on';'bias_A','[0 0 0]'});
add('gain',{'gain_on','on';'phase_gain','[1.03 .98 1.01]'});
add('bias',{'bias_on','on';'bias_A','[.1 -.2 .05]'});
add('noise_small',{'noise_on','on';'noise_rms','.02'});add('noise_large',{'noise_on','on';'noise_rms','.04'});
add('adc8',{'adc_on','on';'adc_bits','8';'adc_span','2'});add('adc10',{'adc_on','on';'adc_bits','10';'adc_span','2'});
add('filter500',{'filter_on','on';'filter_hz','500'});add('filter2000',{'filter_on','on';'filter_hz','2000'});
add('delay1',{'delay_on','on';'delay_cycles','1'});add('delay2',{'delay_on','on';'delay_cycles','2'});
add('analog',{'analog_on','on';'analog_hz','2000'});
add('real',{}, {'real_on','on'});add('real_div4',{}, {'real_on','on';'speed_on','on';'speed_divider','4'});
add('early_fast',{}, {'real_on','on';'trigger_us','10';'compute_us','5'});
add('early_slow',{}, {'real_on','on';'trigger_us','10';'compute_us','15'});
add('early_valley',{}, {'real_on','on';'trigger_us','10';'compute_us','5';'update_mode','仅谷底（对照）'});
add('real_adc8',{'adc_on','on';'adc_bits','8';'adc_span','2'},{'real_on','on'});
out=cell(1,numel(cases));checks=cell(1,numel(cases));
for k=1:numel(cases)
 fprintf('CHAIN_CASE %s\n',cases{k}.id);out{k}=sim(input(cases{k}));s=out{k};t=s.log_iabc_true.Time;
 truth=teach_values(s.log_iabc_true);adc=teach_values(s.log_iabc_adc);filtered=teach_values(s.log_iabc_filter);meas=teach_values(s.log_iabc_meas);
 assert(isequal(t,s.log_iabc_adc.Time,s.log_iabc_filter.Time,s.log_iabc_meas.Time,s.log_iabc_noise.Time));
 values={s.log_iabc_true,s.log_iabc_adc,s.log_iabc_filter,s.log_iabc_meas,s.log_speed};
 for v=values,assert(all(isfinite(teach_values(v{1})),'all'));end
 err=0;
 switch cases{k}.id
  case {'off','gain_neutral','bias_neutral'},err=max(abs(meas-truth),[],'all');
  case 'gain',err=max(abs(adc-truth.*[1.03 .98 1.01]),[],'all');
  case 'bias',err=max(abs(adc-truth-[.1 -.2 .05]),[],'all');
  case {'noise_small','noise_large'},err=max(abs(adc-truth-teach_values(s.log_iabc_noise)),[],'all');
  case {'adc8','adc10'}
   bits=8;if strcmp(cases{k}.id,'adc10'),bits=10;end;quantum=4/2^bits;
   expected=min(2-quantum,max(-2,round(truth/quantum)*quantum));err=max(abs(adc-expected),[],'all');
   assert(all(adc>=-2&adc<=2-quantum,'all'));assert(any(abs(truth)>2,'all'),'量程试验未触发饱和。');
  case {'filter500','filter2000'}
   hz=500;if strcmp(cases{k}.id,'filter2000'),hz=2000;end;alpha=exp(-2*pi*hz*50e-6);
   expected=filter(1-alpha,[1 -alpha],adc);err=max(abs(filtered-expected),[],'all');assert(isequal(filtered,meas));
  case {'delay1','delay2'}
   count=1;if strcmp(cases{k}.id,'delay2'),count=2;end;expected=[zeros(count,3);filtered(1:end-count,:)];
   err=max(abs(meas-expected),[],'all');
  case 'analog',assert(max(abs(adc-truth),[],'all')>.01,'模拟低通未表现差异。');
  otherwise
   d=teach_values(s.obs_adc_timing);tt=s.obs_adc_timing.Time;jeos=tt(d(:,6)>.5);trigger=24.375e-6;
   if startsWith(cases{k}.id,'early'),trigger=10e-6;end
   expected=(trigger+4.5e-6)+(0:numel(jeos)-1)'*50e-6;assert(max(abs(jeos-expected))<1e-12);
   count=2;if strcmp(cases{k}.id,'real_div4'),count=4;end
   speedTimes=tt(d(:,14)>.5);assert(max(abs(speedTimes-(trigger+4.5e-6+(count-1)*50e-6+(0:numel(speedTimes)-1)'*count*50e-6)))<1e-12);
   assert(max(abs(adc-meas),[],'all')<1e-12,'真实模式不应暗加旧滤波或整拍延迟。');
   if strcmp(cases{k}.id,'real_adc8')
    sampleIndex=round((t-tt(1))/62.5e-9)+1;captured=d(sampleIndex,10:12);quantum=4/256;
    expected=min(2-quantum,max(-2,round(captured/quantum)*quantum));err=max(abs(adc-expected),[],'all');
    codes=teach_values(s.obs_adc_codes);referenceCodes=min(4095,max(0,round(2048+captured/(165/4096))));
    assert(isequal(codes,referenceCodes),'固定12bit诊断参考码定义不匹配。');
   end
 end
 assert(err<1e-9,'信号方程不匹配：%s',cases{k}.id);checks{k}=struct('case',cases{k}.id,'formula_max_error_A',err);
end
% Compare common physical states rather than continuous-vs-held diagnostic traces.
for k=[2 3]
 for name={'obs_state','log_speed','log_Te','log_Tcm_requested','log_Tcm_applied'}
  a=out{1}.get(name{1});b=out{k}.get(name{1});assert(isequaln(a.Time,b.Time)&&isequaln(a.Data,b.Data),'零幅值未回归：%s',name{1});
 end
end
assert(isequal(2*teach_values(out{6}.log_iabc_noise),teach_values(out{7}.log_iabc_noise)),'固定种子幅值未按比例变化。');
eventChecks=cell(1,3);
for j=1:3
 k=16+j;s=out{k};d=teach_values(s.obs_pwm_timing);t=s.obs_pwm_timing.Time;
 writes=t(d(:,4)>.5);latches=t(d(:,5)>.5);compute=5e-6;if j==2,compute=15e-6;end
 assert(abs(writes(1)-(14.5e-6+compute))<1e-12);
 expectedLatch=25e-6;if j>=2,expectedLatch=50e-6;end
 assert(abs(latches(1)-expectedLatch)<1e-12);
 applied=teach_values(s.log_Tcm_applied);assert(all(isfinite(applied),'all'));
 delay=d(d(:,5)>.5,9);assert(max(abs(delay-(expectedLatch-14.5e-6)))<1e-12);
 eventChecks{j}=struct('case',cases{k}.id,'first_write_us',writes(1)*1e6,'first_latch_us',latches(1)*1e6,'jeos_to_latch_us',delay(1)*1e6);
end
% Validate the view with off, ADC quantization, and actual event timing.
pmsm_presentation('apply');pmsm_signal_chain_view('apply');logChecks=0;
for k=[1 8 15]
 observed=sim(input(cases{k}));names=out{k}.who;
 for name=names(:)'
  a=out{k}.get(name{1});if ~isa(a,'timeseries'),continue;end;b=observed.get(name{1});
  assert(isequaln(a.Time,b.Time)&&isequaln(a.Data,b.Data),'局部整理改变日志：%s',name{1});logChecks=logChecks+1;
 end
end
% Existing APIs must be able to remove/restore the local view on both paths.
pmsm_presented_call(@()assert(~pmsm_signal_chain_view('installed')));assert(pmsm_signal_chain_view('installed'));
try,pmsm_presented_call(@()error('pmsm:ChainTest','intentional'));catch err,assert(strcmp(err.identifier,'pmsm:ChainTest'));end
assert(pmsm_signal_chain_view('installed'));pmsm_signal_chain_view('remove');pmsm_presentation('remove');
assert(isequaln(original,teach_snapshot(m)));
compiled=validate_timing_contract(m);
% Conflict checks happen before config application, without mutating parameters.
config=pmsm_config('read');bad=config;setSwitch('时序设置','real_on');setSwitch('采样设置','delay_on');reject(bad);
bad=config;setSwitch('时序设置','real_on');setSwitch('时序设置','pwm_on');reject(bad);assert(isequaln(config,pmsm_config('read')));
displayConfig=pmsm_sampling_labels(config);i=find(strcmp({config.rows.section},'采样设置')&strcmp({config.rows.key},'adc_span'));
assert(strcmp(displayConfig.rows(i).label,'ADC双极量程 ± [A]')&&strcmp(displayConfig.rows(i).value,config.rows(i).value));
assert(strcmp(hash,teach_hash(fullfile(root,[m '.slx'])))&&strcmp(referenceHash,teach_hash(fullfile(root,'teaching','reference_v1','manifest.json'))));
report=struct('passed',true,'cases',{checks},'event_checks',{eventChecks},'compiled_tasks',{compiled},'exact_view_original_log_checks',logChecks,...
 'zero_magnitude_physical_regression',true,'noise_amplitude_ratio_exact',true,'conflicts_rejected',2,...
 'view_normal_exception_restore',true,'original_graph_restored',true,'model_sha256',hash,'reference_manifest_sha256',referenceHash);
save(fullfile(folder,'audit_runs.mat'),'out','cases','report','-v7.3');teach_writejson(fullfile(root,'signal_chain','validation.json'),report);disp('SIGNAL_CHAIN_VALIDATED');
 function add(id,sampling,timing)
  if nargin<3,timing={};end;cases{end+1}=struct('id',id,'sampling',{sampling},'timing',{timing});
 end
 function in=input(c)
  in=Simulink.SimulationInput(m);in=in.setModelParameter('StopTime','.002');
  % Audit the complete 2ms event sequence; normal UI tail limits stay unchanged.
  in=in.setBlockParameter([m '/采样设置/记录_obs_adc_timing'],'MaxDataPoints','inf');
  in=in.setBlockParameter([m '/输出延迟/记录_obs_pwm_timing'],'MaxDataPoints','inf');
  for j=1:size(c.sampling,1),in=in.setBlockParameter([m '/采样设置'],c.sampling{j,1},c.sampling{j,2});end
  for j=1:size(c.timing,1),in=in.setBlockParameter([m '/时序设置'],c.timing{j,1},c.timing{j,2});end
 end
 function setSwitch(section,key)
  ix=find(strcmp({bad.rows.section},section)&strcmp({bad.rows.key},key));bad.rows(ix).value='on';
 end
 function reject(c)
  rejected=false;try,pmsm_check_switches(c);catch err,rejected=strcmp(err.identifier,'pmsm:SwitchConflict');end;assert(rejected);
 end
end
function rows=validate_timing_contract(m)
path=[m '/时序设置'];old=get_param(path,'MaskValues');closer=onCleanup(@()set_param(path,'MaskValues',old));rows={};
for divider=[2 4]
 set_param(path,'real_on','on','speed_on','on','speed_divider',num2str(divider));set_param(m,'SimulationCommand','update');
 feval(m,[],[],[],'compile');finish=onCleanup(@()feval(m,[],[],[],'term'));
 for row={'442','电流环',50e-6,28.875e-6;'438','速度环',divider*50e-6,28.875e-6+(divider-1)*50e-6;'240','SVPWM',50e-6,28.875e-6}'
  actual=get_param(Simulink.ID.getHandle([m ':' row{1}]),'CompiledSampleTime');if iscell(actual),actual=vertcat(actual{:});end
  assert(all(abs(actual(:,1)-row{3})<1e-12)&&all(abs(actual(:,2)-row{4})<1e-12));
  rows{end+1}=struct('divider',divider,'task',row{2},'period_s',actual(1,1),'offset_s',actual(1,2));
 end
 clear finish
end
end
