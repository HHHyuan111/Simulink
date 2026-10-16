function pmsm_render_noise_filter_run(folder)
% Fresh-process renderer: consume only the three already-saved raw records.
here=fileparts(mfilename('fullpath'));addpath(here);
plan=jsondecode(fileread(fullfile(folder,'plan.json')));assert(strcmp(plan.scenario.id,'noise_filter'));
ids={'reference','factor','filtered'};outputs=cell(1,3);
for k=1:3,u=load(fullfile(folder,[ids{k} '.mat']),'signals');outputs{k}=u.signals;end
plot_pmsm_noise_filter(outputs,plan,folder);fprintf('NOISE_FILTER_RENDER_PASS\n');
end
