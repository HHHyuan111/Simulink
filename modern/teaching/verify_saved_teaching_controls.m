function report=verify_saved_teaching_controls
% Verify the saved embedded model in a fresh MATLAB process.
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);mdl='PMSM_FOC_R2026a';
source=fullfile(root,[mdl '.slx']);record=jsondecode(fileread(fullfile(folder,'teaching_validation.json')));
assert(~bdIsLoaded(mdl),'Run this saved-file check in a fresh MATLAB session with the model closed.');
assert(strcmp(teach_hash(source),record.after_sha256));load_system(source);guard=onCleanup(@()close_system(mdl,0));
settings=teach_settings(mdl);assert(strcmp(jsonencode(settings),jsonencode(record.defaults)));
set_param(mdl,'SimulationCommand','update');mw=get_param(mdl,'ModelWorkspace');
assert(getVariable(mw,'teaching_Ts_speed')==getVariable(mw,'Ts_speed'));
assert(getVariable(mw,'teach_pwm_on')==0);
assert(numel(find_system(mdl,'SearchDepth',1,'Type','Block'))==record.top_blocks);
assert(numel(find_system(mdl,'LookUnderMasks','all','FollowLinks','off','Type','Block'))==record.total_blocks);
% A short fresh simulation exercises all embedded masks and callbacks.
in=Simulink.SimulationInput(mdl);in=setModelParameter(in,'StopTime','0.005');out=sim(in);
assert(isequal(out.log_iabc_true.Data,out.log_iabc_meas.Data));
assert(isequal(out.log_theta_true.Data,out.log_theta_meas.Data));
assert(isequal(out.log_Tcm_requested.Data,out.log_Tcm_applied.Data));
report=struct('matlab',version,'sha256',teach_hash(source),'all_defaults_off',true, ...
 'embedded_init_and_masks_work',true,'passed',true);
reference=fullfile(root,'.build','speed_loop_stage1','after_sim.mat');
report.full_second_comparison_available=isfile(reference);
if isfile(reference)
 previous=load(reference,'corrected','report');assert(strcmp(previous.report.after_sha256,record.before_sha256));
 fprintf('TEACHING_RELOAD_DEFAULT_1S\n');
 in=Simulink.SimulationInput(mdl);in=setModelParameter(in,'StopTime','1');full=sim(in);
 names=previous.corrected.who;checked=0;
 for k=1:numel(names)
  old=previous.corrected.get(names{k});if ~isa(old,'timeseries'),continue;end
  fresh=full.get(names{k});assert(isequaln(old.Time,fresh.Time)&&isequaln(old.Data,fresh.Data), ...
   'Full-second reference changed: %s',names{k});checked=checked+1;
 end
 assert(checked==12);report.full_second_original_signals_identical=checked;
end
teach_writejson(fullfile(folder,'teaching_reload_check.json'),report);
fprintf('TEACHING_RELOAD_PASSED\n');
end
