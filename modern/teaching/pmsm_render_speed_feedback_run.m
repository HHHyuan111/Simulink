function pmsm_render_speed_feedback_run(folder)
p=jsondecode(fileread(fullfile(folder,'plan.json')));outputs=cell(1,3);
for k=1:3,a=load(fullfile(folder,[p.cases(k).id '.mat']),'signals');outputs{k}=a.signals;end
plot_pmsm_speed_feedback(outputs,p,folder);fprintf('SPEED_FEEDBACK_RENDER_PASS\n');
end
