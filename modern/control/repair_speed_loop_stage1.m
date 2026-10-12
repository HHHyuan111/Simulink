function repair_speed_loop_stage1
% Repair only speed-loop units and sampling in the existing flat model.
% Save the main SLX only after the structural and simulation checks pass.
folder=fileparts(mfilename('fullpath')); root=fileparts(folder);
mdl='PMSM_FOC_R2026a'; source=fullfile(root,[mdl '.slx']);
expected='a745187d8a8b40986515717c7ebc6594f488e745b7f73bd922bf1bdc39b46994';
assert(strcmp(filehash(source),expected),'Source differs from the published learning snapshot; refusing to overwrite.');
work=fullfile(root,'.build','speed_loop_stage1');if ~isfolder(work),mkdir(work);end
backup=fullfile(work,'before.slx');copyfile(source,backup);
load_system(source); cleanup=onCleanup(@()close_system(mdl,0));
set_param(mdl,'SimulationCommand','update');
before=snapshot(mdl); mw=get_param(mdl,'ModelWorkspace');
oldCode=mw.MATLABCode;oldValues=values(mw);
enableSpeedLogs(mdl);
cached=struct;
if isfile(fullfile(work,'before_sim.mat'))
 cached=load(fullfile(work,'before_sim.mat'));
 cached.before=stableSnapshot(cached.before);
 assert(isequaln(cached.before,before),'Baseline cache does not match this source.');
 baseline=cached.baseline;
 fprintf('SPEED_STAGE1_REUSE_VERIFIED_BASELINE\n');
else
 previous=fullfile(root,'validation_results.mat');
 if isfile(previous)
  cached=load(previous,'out','summary');
  assert(cached.summary.all_passed&&cached.summary.scenarios(1).stop_time_s==1);
  assert(abs(cached.summary.scenarios(1).speed_mean_last_20ms-3000.002971484209)<1e-8, ...
   'Previous default record is not the verified learning snapshot.');
  baseline=cached.out;
  fprintf('SPEED_STAGE1_REUSE_PUBLISHED_DEFAULT_RECORD\n');
 else
  fprintf('SPEED_STAGE1_BASELINE_DEFAULT\n');baseline=sim(mdl);
 end
 save(fullfile(work,'before_sim.mat'),'baseline','before','oldValues','-v7');
end
if isfield(cached,'baselineStep')
 baselineStep=cached.baselineStep;
else
 fprintf('SPEED_STAGE1_BASELINE_LOAD_STEP\n');
 baselineStep=loadStep(mdl);
 save(fullfile(work,'before_sim.mat'),'baseline','baselineStep','before','oldValues','-v7');
end

code=oldCode;
code=replaceOnce(code,'dt =Ts; %Sampling Period(s)', ...
    sprintf('dt =Ts; %% Current-control period [s]\nTs_speed=dt; %% Speed-control execution period [s]; firmware timing pending'));
code=replaceOnce(code,'wsc=2*pi*50; % BandWidth of Speed Loop', ...
    'wsc=2*pi*fwb; % Speed-loop design frequency [rad/s], independent of Ts_speed');
code=replaceOnce(code,'K=30/pi*1.5*phis*p;', ...
    sprintf('Kt=1.5*p*phis; %% Nominal torque constant [N*m/A]\nK=30/pi; %% Mechanical rad/s to rpm conversion'));
start=strfind(code,'kp_w=J*wsc/K;'); finish=strfind(code,'downlimit_w=-1.2*Tn;');
assert(isscalar(start)&&isscalar(finish)&&finish>start,'Unexpected speed gain section.');
replacement=sprintf([ ...
 '%% Speed error: rpm. PI output Te_ref: N*m.\n' ...
 'kp_w=J*wsc/K; %% [N*m/rpm], torque-input mechanical plant\n' ...
 'ki_w=kp_w*wsc/5; %% [N*m/(rpm*s)], original PI zero retained\n' ...
 '%% Convert the original A-output back-calculation coefficient to torque units.\n' ...
 '%% Kp and Ki scale by Kt; Ks scales by 1/Kt. Ki*Ks is unchanged.\n' ...
 'ks_w=1.5*kp_w/(Kt^2); %% [rpm/(N*m)]; no anti-windup retuning here\n' ...
 'Bm=0;\n' ...
 'uplimit_w=1.2*Tn; %% Torque demand limit [N*m], unchanged\n' ...
 'downlimit_w=-1.2*Tn;']);
code=[code(1:start-1) replacement code(finish+length('downlimit_w=-1.2*Tn;'):end)];
mw.MATLABCode=code;reload(mw);
set_param(sid(mdl,'155'),'SampleTime','Ts_speed');
set_param(sid(mdl,'438'),'SampleTime','SampleTime');
set_param(sid(mdl,'164'),'SampleTime','SampleTime');
set_param(sid(mdl,'190'),'SampleTime','Ts_speed');
% Te = 1.5*p*(phis+(Ld-Lq)*id)*iq, matching the existing motor equations.
set_param(sid(mdl,'216'),'Value','Ld-Lq');
set_param(mdl,'SimulationCommand','update');
after=snapshot(mdl); changed=checkScope(before,after);
newValues=values(mw);
assert(abs(newValues.kp_w/oldValues.kp_w-newValues.Kt)<1e-12);
assert(abs(newValues.ki_w/oldValues.ki_w-newValues.Kt)<1e-12);
assert(abs(newValues.ks_w/oldValues.ks_w-1/newValues.Kt)<1e-10);
assert(abs(newValues.ki_w*newValues.ks_w-oldValues.ki_w*oldValues.ks_w)<1e-12);

fprintf('SPEED_STAGE1_COMPONENT_CHECKS\n');
component=validate_speed_loop_stage1;
fprintf('SPEED_STAGE1_CLOSED_LOOP_CHECKS\n');
addpath(root);
cachePath=fullfile(work,'after_checks.mat');
if isfile(cachePath)
 checked=load(cachePath);
 checked.after=stableSnapshot(checked.after);
 assert(isequaln(checked.after,after)&&isequaln(checked.newValues,newValues),'Corrected check cache mismatch.');
 corrected=checked.corrected;correctedStep=checked.correctedStep;
 closedLoop=checked.closedLoop;fprintf('SPEED_STAGE1_REUSE_VERIFIED_CLOSED_LOOP_CHECKS\n');
else
 [closedLoop,outputs]=validate_pmsm_r2026a;
 corrected=outputs{1};correctedStep=outputs{4};
 save(cachePath,'corrected','correctedStep','closedLoop','after','newValues','-v7');
end
comparison=struct('before_default',metrics(baseline,3000), ...
 'after_default',metrics(corrected,3000), ...
 'before_load_step',metrics(baselineStep,3000), ...
 'after_load_step',metrics(correctedStep,3000));
makePlot(baseline,corrected,baselineStep,correctedStep,folder);
% Refresh stale informational text without moving annotations or blocks.
a=get_param(sid(mdl,'694'),'Object');
a.Name=sprintf('MATLAB R2026a  ·  24 V  ·  PWM 20 kHz\n速度环：转矩单位 / 显式采样周期');
% Discard only temporary test assignments; retain the edited MATLAB source.
reload(mw);assert(isequaln(values(mw),newValues));
beforeGraphics=before.graphics;finalState=snapshot(mdl);
assert(isequaln(beforeGraphics,finalState.graphics),'Block or region geometry changed.');
checkScope(before,finalState);
save_system(mdl,source);
print(['-s' mdl],'-dpng','-r120',fullfile(root,'layout','flat_tidy.png'));
report=struct('stage','speed_loop_units_and_sampling','matlab',version, ...
 'source_git_commit','4394283f8918b0e10636c6a68cc34e66a78981af', ...
 'before_sha256',expected,'after_sha256',filehash(source), ...
 'top_blocks',164,'total_blocks',numel(after.blocks),'graphics_unchanged',true, ...
 'connections_and_block_identity_unchanged',true,'changed_block_parameters',changed, ...
 'excluded_runtime_observation_metadata',{{'Record.SignalIDs'}}, ...
 'before_parameters',oldValues,'after_parameters',newValues, ...
 'component_checks',component,'comparison',comparison, ...
 'added_speed_logs',{{'speed_Te_ref','speed_P','speed_I'}}, ...
 'closed_loop_checks',closedLoop);
writejson(fullfile(folder,'speed_loop_stage1_results.json'),report);
save(fullfile(work,'after_sim.mat'),'corrected','correctedStep','report','-v7');
fprintf('SPEED_STAGE1_SAVED_AND_PASSED %s\n',report.after_sha256);
end

function h=sid(mdl,id)
h=Simulink.ID.getHandle([mdl ':' id]);
end
function code=replaceOnce(code,from,to)
assert(numel(strfind(code,from))==1,'Unexpected parameter source.');code=strrep(code,from,to);
end
function p=values(mw)
p=struct;names={'J','F','p','phis','Ld','Lq','Tn','dt','Ts','fwb','wsc','K','kp_w','ki_w','ks_w','uplimit_w','downlimit_w'};
for k=1:numel(names),p.(names{k})=getVariable(mw,names{k});end
for name={'Kt','Ts_speed'},try,p.(name{1})=getVariable(mw,name{1});catch,end,end
end
function enableSpeedLogs(mdl)
set_param(mdl,'SignalLogging','on');
ids={'155','164','438'};names={'speed_Te_ref','speed_P','speed_I'};
for k=1:numel(ids)
 ph=get_param(sid(mdl,ids{k}),'PortHandles');
 set_param(ph.Outport(1),'DataLogging','on','DataLoggingNameMode','Custom','DataLoggingName',names{k});
end
end
function out=loadStep(mdl)
in=Simulink.SimulationInput(mdl);in=setModelParameter(in,'StopTime','0.2');
path=getfullname(sid(mdl,'523'));
in=setBlockParameter(in,path,'Time','0.08');
in=setBlockParameter(in,path,'Before','0.3*Tn');
in=setBlockParameter(in,path,'After','0.6*Tn');
out=sim(in);
end
function s=snapshot(mdl)
paths=sort(find_system(mdl,'LookUnderMasks','all','FollowLinks','off','Type','Block'));
blocks=struct('path',{},'sid',{},'type',{},'params',{},'inputs',{},'mask',{});
graphics=struct('path',{},'position',{},'orientation',{});
for k=1:numel(paths)
 b=paths{k};typ=get_param(b,'BlockType');pp=get_param(b,'DialogParameters');params=struct;
 if ~isempty(pp)&&~strcmp(typ,'Scope')
  names=sort(fieldnames(pp));for j=1:numel(names),params.(names{j})=get_param(b,names{j});end
 end
 ph=get_param(b,'PortHandles');ins=cell(numel(ph.Inport),1);
 for j=1:numel(ins)
  ln=get_param(ph.Inport(j),'Line');ins{j}=[];
  if ln>=0,src=get_param(ln,'SrcPortHandle');if src>=0,ins{j}={get_param(src,'Parent'),get_param(src,'PortNumber')};end,end
 end
 mask=struct;for key={'MaskType','MaskDisplay','MaskInitialization'},mask.(key{1})=get_param(b,key{1});end
 blocks(end+1)=struct('path',b,'sid',Simulink.ID.getSID(b),'type',typ,'params',params,'inputs',{ins},'mask',mask); %#ok<AGROW>
 graphics(end+1)=struct('path',b,'position',get_param(b,'Position'),'orientation',get_param(b,'Orientation')); %#ok<AGROW>
end
annotations=find_system(mdl,'FindAll','on','SearchDepth',1,'Type','annotation');regions=struct('tag',{},'position',{},'color',{});
for k=1:numel(annotations)
 a=get_param(annotations(k),'Object');
 if strcmp(a.Tag,'FlatTidyRegion'),regions(end+1)=struct('tag',a.Name,'position',a.Position,'color',a.BackgroundColor);end %#ok<AGROW>
end
[~,ix]=sort({regions.tag});regions=regions(ix);
rt=sfroot;charts=rt.find('-isa','Stateflow.EMChart');scripts={};
for k=1:numel(charts),if startsWith(charts(k).Path,[mdl '/']),scripts(end+1,:)={charts(k).Path,charts(k).Script};end,end %#ok<AGROW>
config=struct;for key={'Solver','FixedStep','StopTime','SolverType'},config.(key{1})=get_param(mdl,key{1});end
s=struct('blocks',blocks,'graphics',struct('blocks',graphics,'regions',regions), ...
 'configuration',config,'scripts',{scripts});
s=stableSnapshot(s);
end
function s=stableSnapshot(s)
% The R2026a XY Graph generates new observation IDs on every simulation.
% Its connected ports, decimation and all actual control parameters are checked.
for k=1:numel(s.blocks)
 if strcmp(s.blocks(k).type,'Record')&&isfield(s.blocks(k).params,'SignalIDs')
  s.blocks(k).params=rmfield(s.blocks(k).params,'SignalIDs');
 end
end
end
function changed=checkScope(a,b)
assert(numel(a.blocks)==329&&numel(b.blocks)==329);
assert(isequaln(a.graphics,b.graphics)&&isequaln(a.configuration,b.configuration)&&isequaln(a.scripts,b.scripts));
allow={'155','SampleTime';'438','SampleTime';'164','SampleTime';'190','SampleTime';'216','Value'};
changed=struct('sid',{},'parameter',{},'before',{},'after',{});
for k=1:numel(a.blocks)
 old=a.blocks(k);new=b.blocks(k);
 assert(isequaln(rmfield(old,'params'),rmfield(new,'params')),'Block identity, wiring or mask changed.');
 names=fieldnames(old.params);assert(isequal(names,fieldnames(new.params)));
 for j=1:numel(names)
  name=names{j};if isequaln(old.params.(name),new.params.(name)),continue;end
  short=extractAfter(old.sid,':');assert(any(strcmp(allow(:,1),short)&strcmp(allow(:,2),name)), ...
   'Unexpected block parameter change: %s / %s: %s -> %s',old.sid,name,jsonencode(old.params.(name)),jsonencode(new.params.(name)));
  changed(end+1)=struct('sid',char(short),'parameter',name,'before',old.params.(name),'after',new.params.(name)); %#ok<AGROW>
 end
end
assert(numel(changed)==size(allow,1),'Expected five scoped parameter changes.');
end
function r=metrics(out,target)
w=double(out.log_speed.Data);t=out.log_speed.Time;tail=t>=t(end)-0.02;
band=max(1,0.02*abs(target));outside=find(abs(w-target)>band);settling=0;
if ~isempty(outside),if outside(end)==numel(t),settling=NaN;else,settling=t(outside(end)+1);end,end
r=struct('steady_speed_rpm',mean(w(tail)),'maximum_speed_rpm',max(w), ...
 'settling_time_2percent_s',settling,'peak_iq_A',max(abs(double(out.log_iq.Data(:)))), ...
 'maximum_iq_ref_A',max(abs(double(out.log_iq_ref.Data(:)))), ...
 'steady_torque_Nm',mean(double(out.log_Te.Data(tail))));
if t(end)<0.3,r.maximum_speed_error_after_load_step_rpm=max(abs(w(t>=0.08)-target));end
end
function makePlot(a,b,c,d,folder)
f=figure('Visible','off','Position',[50 50 1250 850],'Color','white');tiledlayout(2,2,'TileSpacing','compact');
nexttile;plot(a.log_speed.Time,a.log_speed.Data,b.log_speed.Time,b.log_speed.Data);xlim([0 0.2]);grid on;
xlabel('Time (s)');ylabel('Speed (rpm)');title('Start-up');legend('Published snapshot','Torque-unit correction');
nexttile;plot(a.log_iq_ref.Time,a.log_iq_ref.Data,b.log_iq_ref.Time,b.log_iq_ref.Data);xlim([0 0.2]);grid on;
xlabel('Time (s)');ylabel('iq reference (A)');title('Current demand');
nexttile;plot(c.log_speed.Time,c.log_speed.Data,d.log_speed.Time,d.log_speed.Data);xline(0.08,'--');grid on;
window=[double(c.log_speed.Data(c.log_speed.Time>=0.06));double(d.log_speed.Data(d.log_speed.Time>=0.06))];
xlim([0.06 0.2]);ylim([min(window)-10 max(window)+10]);
xlabel('Time (s)');ylabel('Speed (rpm)');title('Load step: 0.3 Tn to 0.6 Tn');
nexttile;ts=b.logsout.getElement('speed_I').Values;plot(ts.Time,ts.Data);hold on;
ts=b.logsout.getElement('speed_P').Values;plot(ts.Time,ts.Data);xlim([0 0.2]);grid on;
xlabel('Time (s)');ylabel('Torque contribution (N m)');legend('Integral','Proportional');title('Corrected speed PI');
sgtitle('Speed loop stage 1: units and sample-time binding');
exportgraphics(f,fullfile(folder,'speed_loop_stage1_comparison.png'),'Resolution',150);close(f);
end
function writejson(path,data)
fid=fopen(path,'w','n','UTF-8');fprintf(fid,'%s',jsonencode(data,PrettyPrint=true));fclose(fid);
end
function result=filehash(path)
fid=fopen(path,'rb');data=fread(fid,Inf,'*uint8');fclose(fid);
md=java.security.MessageDigest.getInstance('SHA-256');md.update(data);
result=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
end
