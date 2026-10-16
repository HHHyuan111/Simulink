function export_pmsm_experiment_examples_stage2
% Compatibility entrance: use the common clean renderer for the three scenes.
here=fileparts(mfilename('fullpath'));indexPath=fullfile(here,'experiment_stage2_validation.json');
index=jsondecode(fileread(indexPath));assert(index.all_passed);
index.run_folders=rmfield(index.run_folders,{'zero_angle','current_bias','current_noise','sample_delay'});
temporary=fullfile(fileparts(here),'.build',['stage2_gallery_' char(java.util.UUID.randomUUID) '.json']);
teach_writejson(temporary,index);export_pmsm_experiment_examples(temporary);
end

