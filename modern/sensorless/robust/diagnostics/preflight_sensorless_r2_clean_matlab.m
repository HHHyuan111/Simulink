function report=preflight_sensorless_r2_clean_matlab(folder,expectedRoot,expectedPref)
% Environment metadata only; do not load, compile, or simulate a model.
assert(~isfolder(folder));mkdir(folder);
report=struct('status','running','simulation_starts',0,'model_loads',0,...
 'process_id',matlabProcessID,'matlab_version',version,'release',version('-release'),...
 'matlabroot',matlabroot,'prefdir',prefdir,'all_passed',false);
write_report;
try
 assert(strcmp(version,'26.1.0.3346908 (R2026a) Update 5'));
 assert(strcmpi(canonical(matlabroot),canonical(expectedRoot)));
 assert(strcmpi(canonical(prefdir),canonical(expectedPref)));
 products=ver;report.product_names={products.Name};
 assert(all(ismember({'MATLAB','Simulink','Stateflow'},report.product_names)));
 report.license_test=struct('MATLAB',logical(license('test','MATLAB')),...
  'Simulink',logical(license('test','SIMULINK')),'Stateflow',logical(license('test','Stateflow')));
 assert(all(structfun(@(x)x,report.license_test)));
 names={'sim','load_system','sfroot','Simulink.fileGenControl'};
 for k=1:numel(names)
  resolved=which(names{k});assert(~isempty(resolved));
  report.functions(k)=struct('name',names{k},'path',resolved);
  assert(contains(lower(strrep(resolved,'\','/')),lower(strrep(expectedRoot,'\','/'))));
 end
 report.all_passed=true;report.status='passed';write_report;
catch err
 report.status='failed';report.error_identifier=err.identifier;write_report;rethrow(err);
end
 function write_report
  fid=fopen(fullfile(folder,'report.json'),'w');assert(fid>=0);closeFile=onCleanup(@()fclose(fid));
  fwrite(fid,jsonencode(report),'char');
 end
end
function path=canonical(path)
path=char(java.io.File(path).getCanonicalPath);
end
