function [out,report]=sensorless_r2_run_initialized(sm,h,duration,folder,chunk)
% Advance the same compiled simulation. Never initialize or tune here.
if nargin<5,chunk=160000;end
assert(strcmp(sm.Status,'initialized')&&abs(sm.Time)<1e-12);
validateattributes(chunk,{'double'},{'scalar','integer','positive'});
total=round(duration/h)+1;assert(abs((total-1)*h-duration)<1e-12);
report=struct('initialized_once',true,'step_chunks',0,'requested_major_steps',0,'expected_major_steps',total,...
 'last_step',false,'status','running','next_major_time_s',sm.Time);
started=tic;
while report.requested_major_steps<total
 count=min(chunk,total-report.requested_major_steps);last=step(sm,NumberOfSteps=count);
 report.step_chunks=report.step_chunks+1;report.requested_major_steps=report.requested_major_steps+count;
 report.next_major_time_s=sm.Time;report.last_step=last;
 assert(~last||report.requested_major_steps==total,'sensorless:V8EarlyStop','Simulation ended before the expected native endpoint.');
 teach_writejson(fullfile(folder,'execution_progress.json'),report);
end
assert(last,'sensorless:V8Endpoint','Final major step missing.');
report.status_before_stop=char(sm.Status);report.api_time_finite_at_completion=isfinite(sm.Time);
if strcmp(sm.Status,'inactive'),out=sm.SimulationOutput;else,out=stop(sm);end
assert(strcmp(sm.Status,'inactive'));
report.elapsed_s=toc(started);report.status='completed';report.status_after_stop=char(sm.Status);
teach_writejson(fullfile(folder,'execution_progress.json'),report);
end
