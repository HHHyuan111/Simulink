function pmsm_render_encoder_run(folder)
plan=jsondecode(fileread(fullfile(folder,'plan.json')));outputs=cell(1,numel(plan.cases));
for k=1:numel(plan.cases),data=load(fullfile(folder,[plan.cases(k).id '.mat']),'signals');outputs{k}=data.signals;end
plot_pmsm_encoder(outputs,plan,folder);fprintf('ENCODER_RENDER_PASS\n');
end
