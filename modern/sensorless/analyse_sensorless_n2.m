function report=analyse_sensorless_n2(folder)
% Independent source/time checks on archived data; no simulation or plotting.
here=fileparts(mfilename('fullpath'));addpath(fullfile(fileparts(here),'teaching'));
plan=jsondecode(fileread(fullfile(here,'milestones','N2_test_plan.json')));
record=jsondecode(fileread(fullfile(folder,'record.json')));cases=cell(numel(record.cases),1);
for k=1:numel(cases)
 r=record.cases(k);assert(strcmp(r.sha256,teach_hash(fullfile(folder,r.file))));
 loaded=load(fullfile(folder,r.file),'signals');cases{k}=loaded.signals;
end
schema=jsondecode(fileread(fullfile(here,'baseline','log_schema.json')));oldNames={schema.name};
regressions=struct('pair',{},'logs',{},'passed',{},'failures',{});
pairs=[1 2;1 3;4 5];
for k=1:size(pairs,1)
 pair=pairs(k,:);[passed,failed]=compare_old(cases{pair(1)},cases{pair(2)},oldNames);
 regressions(k)=struct('pair',[record.cases(pair(1)).id ' / ' record.cases(pair(2)).id],...
  'logs',numel(oldNames),'passed',passed,'failures',{failed});
end
n0=load(fullfile(here,'runs','N0_baseline','signals.mat'),'signals');
[n0match,n0fail]=compare_old(n0.signals,cases{1},oldNames);
report=struct('schema',1,'node','N2','old_log_regressions',regressions,...
 'n0_baseline_identical',n0match,'n0_failures',{n0fail},'integration',struct([]));
for index=[2 3 5]
 s=cases{index};testcase=plan.cases(index);real=strcmp(testcase.timing,'real');
 h=plan.compiled_rates.reference_native_grid_s;offset=0;
 if real,h=plan.compiled_rates.real_native_grid_s;offset=plan.compiled_rates.real_offset_s;end
 native=teach_values(s.obs_sless_voltage_native);nativeTime=s.obs_sless_voltage_native.Time;
 ticks=round(nativeTime/h);N=round(50e-6/h);
 grid_ok=all(diff(ticks)==1)&&max(abs(native(:,1)-nativeTime))<=1e-12;
 upper=double(native(:,7)>=native(:,4:6));bus=native(:,8);
 expectedU=[bus.*(2*upper(:,1)-upper(:,2)-upper(:,3))/3,bus.*(upper(:,2)-upper(:,3))/sqrt(3)];
 reconstruction_error=max(abs(expectedU-native(:,2:3)),[],'all');
 reconstruction_ok=within(native(:,2:3),expectedU,plan);
 sequence_ok=all(native(:,9)==-1);threshold_ok=true;latched_changes=0;request_diff=0;
 if real
  pwm=teach_values(s.obs_pwm_timing);assert(isequaln(s.obs_pwm_timing.Time,nativeTime));
  sequence_ok=isequaln(native(:,9),pwm(:,7));active=ones(1,3)*50e-6/4;expected=zeros(size(native,1),3);
  for k=1:size(native,1)
   if pwm(k,5)>.5,assert(k>1);active=pwm(k-1,10:12);latched_changes=latched_changes+1;end
   expected(k,:)=active;
  end
  threshold_ok=isequaln(native(:,4:6),expected);
  request_diff=max(abs(teach_values(s.log_Tcm_requested)-teach_values(s.log_Tcm_applied)),[],'all');
  threshold_ok=threshold_ok&&latched_changes>0&&request_diff>0;
 end
 % Compare reconstructed values with independently logged original bridge.
 phase=teach_values(s.obs_phase_ideal);phaseTicks=round(s.obs_phase_ideal.Time/h);
 [found,where]=ismember(phaseTicks,ticks);assert(all(found));
 C=[2/3 -1/3 -1/3;0 1/sqrt(3) -1/sqrt(3)];actualU=phase*C';
 bridge_error=max(abs(actualU-native(where,2:3)),[],'all');bridge_ok=within(native(where,2:3),actualU,plan);
 current=teach_values(s.obs_sless_input_i);measured=teach_values(s.log_iabc_meas);
 current_time_ok=isequaln(s.obs_sless_input_i.Time,s.log_iabc_meas.Time);
 current_error=max(abs(current-measured*C'),[],'all');current_ok=current_time_ok&&within(current,measured*C',plan);
 inputV=teach_values(s.obs_sless_input_v);interval=teach_values(s.obs_sless_voltage_interval);
 time=s.obs_sless_input_v.Time;parameters=sensorless_parameters;lambda=parameters.R_hat/parameters.L_hat;rho=exp(-lambda*h);
 complete=find(interval(:,2)>interval(:,1));weighted_errors=zeros(numel(complete),1);interval_ok=true;
 for j=1:numel(complete)
  k=complete(j);begin=round(interval(k,1)/h);last=round(interval(k,2)/h);
  interval_ok=interval_ok&&last-begin==N&&abs(interval(k,2)-time(k))<=1e-12;
  segmentTicks=(begin:last-1)';[exists,rows]=ismember(segmentTicks,ticks);assert(all(exists));
  % Direct analytic exponential weights; not the DUT's recursive accumulator.
  weights=exp(-lambda*h*(last-segmentTicks-1))*(1-rho)/(1-exp(-lambda*50e-6));
  expectedV=weights'*native(rows,2:3);
  weighted_errors(j)=max(abs(inputV(k,:)-expectedV));
  interval_ok=interval_ok&&within(inputV(k,:),expectedV,plan);
 end
 assert(numel(complete)>=40,'首末20个完整周期不足。');
 [modules,maximum]=compare_modules(s,offset,strcmp(testcase.observer,'disabled'),plan);
 rates=jsondecode(fileread(fullfile(folder,[testcase.id '_rates.json'])));rates_ok=true;
 for k=1:numel(rates)
  expectedRate=[50e-6 offset];if contains(rates(k).path,'分段累计'),expectedRate=[h 0];end
  rates_ok=rates_ok&&isequaln(rates(k).sample_time(:)',expectedRate);
 end
 sample_time=s.obs_sless_input_i.Time;
 activeSamples=sample_time>=offset-h/4;
 task_ticks=round((sample_time(activeSamples)-offset)/h);
 task_grid_ok=all(mod(task_ticks,N)==0);
 row=struct('case_id',testcase.id,'native_grid',grid_ok,'native_samples',size(native,1),...
  'reconstruction_passed',reconstruction_ok,'reconstruction_max_error_V',reconstruction_error,...
  'CCR_sequence_identical',sequence_ok,'applied_thresholds_identical',threshold_ok,'latches',latched_changes,...
  'requested_applied_threshold_max_difference_s',request_diff,'bridge_voltage_passed',bridge_ok,...
  'bridge_voltage_max_error_V',bridge_error,'sample_current_passed',current_ok,'sample_current_max_error_A',current_error,...
  'weighted_intervals_passed',interval_ok,'complete_intervals',numel(complete),'weighted_max_error_V',max(weighted_errors),...
  'first20_interval_indices',complete(1:20)','last20_interval_indices',complete(end-19:end)',...
  'N1_composition_passed',modules,'N1_composition_max_abs_error',maximum,'compiled_rates_passed',rates_ok,...
  'task_grid_passed',task_grid_ok,'passed',grid_ok&&reconstruction_ok&&sequence_ok&&threshold_ok&&bridge_ok&&current_ok&&interval_ok&&modules&&rates_ok&&task_grid_ok);
 if isempty(report.integration),report.integration=row;else,report.integration(end+1)=row;end
 fprintf('N2_ANALYSIS %s passed=%d old_clock=%g offset=%g\n',testcase.id,row.passed,h,offset);
end
report.all_passed=all([regressions.passed])&&n0match&&all([report.integration.passed])&&all([record.cases.restored]);
end

function [passed,failures]=compare_old(a,b,names)
failures={};
for k=1:numel(names)
 name=names{k};if ~isfield(a,name)||~isfield(b,name)||~isequaln(a.(name).Time,b.(name).Time)||~isequaln(a.(name).Data,b.(name).Data),failures{end+1}=name;end %#ok<AGROW>
end
passed=isempty(failures);
end

function ok=within(actual,expected,plan)
tol=plan.voltage_reconstruction.absolute_tolerance_V+plan.voltage_reconstruction.relative_tolerance*abs(expected);
ok=isequal(size(actual),size(expected))&&all(abs(actual-expected)<=tol,'all');
end

function [passed,maximum]=compare_modules(s,offset,disabled,plan)
c=sensorless_parameters;state=sensorless_state(c);time=s.obs_sless_input_i.Time;
current=teach_values(s.obs_sless_input_i);voltage=teach_values(s.obs_sless_input_v);
valid=teach_values(s.obs_sless_sample_valid);reset=teach_values(s.obs_sless_reset);
names={'i_hat','i_residual','injection','emf','theta_raw','phase_correction','theta','omega_e','speed',...
 'pll_error','pll_integral','pll_saturated','emf_magnitude','valid','state'};
fields={'i_hat','residual','injection','emf','theta_raw','phase_correction','theta','omega_e','speed_rpm',...
 'pll_error','pll_integral','pll_saturated','emf_magnitude','valid','state'};
actual=cell(size(names));for j=1:numel(names),actual{j}=teach_values(s.(['obs_sless_' names{j}]));end
maximum=0;passed=true;
for k=1:numel(time)
 if time(k)<offset-1e-12,continue;end
 [state,o]=sensorless_observer_step(state,current(k,:)',voltage(k,:)',1,logical(valid(k)),logical(reset(k)),c);
 if disabled,passed=passed&&reset(k);end
 for j=1:numel(names)
  expected=reshape(double(o.(fields{j})),1,[]);values=actual{j}(k,:);
  maximum=max(maximum,max(abs(values-expected)));passed=passed&&within(values,expected,plan);
 end
end
end
