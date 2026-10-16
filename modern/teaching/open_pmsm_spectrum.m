function f=open_pmsm_spectrum
% Native MATLAB figure with native zoom/data tips, no custom viewer.
here=fileparts(mfilename('fullpath'));folder=fullfile(here,'frequency','deadtime_v1');
try
 r=jsondecode(fileread(fullfile(folder,'manifest.json')));
 summary=jsondecode(fileread(fullfile(here,'experiments','examples','low_speed_compensation','summary.json')));
 assert(strcmp(r.source_run_id,summary.source_run_id));
 source=fullfile(here,'experiments','runs',r.source_run_id);pmsm_experiment_verify(source);
 assert(strcmp(r.source_record_sha256,teach_hash(fullfile(source,'record.json'))));
 for entry=r.source_files(:)',assert(strcmp(entry.sha256,teach_hash(fullfile(here,entry.path))));end
 for entry=r.files(:)',assert(strcmp(entry.sha256,teach_hash(fullfile(folder,entry.path))));end
catch
 export_pmsm_deadtime_spectrum([],folder);
end
f=openfig(fullfile(folder,'spectrum.fig'),'new','visible');
end
