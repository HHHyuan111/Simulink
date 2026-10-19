function report=run_sensorless_direct_baseline
% Same physical model and stop time, with only the observation layer removed.
base=sensorless_direct_setup;mdl='PMSM_FOC_R2026a';folder=fullfile(base,'runs','SMO_direct_baseline');
assert(~isfolder(folder));mkdir(folder);file=fullfile(folder,[mdl '.slx']);
source=fullfile(base,'models','direct',[mdl '.slx']);copyfile(source,file);
report=struct('phase','configure','passed',false,'process_id',matlabProcessID,'simulation_starts',0,...
 'source_direct_model_sha256',teach_hash(source),'duration_s',.25);
load_system(file);cleanup=onCleanup(@()close_private(mdl)); %#ok<NASGU>
delete_block([mdl '/无感观测']);delete_block([mdl '/输出延迟/无感生效阈值']);delete_block([mdl '/采样设置/无感ADC原始']);
set_param(mdl,'InitFcn','');save_system(mdl,file);
cache=fullfile(base,'.build','direct_baseline');Simulink.fileGenControl('set','CacheFolder',fullfile(cache,'c'),'CodeGenFolder',fullfile(cache,'g'),'createDir',true);
report.phase='simulate';report.simulation_starts=1;teach_writejson(fullfile(folder,'report.json'),report);started=tic;
out=sim(mdl,'SimulationMode','normal','StopTime','.25','ReturnWorkspaceOutputs','on');report.elapsed_s=toc(started);assert(isempty(out.ErrorMessage));
schema=jsondecode(fileread(fullfile(base,'baseline','log_schema.json')));signals=struct;
for k=1:numel(schema),signals.(schema(k).name)=out.get(schema(k).name);end
save(fullfile(folder,'signals.mat'),'-struct','signals','-v7.3');clear out;close_system(mdl,0);
report.raw_sha256=teach_hash(fullfile(folder,'signals.mat'));report.phase='completed';report.passed=true;teach_writejson(fullfile(folder,'report.json'),report);
review_sensorless_direct_first;
end
function close_private(mdl)
if bdIsLoaded(mdl),close_system(mdl,0);end
end
