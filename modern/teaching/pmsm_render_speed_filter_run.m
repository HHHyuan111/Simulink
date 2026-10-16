function pmsm_render_speed_filter_run(folder)
p=jsondecode(fileread(fullfile(folder,'plan.json')));outputs=cell(1,2);
for k=1:2,a=load(fullfile(folder,[p.cases(k).id '.mat']),'signals');outputs{k}=a.signals;end
plot_pmsm_speed_filter(outputs,p,folder);fprintf('SPEED_FILTER_RENDER_PASS\n');
end
