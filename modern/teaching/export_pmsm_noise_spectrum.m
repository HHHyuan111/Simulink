function result=export_pmsm_noise_spectrum(sourceFolder,outputFolder)
% Read sealed cases and isolate noise; no new simulation or control change.
here=fileparts(mfilename('fullpath'));
if nargin<1||isempty(sourceFolder)
 summary=jsondecode(fileread(fullfile(here,'experiments','examples','noise_filter','summary.json')));
 sourceFolder=fullfile(here,'experiments','runs',summary.source_run_id);
end
if nargin<2,outputFolder=fullfile(here,'frequency','noise_v1');end
src=char(java.io.File(sourceFolder).getCanonicalPath);dst=char(java.io.File(outputFolder).getCanonicalPath);
assert(~startsWith(lower([dst filesep]),lower([src filesep])),'派生结果不能写入原实验。');
record=pmsm_experiment_verify(sourceFolder);plan=jsondecode(fileread(fullfile(sourceFolder,'plan.json')));
assert(strcmp(plan.scenario.id,'noise_filter')&&numel(plan.cases)==3);
outputs=cell(1,3);
for k=1:3,d=load(fullfile(sourceFolder,[plan.cases(k).id '.mat']),'signals');outputs{k}=d.signals;end
[decomposition,trace]=pmsm_noise_filter_analysis(outputs,plan);
window=[plan.duration_s-.08 plan.duration_s];
a=pmsm_noise_psd(trace.time_s,trace.noise_component{2},trace.noise_component{3},window,256);
alpha=decomposition.alpha;H=(1-alpha)./(1-alpha*exp(-1i*2*pi*a.frequency_Hz/a.fs_Hz));
theoryRatio=sqrt((1-alpha)/(1+alpha));observedRatio=a.time_ac_rms_A(2,:)./a.time_ac_rms_A(1,:);
assert(max(abs(observedRatio/theoryRatio-1))<.15,'有限窗口噪声衰减与当前一阶滤波不符。');
if ~isfolder(outputFolder),mkdir(outputFolder);end
save(fullfile(outputFolder,'analysis.mat'),'a','H','alpha','decomposition','-v7.3');
f=plot_pmsm_noise_spectrum(a,H,'off');guard=onCleanup(@()close(f));
exportgraphics(f,fullfile(outputFolder,'spectrum.png'),'Resolution',140);savefig(f,fullfile(outputFolder,'spectrum.fig'));clear guard;
rows=cell(3,8);
for phase=1:3
 rows(phase,:)={char('A'+phase-1),a.time_rms_A(1,phase),a.time_rms_A(2,phase), ...
  a.time_ac_rms_A(1,phase),a.time_ac_rms_A(2,phase),a.psd_integral_rms_A(1,phase),a.psd_integral_rms_A(2,phase),observedRatio(phase)};
end
writetable(cell2table(rows,'VariableNames',{'phase','input_rms_A','output_rms_A','input_ac_rms_A','output_ac_rms_A','input_psd_rms_A','output_psd_rms_A','observed_ac_rms_ratio'}),fullfile(outputFolder,'noise_metrics.csv'),'Encoding','UTF-8');
sources={'pmsm_noise_psd.m','plot_pmsm_noise_spectrum.m','export_pmsm_noise_spectrum.m','pmsm_noise_filter_analysis.m','pmsm_plot_style.m'};
hashes=cellfun(@(p)teach_hash(fullfile(here,p)),sources,'UniformOutput',false);
artifacts={'analysis.mat','spectrum.png','spectrum.fig','noise_metrics.csv'};
artifactHashes=cellfun(@(p)teach_hash(fullfile(outputFolder,p)),artifacts,'UniformOutput',false);
summary=rmfield(a,{'frequency_Hz','input_psd_A2_per_Hz','output_psd_A2_per_Hz','h1_estimate','input_valid_bins', ...
 'display_frequency_Hz','display_input_psd_A2_per_Hz','display_output_psd_A2_per_Hz','display_h1_estimate','display_input_valid_bins'});
result=struct('schema',1,'kind','noise_filter_spectrum','source_run_id',record.id, ...
 'source_run_folder',sourceFolder,'source_record_sha256',teach_hash(fullfile(sourceFolder,'record.json')), ...
 'model_sha256',record.model_sha256,'analysis',summary,'filter_alpha',alpha, ...
 'theoretical_white_noise_rms_ratio',theoryRatio,'observed_ac_rms_ratio',observedRatio, ...
 'nominal_electrical_frequency_Hz',decomposition.nominal_electrical_frequency_Hz, ...
 'nominal_filter_gain_dB',decomposition.nominal_gain_dB,'nominal_filter_phase_deg',decomposition.nominal_phase_deg, ...
 'source_files',struct('path',sources,'sha256',hashes),'files',struct('path',artifacts,'sha256',artifactHashes));
teach_writejson(fullfile(outputFolder,'manifest.json'),result);pmsm_experiment_verify(sourceFolder);
fprintf('NOISE_SPECTRUM_READY %s\n',outputFolder);
end
