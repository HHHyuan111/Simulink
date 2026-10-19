function report=run_sensorless_closed(label,show)
if nargin<2,show=false;end
here=fileparts(mfilename('fullpath'));addpath(fullfile(fileparts(here),'direct'));base=sensorless_direct_setup;addpath(here);
mdl='PMSM_SMO_ClosedLoop';folder=fullfile(base,'runs',['SMO_closed_' label]);assert(~isfolder(folder));mkdir(folder);
file=fullfile(base,'models','closed_loop',[mdl '.slx']);build=jsondecode(fileread(fullfile(base,'models','closed_loop','build.json')));
report=struct('phase','load','passed',false,'process_id',matlabProcessID,'simulation_starts',0,'model_sha256',teach_hash(file),'label',label);
copyfile(file,fullfile(folder,[mdl '.slx']));copyfile(fullfile(base,'closed_loop','acceptance.json'),fullfile(folder,'acceptance.json'));
cache=fullfile(base,'.build',['closed_' label]);Simulink.fileGenControl('set','CacheFolder',fullfile(cache,'c'),'CodeGenFolder',fullfile(cache,'g'),'createDir',true);
load_system(file);if show,open_system(mdl);open_system([mdl '/闭环结果观测/闭环全过程']);end
try
 report.phase='simulate';report.simulation_starts=1;write_report;started=tic;
 out=sim(mdl,'SimulationMode','normal','StopTime','.5','ReturnWorkspaceOutputs','on');report.elapsed_s=toc(started);assert(isempty(out.ErrorMessage));
 report.phase='archive';write_report;signals=struct;
 for key=out.who',value=out.get(key{1});if isa(value,'timeseries'),signals.(key{1})=value;end,end
 save(fullfile(folder,'signals.mat'),'-struct','signals','-v7.3');clear out;report.raw_sha256=teach_hash(fullfile(folder,'signals.mat'));
 if ~show,close_system(mdl,0);end
 c=jsondecode(fileread(fullfile(base,'closed_loop','acceptance.json')));metrics=analyse_sensorless_closed(signals,c);
 teach_writejson(fullfile(folder,'metrics.json'),metrics);report.metrics_passed=metrics.passed;
 report.passed=metrics.passed&&strcmp(report.model_sha256,build.model_sha256);report.phase='completed';write_report;
 if show,open_system([mdl '/闭环结果观测/闭环全过程']);end
catch err
 report.failed_phase=report.phase;report.phase='failed';report.error_identifier=err.identifier;write_report;rethrow(err);
end
 function write_report,teach_writejson(fullfile(folder,'report.json'),report);fprintf('SMO_CLOSED %s %s\n',label,report.phase);end
end
