function report=probe_sensorless_r2_core_replay(folder)
% Archived-input isolation only: no model load, compile or plant execution.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);
addpath(base,fullfile(base,'robust/integration'),fullfile(base,'robust/phase_guard'),fullfile(modern,'teaching'));
assert(~isfolder(folder));mkdir(folder);report=struct('kind','offline_core_isolation','all_passed',false,'phase','source_check',...
 'plant_reexecuted',false,'whole_model_fault_acceptance',false,'matlab_version',version,'process_id',feature('getpid'));
contract=fullfile(base,'contracts/nonideal_r2_core_replay_diagnostic.json');plan=jsondecode(fileread(contract));
copyfile(contract,fullfile(folder,'contract.json'));report.contract_sha256=teach_hash(contract);
reference=fullfile(base,plan.reference_folder);record=jsondecode(fileread(fullfile(reference,'record.json')));
raw=fullfile(reference,'signals.mat');assert(strcmp(record.raw_sha256,plan.reference_raw_sha256)&&strcmp(teach_hash(raw),record.raw_sha256));
report.reference_raw_sha256=record.raw_sha256;report.reference_record_sha256=teach_hash(fullfile(reference,'record.json'));
files={'sensorless_smo_step.m','sensorless_emf_step.m','sensorless_pll_step.m','sensorless_validity_step.m',...
 'sensorless_state.m','sensorless_rt_config.m','robust/integration/sensorless_v2_front_phase.m',...
 'robust/integration/sensorless_v2_config_rt.m','robust/phase_guard/sensorless_r2_phase_guard.m'};
report.sources=struct('path',{},'sha256',{});
for k=1:numel(files)
 relative=files{k};index=find(strcmp({record.source_files.path},relative));assert(isscalar(index));
 source=fullfile(base,relative);assert(strcmp(teach_hash(source),record.source_files(index).sha256));
 [~,name]=fileparts(source);assert(strcmpi(which(name),source),'Unexpected path resolution: %s',name);
 destination=fullfile(folder,'source',relative);if ~isfolder(fileparts(destination)),mkdir(fileparts(destination));end
 copyfile(source,destination);report.sources(end+1)=struct('path',relative,'sha256',teach_hash(source));
end
copyfile([mfilename('fullpath') '.m'],fullfile(folder,'probe_source.m.txt'));report.probe_sha256=teach_hash([mfilename('fullpath') '.m']);
startup=which('startup','-all');environment=struct('matlab_version',version,'architecture',computer('arch'),...
 'startup_locations',{startup},'path',path,'userpath',userpath,'matlabpath_present',~isempty(getenv('MATLABPATH')));
teach_writejson(fullfile(folder,'private_environment.json'),environment);
report.private_environment_sha256=teach_hash(fullfile(folder,'private_environment.json'));
report.startup_script_found=~isempty(startup);report.source_resolution_checked=true;
teach_writejson(fullfile(folder,'report.json'),report);
try
 fields={'i_hat','i_residual','injection','emf','emf_magnitude','theta_raw','phase_correction','front_phase',...
  'theta','omega_e','speed','pll_error','pll_integral','pll_saturated','valid','state','history'};
 inputNames={'input_i','input_v','sample_valid','reset','truth_theta','truth_speed'};
 names=[strcat('obs_sless_v2_',fields) strcat('obs_sless_v2_',inputNames) {'obs_sless_r2_phase_guard'}];
 report.phase='read_archived_streams';teach_writejson(fullfile(folder,'report.json'),report);s=load(raw,names{:});
 t=s.obs_sless_v2_theta.Time;assert(numel(t)==16000);input=struct;expected=struct;
 for k=1:numel(inputNames),value=s.(['obs_sless_v2_' inputNames{k}]);assert(isequaln(t,value.Time));input.(inputNames{k})=teach_values(value);end
 for k=1:numel(fields),value=s.(['obs_sless_v2_' fields{k}]);assert(isequaln(t,value.Time));expected.(fields{k})=teach_values(value);end
 assert(isequaln(t,s.obs_sless_r2_phase_guard.Time));expected.phase_guard=teach_values(s.obs_sless_r2_phase_guard);clear s;
 c=sensorless_rt_config(record.observer_config);front=sensorless_v2_config_rt(record.config_vector);
 report.phase='replay_baseline';teach_writejson(fullfile(folder,'report.json'),report);started=tic;
 baseline=replay(input,c,front);report.elapsed_s=toc(started);report.samples=numel(t);
 report.comparisons=struct('field',{},'exact',{},'max_abs',{},'first_differing_sample',{});fields=fieldnames(expected);
 for k=1:numel(fields)
  name=fields{k};a=baseline.(name);b=expected.(name);assert(isequal(size(a),size(b)));
  first=find(any(a~=b,2),1);if isempty(first),first=0;end
  report.comparisons(end+1)=struct('field',name,'exact',isequaln(a,b),'max_abs',max(abs(a-b),[],'all'),'first_differing_sample',first);
 end
 report.baseline_exact=all([report.comparisons.exact]);report.numeric_elements=sum(structfun(@numel,expected));
 save(fullfile(folder,'baseline.mat'),'baseline','expected','input','t','-v7.3');
 if report.baseline_exact
  report.phase='core_fault_diagnostics';teach_writejson(fullfile(folder,'report.json'),report);
  parent=jsondecode(fileread(fullfile(base,'contracts/nonideal_r2_test_plan.json')));cases=parent.cases;if ~iscell(cases),cases=num2cell(cases);end
  for id={'missing_five','reset_one'}
   test=cases{find(cellfun(@(x)strcmp(x.id,id{1}),cases))};mutated=input;
   if strcmp(id{1},'missing_five')
    onset=test.missing_reference_interval_s(1);healthy=test.missing_reference_interval_s(2);
    affected=t>=onset-1e-12&t<healthy-1e-12;assert(sum(affected)==5);mutated.sample_valid(affected)=0;
   else
    onset=test.reset_reference_s;healthy=onset+c.sample_s;affected=abs(t-onset)<1e-12;assert(sum(affected)==1);mutated.reset(affected)=1;
   end
   result=replay(mutated,c,front);packet=result.phase_guard(:,8)>0;eligible=find(t>=healthy-1e-12&packet,1);
   recovery=NaN;if ~isempty(eligible),recovery=t(eligible);end
   diagnostic=struct('id',id{1},'component_only',true,'affected_samples',sum(affected),...
    'fault_reference_s',onset,'healthy_reference_s',healthy,'first_requalified_reference_s',recovery,...
    'no_packet_qualification_during_fault',~any(packet(affected)),...
    'qualification_not_before_599_opportunities',isnan(recovery)||recovery>=healthy+598*c.sample_s-1e-12,...
    'requalified_by_150ms',isfinite(recovery)&&recovery-healthy<=.15);
   if strcmp(id{1},'reset_one')
    diagnostic.reset_states_zero=all(result.i_hat(affected,:)==0,'all')&&all(result.injection(affected,:)==0,'all')&&...
     all(result.emf(affected,:)==0,'all')&&all(result.theta(affected)==0)&&all(result.omega_e(affected)==0)&&all(result.history(affected,:)==0,'all');
   else,diagnostic.no_measurement_correction=all(result.i_residual(affected,:)==0,'all');end
   report.core_faults.(id{1})=diagnostic;save(fullfile(folder,[id{1} '_core.mat']),'result','mutated','t','diagnostic','-v7.3');
  end
 end
 for k=1:numel(report.sources),assert(strcmp(teach_hash(fullfile(base,report.sources(k).path)),report.sources(k).sha256));end
 report.phase='completed';report.all_passed=report.baseline_exact;report.R2_case_status_changed=false;
 teach_writejson(fullfile(folder,'report.json'),report);fprintf('CORE_REPLAY_COMPLETE exact=%d samples=%d\n',report.baseline_exact,numel(t));
catch err
 report.phase_at_error=report.phase;report.phase='analysis_error';report.error=getReport(err,'extended','hyperlinks','off');teach_writejson(fullfile(folder,'report.json'),report);rethrow(err);
end
end
function output=replay(input,c,front)
n=size(input.input_i,1);fields={'i_hat',2;'i_residual',2;'injection',2;'emf',2;'emf_magnitude',1;'theta_raw',1;...
 'phase_correction',1;'front_phase',1;'theta',1;'omega_e',1;'speed',1;'pll_error',1;'pll_integral',1;...
 'pll_saturated',1;'valid',1;'state',1;'history',3;'phase_guard',8};output=struct;
for k=1:size(fields,1),output.(fields{k,1})=zeros(n,fields{k,2});end
state=sensorless_state(c);omegaPrevious=0;direction=1;
for k=1:n
 valid=input.sample_valid(k)>0;reset=input.reset(k)>0;
 [state.smo,d]=sensorless_smo_step(state.smo,input.input_i(k,:)',input.input_v(k,:)',c,valid,reset);
 omega=omegaPrevious;if reset,omega=0;end
 [state.emf,emf]=sensorless_emf_step(state.emf,state.smo.z,omega,direction,c,valid,reset);
 [phase,~]=sensorless_v2_front_phase(omega,front);rotation=[cos(phase) -sin(phase);sin(phase) cos(phase)];vector=rotation*emf.vector;
 enabled=valid&&emf.magnitude>=c.validity.emf_off_below_V;
 [state.pll,pll]=sensorless_pll_step(state.pll,vector,c,enabled,reset);
 [state,quality,status]=sensorless_validity_step(state,d.residual,pll.error,emf.magnitude,pll.saturated,valid,direction,reset,c);
 [~,guard]=sensorless_r2_phase_guard(pll.theta,vector,quality,valid,reset,c.validity.emf_off_below_V);
 output.i_hat(k,:)=state.smo.i';output.i_residual(k,:)=d.residual';output.injection(k,:)=state.smo.z';output.emf(k,:)=state.emf';
 output.emf_magnitude(k)=emf.magnitude;output.theta_raw(k)=emf.raw_theta;output.phase_correction(k)=emf.phase_correction;output.front_phase(k)=phase;
 output.theta(k)=pll.theta;output.omega_e(k)=pll.omega;output.speed(k)=pll.omega/c.pole_pairs*60/(2*pi);
 output.pll_error(k)=pll.error;output.pll_integral(k)=pll.integral;output.pll_saturated(k)=double(pll.saturated);output.valid(k)=double(quality);output.state(k)=status;
 output.history(k,:)=[state.lock_count state.history_count state.unlock_count];output.phase_guard(k,:)=guard';omegaPrevious=pll.omega;
end
end
