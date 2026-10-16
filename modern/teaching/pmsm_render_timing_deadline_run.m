function pmsm_render_timing_deadline_run(folder)
here=fileparts(mfilename('fullpath'));addpath(here);plan=jsondecode(fileread(fullfile(folder,'plan.json')));
assert(strcmp(plan.scenario.id,'timing_deadline'));outputs=cell(1,3);
for k=1:3,u=load(fullfile(folder,[plan.cases(k).id '.mat']),'signals');outputs{k}=u.signals;end
plot_pmsm_timing_deadline(outputs,plan,folder);fprintf('TIMING_DEADLINE_RENDER_PASS\n');
end
