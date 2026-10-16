function result=export_pmsm_deadtime_spectrum(sourceFolder,outputFolder)
% Derived report only: archived experiments and the model are never written.
here=fileparts(mfilename('fullpath'));
if nargin<1||isempty(sourceFolder)
 summary=jsondecode(fileread(fullfile(here,'experiments','examples','low_speed_compensation','summary.json')));
 sourceFolder=fullfile(here,'experiments','runs',summary.source_run_id);
end
if nargin<2,outputFolder=fullfile(here,'frequency','deadtime_v1');end
assert(~strcmpi(char(java.io.File(sourceFolder).getCanonicalPath),char(java.io.File(outputFolder).getCanonicalPath)),'派生结果不能写进原实验文件夹。');
% Also reject nested destinations inside the sealed experiment.
src=char(java.io.File(sourceFolder).getCanonicalPath);dst=char(java.io.File(outputFolder).getCanonicalPath);
assert(~startsWith(lower([dst filesep]),lower([src filesep])),'派生结果不能覆盖原实验。');
record=pmsm_experiment_verify(sourceFolder);plan=jsondecode(fileread(fullfile(sourceFolder,'plan.json')));
assert(strcmp(plan.scenario.id,'low_speed_compensation')&&numel(plan.cases)==3,'需要三组同桥同网格的补偿实验。');
window=[plan.duration_s-.08 plan.duration_s];analyses=cell(1,3);labels={plan.cases.label};
for k=1:3
 data=load(fullfile(sourceFolder,[plan.cases(k).id '.mat']),'signals');s=data.signals;
 assert(isequal(s.obs_current_fast.Time,s.log_theta_true.Time),'电流与真实角度记录必须同拍。');
 analyses{k}=pmsm_current_spectrum(s.obs_current_fast.Time,teach_values(s.obs_current_fast),teach_values(s.log_theta_true),window,19);
end
assert(max(cellfun(@(a)a.fe_Hz,analyses))-min(cellfun(@(a)a.fe_Hz,analyses))<.01,'三组电频率差异过大。');
if ~isfolder(outputFolder),mkdir(outputFolder);end
save(fullfile(outputFolder,'analysis.mat'),'analyses','labels','window','-v7.3');
f=plot_pmsm_spectrum(analyses,labels,'off');guard=onCleanup(@()close(f));
exportgraphics(f,fullfile(outputFolder,'spectrum.png'),'Resolution',140);savefig(f,fullfile(outputFolder,'spectrum.fig'));clear guard;
rows=cell(9,7);summaries=cell(1,3);
for k=1:3
 a=analyses{k};summaries{k}=rmfield(a,{'frequency_Hz','fft_peak_A','harmonic_peak_A','harmonic_percent','display_frequency_Hz','display_fft_peak_A'});
 for phase=1:3
  rows((k-1)*3+phase,:)={plan.cases(k).id,char('A'+phase-1),a.harmonic_peak_A(1,phase), ...
   a.harmonic_percent(5,phase),a.harmonic_percent(7,phase),a.low_order_ratio_percent(phase),a.fe_Hz};
 end
end
writetable(cell2table(rows,'VariableNames',{'case_id','phase','fundamental_peak_A','h5_percent','h7_percent','h2_to_h19_ratio_percent','fe_Hz'}),fullfile(outputFolder,'harmonics.csv'),'Encoding','UTF-8');
sources={'pmsm_current_spectrum.m','plot_pmsm_spectrum.m','export_pmsm_deadtime_spectrum.m'};
hashes=cellfun(@(p)teach_hash(fullfile(here,p)),sources,'UniformOutput',false);
artifacts={'analysis.mat','spectrum.png','spectrum.fig','harmonics.csv'};
artifactHashes=cellfun(@(p)teach_hash(fullfile(outputFolder,p)),artifacts,'UniformOutput',false);
result=struct('schema',1,'kind','deadtime_current_spectrum','source_run_id',record.id, ...
 'source_run_folder',sourceFolder,'source_record_sha256',teach_hash(fullfile(sourceFolder,'record.json')), ...
 'model_sha256',record.model_sha256,'window_s',window,'labels',{labels},'cases',{summaries}, ...
 'source_files',struct('path',sources,'sha256',hashes),'files',struct('path',artifacts,'sha256',artifactHashes));
teach_writejson(fullfile(outputFolder,'manifest.json'),result);pmsm_experiment_verify(sourceFolder);
fprintf('DEADTIME_SPECTRUM_READY %s\n',outputFolder);
end
