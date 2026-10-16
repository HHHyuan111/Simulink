function result=validate_pmsm_system_baseline(folder)
% Audit completed joint-chain evidence, reversible structure and UI entry.
here=fileparts(mfilename('fullpath'));root=fileparts(here);addpath(fullfile(root,'teaching'));
if nargin<1,x=jsondecode(fileread(fullfile(here,'latest.json')));folder=x.folder;end
r=verify_pmsm_system_baseline(folder);p=jsondecode(fileread(fullfile(folder,'plan.json')));
outputs=cell(1,2);for k=1:2,x=load(fullfile(folder,[r.cases(k).id '.mat']),'signals');outputs{k}=x.signals;end
analysis=pmsm_system_analysis(outputs,p);
result=struct('kind',r.kind,'default_folder',folder,'checks',struct,'model_sha256',r.model_sha256,'reference_sha256',r.reference_sha256);
result.checks.raw_data_mechanism_and_platform_analysis=analysis.interface_checks_passed;
result.platforms_pass=analysis.all_platforms_pass;
for value={[10000.5 2 200],[10000 2.5 200],[10000 2 0],[10000 2 NaN]}
 rejected=false;try,pmsm_system_plan(value{1});catch,rejected=true;end;assert(rejected);
end
result.checks.invalid_parameters_rejected=true;
mdl='PMSM_FOC_R2026a';assert(~bdIsLoaded(mdl));load_system(fullfile(root,[mdl '.slx']));guard=onCleanup(@()close_system(mdl,0));
pmsm_reference('restore');before=teach_snapshot(mdl);
pmsm_encoder_model('install',mdl);pmsm_encoder_speed_model('install',mdl);pmsm_speed_feedback_model('install',mdl);pmsm_speed_filter_model('install',mdl);
pmsm_system_inputs('install',mdl,p.input_schedule);pmsm_system_inputs('remove',mdl);pmsm_encoder_model('remove',mdl);
pmsm_reference('restore');assert(isequaln(before,teach_snapshot(mdl)));result.checks.install_remove_preserves_original_structure=true;
f=open_pmsm_framework('off');uiGuard=onCleanup(@()delete(f));
buttons=findall(f,'Type','uibutton');assert(numel(buttons)==6&&any(strcmp({buttons.Text},'运行整机基线'))&&any(strcmp({buttons.Text},'单项实验')));
t=findall(f,'Type','uitable');assert(isscalar(t)&&size(t.Data,1)==6);result.checks.unified_navigation_created=true;clear uiGuard;
% A modified plan must be refused before any later artifact is even read.
work=fullfile(root,'.build',['system_tamper_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);mkdir(work);
copyfile(fullfile(folder,'record.json'),fullfile(work,'record.json'));copyfile(fullfile(folder,'plan.json'),fullfile(work,'plan.json'));
fid=fopen(fullfile(work,'plan.json'),'a');fprintf(fid,'\n');fclose(fid);rejected=false;
try,verify_pmsm_system_baseline(work);catch err,rejected=contains(err.message,'plan.json');end
assert(rejected);result.checks.changed_plan_rejected=true;
legacy=jsondecode(fileread(fullfile(here,'legacy_regression.json')));
assert(legacy.all_exact&&numel(legacy.signals)==66);pmsm_experiment_verify(legacy.repeated_folder);
result.checks.legacy_speed_filter_66_signals_exact=true;result.legacy_regression=legacy.repeated_folder;
% Verify historic archives without rewriting figures or their manifests.
gallery=jsondecode(fileread(fullfile(root,'teaching','experiment_gallery_validation.json')));
result.previous_gallery_validation=gallery;
result.checks.main_and_reference_preserved=strcmp(teach_hash(fullfile(root,[mdl '.slx'])),r.model_sha256)&&...
 strcmp(teach_hash(fullfile(root,'teaching','reference_v1','manifest.json')),r.reference_sha256);
assert(result.checks.main_and_reference_preserved);
result.all_interface_checks_passed=all(structfun(@(x)logical(x),result.checks));
checks=dir(fullfile(here,'repeat_checks','*.json'));found=false;
for k=1:numel(checks)
 receipt=fullfile(checks(k).folder,checks(k).name);c=jsondecode(fileread(receipt));
 sameFolder=strcmpi(strrep(folder,'\','/'),strrep(c.original_folder,'\','/'))||strcmpi(strrep(folder,'\','/'),strrep(c.repeated_folder,'\','/'));
 if sameFolder
  assert(c.all_exact&&c.same_matlab_version&&numel(c.signals)==66);
  verify_pmsm_system_baseline(c.original_folder);verify_pmsm_system_baseline(c.repeated_folder);
  result.reproducibility=struct('original_folder',c.original_folder,'repeated_folder',c.repeated_folder,...
   'signal_count',numel(c.signals),'all_exact',c.all_exact,'receipt',receipt,'receipt_sha256',teach_hash(receipt));
  found=true;break
 end
end
result.all_passed=result.all_interface_checks_passed&&result.platforms_pass&&found;
result.repeat_evidence_found=found;result.example_source_sha256=teach_hash(fullfile(here,'examples','source.json'));
result.validator_sha256=teach_hash([mfilename('fullpath') '.m']);
teach_writejson(fullfile(here,'system_baseline_validation.json'),result);
fprintf('SYSTEM_VALIDATION_PASS %d; PLATFORMS_PASS %d; REPEAT_EVIDENCE %d\n',result.all_passed,result.platforms_pass,found);
end
