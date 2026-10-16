function validate_parameter_settings
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);addpath(fullfile(root,'deadtime'));
mdl='PMSM_FOC_R2026a';work=fullfile(root,'.build','parameter_settings');if ~isfolder(work),mkdir(work);end
source=fullfile(root,'.build','deadtime_stage',[mdl '.slx']);candidate=fullfile(work,[mdl '.slx']);copyfile(source,candidate);
load_system(candidate);guard=onCleanup(@()close_system(mdl,0));mw=get_param(mdl,'ModelWorkspace');initial=teach_snapshot(mdl);code=mw.MATLABCode;
base=pmsm_config('read');assert(numel(base.rows)>60);gains=struct;
for key={'kp_w','ki_w','ks_w','kp_id','ki_id','ks_id','kp_iq','ki_iq','ks_iq'},gains.(key{1})=getVariable(mw,key{1});end
for name={'reference','teaching','board'}
 fprintf('SETTINGS_PRESET %s\n',name{1});c=pmsm_config('preset',name{1});actual=pmsm_config('apply',c);
 teach_writejson(fullfile(work,['check_' name{1} '.json']),struct('expected',c,'actual',actual));
 assert(isequaln(c.rows,actual.rows));fprintf('SETTINGS_PRESET_PASS %s\n',name{1});
end
fprintf('SETTINGS_RESTORE_BASE\n');
pmsm_config('apply',base);
before=teach_snapshot(mdl);beforeCode=mw.MATLABCode;
bad=pmsm_config('preset','teaching');ix=find(strcmp({bad.rows.key},'dead_on'));bad.rows(ix).value='on';
failed=false;try,pmsm_config('apply',bad);catch,failed=true;end;assert(failed);assert(isequaln(before,teach_snapshot(mdl))&&strcmp(beforeCode,mw.MATLABCode));
bad=base;ix=find(strcmp({bad.rows.key},'ron'));bad.rows(ix).value='-1';failed=false;try,pmsm_config('apply',bad);catch,failed=true;end;assert(failed);
changed=base;
for pair={'Rs','0.12';'Iq_limit','7';'fc','10000';'Ts_speed','0.0002'}'
 ix=find(strcmp({changed.rows.section},'电机与工况')&strcmp({changed.rows.key},pair{1}));changed.rows(ix).value=pair{2};changed.rows(ix).source='test calibration';changed.rows(ix).status='测试';
end
changed=pmsm_config('apply',changed);assert(getVariable(mw,'Rs')==.12&&getVariable(mw,'dt')==.0001);assert(abs(getVariable(mw,'uplimit_w')-7*getVariable(mw,'Kt'))<1e-12);
in=Simulink.SimulationInput(mdl);in=in.setModelParameter('StopTime','.003');o=sim(in);assert(all(isfinite(o.log_iq.Data),'all'));
for key=fieldnames(gains)',assert(isequal(gains.(key{1}),getVariable(mw,key{1})));end
reload(mw);save_system(mdl,candidate);close_system(mdl,0);load_system(candidate);fresh=pmsm_config('read');
teach_writejson(fullfile(work,'reload_check.json'),struct('expected',changed,'actual',fresh));
assert(isequaln(fresh.rows,changed.rows));pmsm_config('apply',base);
now=teach_snapshot(mdl);assert(numel(now.blocks)==numel(initial.blocks)&&isequaln(now.regions,initial.regions));
for k=1:numel(initial.blocks),assert(isequal(initial.blocks(k).position,now.blocks(k).position));end
% Instantiate the editor and check the complete editable table exists.
f=open_pmsm_settings;cleanup=onCleanup(@()close(f));tables=findall(f,'Type','uitable');assert(isscalar(tables)&&size(tables.Data,2)==6);clear cleanup;
record=struct('all_passed',true,'parameter_count',numel(base.rows),'pi_unchanged',true,'presets_compiled',true,'invalid_settings_rolled_back',true,'motor_dependencies_updated',true,'saved_reload_preserved',true,'layout_preserved',true,'editor_created',true);
teach_writejson(fullfile(folder,'parameter_settings_results.json'),record);teach_writejson(fullfile(folder,'parameter_reference.json'),base);
for name={'reference','teaching','board'},teach_writejson(fullfile(folder,['profile_' name{1} '.json']),pmsm_config('preset',name{1}));end
fprintf('PARAMETER_SETTINGS_ALL_PASS %d\n',numel(base.rows));
end
