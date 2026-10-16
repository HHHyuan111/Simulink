function report=validate_pmsm_noise_spectrum
here=fileparts(mfilename('fullpath'));root=fileparts(here);addpath(here);
fs=20000;t=(0:32767)'/fs;x=sqrt(2)*sin(2*pi*1250*t);
a=pmsm_noise_psd(t,x,x,[0 numel(t)/fs],256);
assert(abs(a.psd_integral_rms_A(1)-1)<1e-10&&max(abs(a.input_psd_A2_per_Hz-a.output_psd_A2_per_Hz))<1e-14);
assert(a.parseval_max_error_A2<1e-12&&abs(a.bin_width_Hz-78.125)<1e-8);
assert(max(abs(a.display_input_psd_A2_per_Hz(1:4:end,:)-a.input_psd_A2_per_Hz),[],'all')<1e-10);
assert(abs(sum(a.display_input_psd_A2_per_Hz)*a.fs_Hz/(4*a.segment_length)-1)<1e-10,'补零PSD面积错误。');
stream=RandStream('mt19937ar','Seed',9123);noise=.02*randn(stream,numel(t),3);alpha=exp(-2*pi*1500/fs);
y=filter(1-alpha,[1 -alpha],noise);b=pmsm_noise_psd(t,noise,y,[.1 numel(t)/fs],256);
theory=sqrt((1-alpha)/(1+alpha));assert(max(abs(b.time_ac_rms_A(2,:)./b.time_ac_rms_A(1,:)/theory-1))<.025);
H=(1-alpha)./(1-alpha*exp(-1i*2*pi*b.frequency_Hz/fs));
assert(max(abs(b.h1_estimate(2:end-1,:)-H(2:end-1)),[],'all')<.03,'H1估计方向或归一化错误。');
invalid={@()pmsm_noise_psd(t,noise,y,[0 .01],256), ...
 @()pmsm_noise_psd(t,noise,y,[0 .08],255), ...
 @()pmsm_noise_psd(t+[0;1e-6*ones(numel(t)-1,1)],noise,y,[0 .08],256)};
for k=1:numel(invalid),rejected=false;try,invalid{k}();catch,rejected=true;end;assert(rejected);end
summary=jsondecode(fileread(fullfile(here,'experiments','examples','noise_filter','summary.json')));
source=fullfile(here,'experiments','runs',summary.source_run_id);before=teach_hash(fullfile(source,'record.json'));
modelHash=teach_hash(fullfile(root,'PMSM_FOC_R2026a.slx'));folder=fullfile(here,'frequency','noise_v1');
r=export_pmsm_noise_spectrum(source,folder);first=load(fullfile(folder,'analysis.mat'));
repeat=fullfile(root,'.build','noise_spectrum_repeat');export_pmsm_noise_spectrum(source,repeat);
second=load(fullfile(repeat,'analysis.mat'));assert(isequaln(first,second),'噪声频谱不能逐点复现。');
assert(strcmp(before,teach_hash(fullfile(source,'record.json')))&&strcmp(modelHash,teach_hash(fullfile(root,'PMSM_FOC_R2026a.slx'))));
pmsm_experiment_verify(source);
report=struct('passed',true,'matlab_version',version,'known_tone_psd_area',true,'parseval_check',true, ...
 'white_noise_ratio_and_H1',true,'invalid_inputs_rejected',numel(invalid),'repeat_exact',true, ...
 'source_run_id',r.source_run_id,'source_record_sha256',before,'model_sha256',modelHash, ...
 'derived_manifest_sha256',teach_hash(fullfile(folder,'manifest.json')));
teach_writejson(fullfile(here,'frequency','noise_spectrum_validation.json'),report);disp('NOISE_SPECTRUM_VALIDATED');
end
