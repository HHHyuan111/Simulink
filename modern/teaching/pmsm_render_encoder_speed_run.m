function pmsm_render_encoder_speed_run(folder)
plan=jsondecode(fileread(fullfile(folder,'plan.json')));data=load(fullfile(folder,'reference.mat'),'signals');
plot_pmsm_encoder_speed({data.signals},plan,folder);fprintf('ENCODER_SPEED_RENDER_PASS\n');
end
