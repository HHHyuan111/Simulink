function pmsm_render_sampling_window_run(folder)
here=fileparts(mfilename('fullpath'));addpath(here);plan=jsondecode(fileread(fullfile(folder,'plan.json')));
assert(strcmp(plan.scenario.id,'sampling_window'));outputs=cell(1,3);
for k=1:3,u=load(fullfile(folder,[plan.cases(k).id '.mat']),'signals');outputs{k}=u.signals;end
plot_pmsm_sampling_window(outputs,plan,folder);fprintf('SAMPLING_WINDOW_RENDER_PASS\n');
end
