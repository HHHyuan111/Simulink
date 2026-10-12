function apply_chensha_profile
% One-time parameter migration, validate staged SLX before replacing canonical.
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);addpath(fullfile(root,'teaching'));
mdl='PMSM_FOC_R2026a';canonical=fullfile(root,[mdl '.slx']);
expected='0524c3504492918af3bc346e1ea1055189b6195e88a8b179b84a30d1689520df';
assert(~bdIsLoaded(mdl),'Run in a fresh MATLAB batch session.');
assert(strcmp(teach_hash(canonical),expected),'Source changed; inspect before applying.');
work=fullfile(root,'.build','motor_profile_stage');if ~isfolder(work),mkdir(work);end
backup=fullfile(work,'PMSM_FOC_before_chensha.slx');
if isfile(backup),assert(strcmp(teach_hash(backup),expected),'Existing backup is from another source.');else,copyfile(canonical,backup);end
candidate=fullfile(work,[mdl '.slx']);copyfile(canonical,candidate);
load_system(candidate);guard=onCleanup(@()close_system(mdl,0));
before=teach_snapshot(mdl);mw=get_param(mdl,'ModelWorkspace');oldcode=mw.MATLABCode;oldsettings=teach_settings(mdl);
piNames={'kp_w','ki_w','ks_w','kp_id','ki_id','ks_id','kp_iq','ki_iq','ks_iq'};
oldpi=struct;gaincode='';for k=1:numel(piNames)
 name=piNames{k};oldpi.(name)=getVariable(mw,name);
 gaincode=[gaincode sprintf('%s=%.17g;\n',name,oldpi.(name))]; %#ok<AGROW>
end
fprintf('CHENSHA_BEFORE_1S\n');old=sim(mdl);baseline=metrics(old);
code=fileread(fullfile(folder,'chensha_model_parameters.m'));
assert(contains(code,'%__FROZEN_PI_GAINS__'));code=strrep(code,'%__FROZEN_PI_GAINS__',strtrim(gaincode));
mw.MATLABCode=code;reload(mw);
for k=1:numel(piNames),assert(isequal(getVariable(mw,piNames{k}),oldpi.(piNames{k})));end
% Values only; all realism switches remain off. No new dynamics or topology.
set_param([mdl '/采样设置'],'adc_span','82.5','adc_bits','12');
set_param([mdl '/角度设置'],'step_deg','0.18'); % 360*5/10000 electric degrees/count
set_param(mdl,'Description',['CHENSHA 200W nominal motor profile from AxDr_L dev ' ...
 '48d6e86814ac6657b1313b4c92ef24c88f492e07. PI gains frozen from previous model. ' ...
 'Current/PWM 20kHz, speed 10kHz. Bench iq command limit 8A. ' ...
 'ABZ estimator, active protection and hardware sampling windows are not implemented.']);
annotations=find_system(mdl,'FindAll','on','SearchDepth',1,'Type','annotation');
for h=annotations(:)'
 a=get_param(h,'Object');
 if isequal(a.Position,[1000 1260 1750 1285]),a.Name='沉沙 200W · 5极对 · 固件标称参数';end
 if isequal(a.Position,[1920 15 2700 80]),a.Name=sprintf('MATLAB R2026a · 24 V · PWM 20 kHz\n沉沙 200W · 速度环 10 kHz');end
end
set_param(mdl,'SimulationCommand','update');
after=teach_snapshot(mdl);allowed=before;
for k=1:numel(allowed.blocks)
 b=allowed.blocks(k);key='';value='';
 if strcmp(b.path,[mdl '/采样设置']),key='adc_span';value='82.5';end
 if strcmp(b.path,[mdl '/角度设置']),key='step_deg';value='0.18';end
 if ~isempty(key)
  allowed.blocks(k).params.(key)=value;
  index=find(strcmp(b.mask.MaskNames,key));assert(isscalar(index));
  allowed.blocks(k).mask.MaskValues{index}=value;
 end
end
assert(isequaln(allowed,after),'Unexpected block, parameter, position or region change.');
newsettings=teach_settings(mdl);expectedsettings=oldsettings;
for j=1:numel(expectedsettings),for q=1:numel(expectedsettings(j).parameters)
 s=expectedsettings(j);name=s.parameters(q).name;
 if strcmp(s.block,'采样设置')&&strcmp(name,'adc_span'),expectedsettings(j).parameters(q).value='82.5';end
 if strcmp(s.block,'角度设置')&&strcmp(name,'step_deg'),expectedsettings(j).parameters(q).value='0.18';end
end,end
% Snapshot includes mask values, so compare with these explicitly allowed edits.
assert(isequaln(newsettings,expectedsettings));
fprintf('CHENSHA_AFTER_1S\n');out=sim(mdl);result=metrics(out);
assert(result.finite&&result.thresholds_valid&&result.final_speed_error_rpm<20);
assert(result.peak_iq_demand_A<=8+1e-10);
assert(all(abs(teach_values(out.log_TL)-0.3*0.69)<1e-12));
assert(result.voltage_ratio_max<1,'Default test entered known overmodulation region.');
assert(isempty(find_system(mdl,'LookUnderMasks','all','FollowLinks','off','LinkStatus','unresolved')));
% Verify compiled task rates rather than inferring them from log spacing.
feval(mdl,[],[],[],'compile');rates=cell(1,3);
try
 ids={'190','164','438'};for k=1:3
  rate=get_param(Simulink.ID.getHandle([mdl ':' ids{k}]),'CompiledSampleTime');
  if iscell(rate),rate=vertcat(rate{:});end
  rates{k}=rate;discrete=unique(rate(isfinite(rate(:,1))&rate(:,1)>0,1));
  assert(isscalar(discrete)&&abs(discrete-100e-6)<1e-12,'Speed task did not compile at 10kHz.');
 end
catch err,feval(mdl,[],[],[],'term');rethrow(err);end
feval(mdl,[],[],[],'term');
% Keep the embedded parameter source alongside the SLX for review.
fid=fopen(fullfile(work,'old_parameters.m'),'w','n','UTF-8');fprintf(fid,'%s',oldcode);fclose(fid);
fid=fopen(fullfile(folder,'chensha_model_parameters.m'),'w','n','UTF-8');fprintf(fid,'%s',code);fclose(fid);
save_system(mdl,candidate);candidatehash=teach_hash(candidate);
clear guard; % Close before replacing the canonical disk file.
load_system(candidate);freshguard=onCleanup(@()close_system(mdl,0));
fprintf('CHENSHA_RELOAD_1S\n');fresh=sim(mdl);freshmetrics=metrics(fresh);
for name={'log_speed','log_Te','log_id','log_iq','log_TL','log_iq_ref','log_Tcm_applied'}
 a=out.get(name{1});b=fresh.get(name{1});assert(isequaln(a.Time,b.Time)&&isequaln(a.Data,b.Data),'Saved/reloaded result changed.');
end
assert(strcmp(teach_hash(canonical),expected),'Canonical changed while validation ran.');
record=struct('source_sha256',expected,'model_sha256',candidatehash,'firmware_commit',getVariable(get_param(mdl,'ModelWorkspace'),'MotorSourceCommit'), ...
 'before',baseline,'after',result,'reloaded',freshmetrics,'pi_gains',oldpi,'pi_gains_unchanged',true, ...
 'all_blocks_and_positions_unchanged',true,'all_switches_off',true,'speed_task_periods',{rates}, ...
 'loaded_parameters',parameterValues(get_param(mdl,'ModelWorkspace')),'all_passed',true);
reportdir=fullfile(folder,'report_chensha');if ~isfolder(reportdir),mkdir(reportdir);end
plot_observation_report(fresh,'沉沙 200W · 标称参数 · 原 PI',reportdir);
save(fullfile(work,'runs.mat'),'old','out','fresh','record','before','after','-v7.3');
clear freshguard;
copyfile(candidate,canonical);assert(strcmp(teach_hash(canonical),candidatehash));
teach_writejson(fullfile(folder,'chensha_validation.json'),record);
fprintf('CHENSHA_MIGRATION_PASS %s\n',candidatehash);
end

function v=parameterValues(mw)
v=struct;for x=whos(mw)',value=getVariable(mw,x.name);if isnumeric(value)||ischar(value),v.(x.name)=value;end,end
end
function m=metrics(o)
t=o.log_speed.Time;speed=teach_values(o.log_speed);ref=teach_values(o.log_nref);iq=teach_values(o.log_iq);demand=teach_values(o.log_iq_ref);
thresholds=teach_values(o.log_Tcm_applied);vd=teach_values(o.obs_vd);vq=teach_values(o.obs_vq);
finite=true;names=o.who;for k=1:numel(names),x=o.get(names{k});if isa(x,'timeseries'),finite=finite&&all(isfinite(x.Data(:)));end,end
m=struct('finite',finite,'stop_time_s',t(end),'final_speed_rpm',speed(end),'final_speed_error_rpm',abs(ref(end)-speed(end)), ...
 'peak_iq_A',max(abs(iq)),'peak_iq_demand_A',max(abs(demand)),'peak_speed_rpm',max(speed), ...
 'thresholds_valid',all(thresholds(:)>=-1e-12&thresholds(:)<=25e-6+1e-12), ...
 'voltage_ratio_max',max(hypot(vd,vq)/(24/sqrt(3))));
end
