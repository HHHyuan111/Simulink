function report=verify_sensorless_robust_r0(first,second)
% Full archived component arrays, no model load and no tolerance relaxation.
here=fileparts(mfilename('fullpath'));root=fileparts(here);addpath(fullfile(fileparts(root),'teaching'));
a=check(first,here,root);b=check(second,here,root);
assert(strcmp(a.matlab_version,b.matlab_version)&&isequaln(a.source_files,b.source_files)&&isequaln(a.contracts,b.contracts));
x=load(fullfile(first,'raw.mat'));y=load(fullfile(second,'raw.mat'));
ma=jsondecode(fileread(fullfile(first,'metrics.json')));mb=jsondecode(fileread(fullfile(second,'metrics.json')));
report=struct('schema',1,'node','N3R0','first_folder',first,'second_folder',second,...
 'raw_numeric_elements',a.raw_numeric_elements,'complete_raw_identical',isequaln(x.raw,y.raw),...
 'metrics_identical',isequaln(ma,mb),'model_loaded',bdIsLoaded('PMSM_FOC_R2026a'),...
 'verification_driver_sha256',teach_hash([mfilename('fullpath') '.m']));
report.all_passed=report.complete_raw_identical&&report.metrics_identical&&~report.model_loaded;
teach_writejson(fullfile(second,'replay_validation.json'),report);
fprintf('N3R0_REPLAY_PASSED=%d elements=%d\n',report.all_passed,report.raw_numeric_elements);assert(report.all_passed);
end

function r=check(folder,here,root)
r=jsondecode(fileread(fullfile(folder,'record.json')));assert(strcmp(r.status,'passed')&&r.all_passed&&~r.model_loaded);
assert(strcmp(r.raw_sha256,teach_hash(fullfile(folder,'raw.mat'))));
for f=r.source_files(:)',assert(strcmp(f.sha256,teach_hash(fullfile(here,f.path))));end
for f=r.contracts(:)',assert(strcmp(f.sha256,teach_hash(fullfile(root,f.path))));end
end
