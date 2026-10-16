function bound_deadtime_logs
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);addpath(fullfile(root,'teaching'));
work=fullfile(root,'.build','deadtime_stage');mdl='PMSM_FOC_R2026a';file=fullfile(work,[mdl '.slx']);recordFile=fullfile(folder,'deadtime_stage4_results.json');r=jsondecode(fileread(recordFile));
assert(strcmp(teach_hash(file),r.model_sha256));r.validated_algorithm_model_sha256=r.model_sha256;
copyfile(file,fullfile(work,'PMSM_FOC_before_log_bound.slx'));load_system(file);guard=onCleanup(@()close_system(mdl,0));before=teach_snapshot(mdl);allowed=before;
for name={'obs_dead_requested','obs_dead_gates'}
 b=find_system(mdl,'LookUnderMasks','all','BlockType','ToWorkspace','VariableName',name{1});assert(isscalar(b));set_param(b{1},'MaxDataPoints','4000');
 ix=find(strcmp({allowed.blocks.path},b{1}));allowed.blocks(ix).params.MaxDataPoints='4000';
end
assert(isequaln(allowed,teach_snapshot(mdl)),'Changes beyond logging retention.');save_system(mdl,file);close_system(mdl,0);load_system(file);assert(isequaln(allowed,teach_snapshot(mdl)));
r.model_sha256=teach_hash(file);r.publication_status='verified_candidate';r.logging_retention_only=true;r.dead_gate_log_max_points=4000;
r.notes{end+1}='Only the two new high-rate gate ToWorkspace logs are bounded to their last4000 points. Algorithm, scripts, other48 logs, gains and geometry unchanged; saved reload verified.';
teach_writejson(recordFile,r);fprintf('BOUNDED_LOGS_READY %s\n',r.model_sha256);
end
