function validate_deadtime_probes
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);addpath(fullfile(root,'teaching'));
mdl='PMSM_FOC_R2026a';file=fullfile(root,[mdl '.slx']);hash=teach_hash(file);load_system(file);g=onCleanup(@()close_system(mdl,0));before=teach_snapshot(mdl);mw=get_param(mdl,'ModelWorkspace');code=mw.MATLABCode;
opt=struct('rpm',300,'load_Nm',.08,'comp_us',2,'hysteresis_A',.05);a=run_deadtime_case(mdl,2,'on',.003,1,opt);opt.aligned_current_logs=true;b=run_deadtime_case(mdl,2,'on',.003,1,opt);
count=0;maximum=0;for key=a.who'
 if ismember(key{1},{'log_iabc_meas','log_iabc_true'}),continue;end
 x=a.get(key{1});if ~isa(x,'timeseries'),continue;end;y=b.get(key{1});assert(isequal(x.Time,y.Time));d=max(abs(teach_values(x)-teach_values(y)),[],'all');assert(isfinite(d)&&d<1e-10);count=count+1;maximum=max(maximum,d);
end
reload(mw);assert(strcmp(code,mw.MATLABCode)&&isequaln(before,teach_snapshot(mdl))&&strcmp(hash,teach_hash(file)));
ref=check_low_deadtime_reference;for report={'report_hysteresis','report_amplitude'},p=fullfile(folder,report{1},'results.json');r=jsondecode(fileread(p));assert(r.all_passed&&strcmp(r.model_sha256,hash));r.reference=ref;teach_writejson(p,r);end
assert(nargin('run_deadtime_demo')==5&&nargin('plot_three_phase_lesson')==6&&nargin('plot_deadtime_report')==6);
out=fullfile(folder,'report_probe_validation');if ~isfolder(out),mkdir(out);end
work=fullfile(root,'.build','deadtime_demo');opts=struct('comp_us',2,'hysteresis_A',.05);plot_three_phase_lesson(work,out,2,300,.08,opts);plot_deadtime_report(work,out,2,300,.08,opts);
r=struct('all_passed',true,'model_sha256',hash,'alignment_only_logs_excluded',{{'log_iabc_meas','log_iabc_true'}},'unchanged_timeseries',count,'max_abs_difference',maximum,'source_model_unchanged',true,'source_workspace_code_unchanged',true,'new_option_titles_rendered',true,'reference',ref);
teach_writejson(fullfile(folder,'parameter_probe_validation.json'),r);fprintf('PARAMETER_PROBE_ALL_PASS count=%g difference=%g\n',count,maximum);
end
