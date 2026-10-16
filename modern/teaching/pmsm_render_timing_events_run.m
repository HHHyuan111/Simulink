function pmsm_render_timing_events_run(folder)
% Isolated renderer reads only the already-saved raw records and plan.
here=fileparts(mfilename('fullpath'));addpath(here);plan=jsondecode(fileread(fullfile(folder,'plan.json')));
assert(strcmp(plan.scenario.id,'timing_events'));ids={'reference','factor'};outputs=cell(1,2);
for k=1:2,u=load(fullfile(folder,[ids{k} '.mat']),'signals');outputs{k}=u.signals;end
plot_pmsm_timing_events(outputs,plan,folder);fprintf('TIMING_EVENTS_RENDER_PASS\n');
end
