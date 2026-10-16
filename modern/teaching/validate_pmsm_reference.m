function record=validate_pmsm_reference
% Run in a separate MATLAB process; never close an already-open user model.
here=fileparts(mfilename('fullpath'));root=fileparts(here);mdl='PMSM_FOC_R2026a';
assert(~bdIsLoaded(mdl),'请在独立MATLAB进程运行本检查，避免干扰已打开的模型。');
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));work=fullfile(root,'.build',['reference_check_' stamp]);mkdir(work);
source=fullfile(root,[mdl '.slx']);candidate=fullfile(work,[mdl '.slx']);copyfile(source,candidate);
oldFolder=pwd;folderGuard=onCleanup(@()cd(oldFolder));addpath(here,fullfile(root,'control'),fullfile(root,'timing'),fullfile(root,'deadtime'));cd(work);
sourceHash=teach_hash(source);load_system(candidate);guard=onCleanup(@()close_system(mdl,0));
ref=fullfile(work,'reference');manifest=pmsm_reference('freeze',ref,mdl);baseline=pmsm_reference('read',ref,mdl);
geometry=teach_snapshot(mdl);record=struct('all_passed',false,'model_sha256',sourceHash,'work_folder',work, ...
 'matlab_version',version,'reference_manifest_sha256',teach_hash(fullfile(ref,'manifest.json')));
catalog=pmsm_switch_catalog;cfg=baseline.configuration;
assert(numel(catalog)==19&&numel(cfg.rows)==62);
switchRows=cfg.rows(strcmp({cfg.rows.kind},'switch'));
assert(isequal(sort(strcat({catalog.section},'.',{catalog.key})),sort(strcat({switchRows.section},'.',{switchRows.key}))));
for k=1:numel(catalog)
 for name=catalog(k).parameters,assert(any(strcmp({cfg.rows.section},catalog(k).section)&strcmp({cfg.rows.key},name{1})),'开关参数说明引用不存在。');end
 c=cfg;c=enable(c,catalog(k).section,catalog(k).key,catalog);pmsm_check_switches(c);
end
record.catalog_coverage=19;
fprintf('REFERENCE_DEFAULT_1S\n');o=sim(mdl);referenceSignals=signatures(o);record.default_metrics=metrics(o);clear o;
assert(numel(referenceSignals)==52,'预期52路时间序列。');
record.reference_signals=referenceSignals;
% Reject dependency violations without changing any loaded state.
invalids={{'功率设置','comp_on','on'};{'时序设置','window_on','on'};{'时序设置','invalid_hold_on','on'}; ...
 {'时序设置','real_on','on';'时序设置','pwm_on','on'}; ...
 {'时序设置','real_on','on';'采样设置','delay_on','on'}; ...
 {'功率设置','gate_on','on';'功率设置','dead_on','on'}};
for k=1:numel(invalids)
 before=pmsm_reference('capture');c=cfg;
 pairs=invalids{k};for j=1:size(pairs,1),c=set(c,pairs{j,1},pairs{j,2},pairs{j,3});end
 failed=false;try,pmsm_config('apply',c);catch err,failed=startsWith(err.identifier,'pmsm:Switch');end
 assert(failed&&isequaln(before,pmsm_reference('capture')),'错误组合未被无副作用地拒绝。');
end
record.invalid_combinations_rejected=numel(invalids);
% Parameter restore must not certify an unsaved control-logic edit as baseline.
gains=find_system(mdl,'LookUnderMasks','all','FollowLinks','off','BlockType','Gain');probe=gains{1};oldGain=get_param(probe,'Gain');
set_param(probe,'Gain','2');edited=teach_snapshot(mdl);failed=false;
try,pmsm_reference('restore',ref,mdl);catch,failed=true;end
assert(failed&&isequaln(edited,teach_snapshot(mdl)));set_param(probe,'Gain',oldGain);record.unsaved_algorithm_edit_rejected=true;
% A numerical constraint fails only at model update; check transactional rollback.
before=pmsm_reference('capture');bad=set(set(cfg,'时序设置','real_on','on'),'时序设置','compute_us','50');
failed=false;try,pmsm_config('apply',bad);catch,failed=true;end
assert(failed&&isequaln(before,pmsm_reference('capture')),'更新失败后的参数回滚不完整。');record.compile_failure_rolled_back=true;
fprintf('REFERENCE_DISTURB_AND_RESTORE\n');
c=set(set(set(cfg,'电机与工况','n','1200'),'电机与工况','Rs','0.12'),'采样设置','noise_on','on');
c=set(c,'角度设置','bias_on','on');pmsm_config('apply',c);
mw=get_param(mdl,'ModelWorkspace');assignin(mw,'kp_w',2*getVariable(mw,'kp_w'));
motor=getfullname(Simulink.ID.getHandle([mdl ':626']));set_param([motor '/id_iq_wm_theta'],'InitialCondition','[0;1;10;0]');
set_param([mdl '/speed_ref'],'Value','1200');set_param(mdl,'StopTime','.02','FixedStep','2e-6');
assert(~isequaln(baseline,pmsm_reference('capture')));
restored=pmsm_reference('restore',ref,mdl);assert(isequaln(restored,baseline));
assert(isequaln(geometry,teach_snapshot(mdl)));record.complete_restore_passed=true;record.layout_and_algorithms_preserved=true;
% Save only the disposable copy, then verify the restored state survives reload.
save_system(mdl,candidate);close_system(mdl,0);load_system(candidate);set_param(mdl,'SimulationCommand','update');
assert(isequaln(baseline,pmsm_reference('capture')));record.saved_reload_preserved=true;
fprintf('REFERENCE_RELOAD_REPEAT_1S\n');o=sim(mdl);repeated=signatures(o);clear o;
assert(isequaln(referenceSignals,repeated),'固定参考保存重载后时间序列改变。');record.repeated_identical_signals=numel(repeated);
% Return to the byte-identical source copy for strict reference identity checks.
close_system(mdl,0);copyfile(source,candidate);load_system(candidate);pmsm_reference('restore',ref,mdl);
fprintf('REFERENCE_NOISE_SEED_REPEAT_50MS\n');
in=Simulink.SimulationInput(mdl);in=in.setModelParameter('StopTime','.05');in=in.setBlockParameter([mdl '/采样设置'],'noise_on','on');
o=sim(in);noiseFirst=signatures(o);noise=teach_values(o.log_iabc_noise);assert(any(noise~=0,'all'));clear o;
o=sim(in);noiseSecond=signatures(o);clear o;assert(isequaln(noiseFirst,noiseSecond));record.noise_seed_repeated_identically=true;
pmsm_reference('restore',ref,mdl);
% Accidental reference-file edits must be detected before a restore mutation.
stateFile=fullfile(ref,'state.json');original=fileread(stateFile);fid=fopen(stateFile,'a','n','UTF-8');fprintf(fid,' ');fclose(fid);
before=pmsm_reference('capture');failed=false;try,pmsm_reference('restore',ref,mdl);catch,failed=true;end
fid=fopen(stateFile,'w','n','UTF-8');fprintf(fid,'%s',original);fclose(fid);
assert(failed&&isequaln(before,pmsm_reference('capture')));pmsm_reference('verify',ref,mdl);record.tampered_reference_rejected=true;
f=open_pmsm_settings;fg=onCleanup(@()close(f));assert(isscalar(findall(f,'Tag','RestoreFixedReference')));clear fg;
record.editor_entry_created=true;record.parameter_count=manifest.parameter_count;record.switch_count=manifest.switch_count;
assert(strcmp(sourceHash,teach_hash(source)),'主模型文件被改变。');record.main_model_unchanged=true;
record.all_passed=true;teach_writejson(fullfile(here,'reference_validation.json'),record);
fprintf('REFERENCE_ALL_PASS %s\n',sourceHash);
end

function c=set(c,section,key,value)
ix=find(strcmp({c.rows.section},section)&strcmp({c.rows.key},key));assert(isscalar(ix));c.rows(ix).value=value;
end

function c=enable(c,section,key,catalog)
c=set(c,section,key,'on');ix=find(strcmp({catalog.section},section)&strcmp({catalog.key},key));
for id=catalog(ix).requires,p=split(id{1},'.');c=enable(c,p{1},p{2},catalog);end
end

function s=signatures(o)
s=struct('name',{},'samples',{},'data_size',{},'time_sha256',{},'data_sha256',{});names=sort(o.who);
for k=1:numel(names)
 v=o.get(names{k});if ~isa(v,'timeseries'),continue;end
 assert(all(isfinite(v.Time),'all')&&all(isfinite(v.Data),'all'),'非有限时间序列：%s',names{k});
 s(end+1)=struct('name',names{k},'samples',numel(v.Time),'data_size',size(v.Data),'time_sha256',digest(v.Time),'data_sha256',digest(v.Data));
end
end

function h=digest(x)
md=java.security.MessageDigest.getInstance('SHA-256');md.update(uint8(class(x)));md.update(typecast(double(size(x)),'uint8'));
if islogical(x),bytes=uint8(x(:));else,bytes=typecast(x(:),'uint8');end
md.update(bytes);h=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
end

function m=metrics(o)
speed=teach_values(o.log_speed);iq=teach_values(o.log_iq);id=teach_values(o.log_id);
m=struct('duration_s',o.log_speed.Time(end),'speed_final_rpm',speed(end),'speed_peak_rpm',max(speed), ...
 'iq_peak_A',max(abs(iq)),'id_peak_A',max(abs(id)));
assert(abs(m.speed_final_rpm-3000)<10,'参考速度未到达指定范围。');
end
