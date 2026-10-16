function report=validate_pmsm_spectrum
here=fileparts(mfilename('fullpath'));root=fileparts(here);addpath(here);
t=(0:79999)'*1e-6;theta=2*pi*50*t;phase=[0 -2*pi/3 2*pi/3];
x=.3+2*sin(theta+phase)+.2*sin(5*(theta+phase))+.1*sin(7*(theta+phase));
a=pmsm_current_spectrum(t,x,theta,[0 .08],19);
assert(a.sample_count==80000&&abs(a.bin_width_Hz-12.5)<1e-8);
assert(max(abs(a.harmonic_peak_A(1,:)-2))<1e-10&&max(abs(a.harmonic_peak_A(5,:)-.2))<1e-10&&max(abs(a.harmonic_peak_A(7,:)-.1))<1e-10);
assert(max(abs(a.dc_A-.3))<1e-10&&max(abs(a.low_order_ratio_percent-100*sqrt(.05)/2))<1e-10);
[~,bin]=min(abs(a.frequency_Hz-50));assert(max(abs(a.fft_peak_A(bin,:)-2))<1e-9,'FFT幅值标定错误');
assert(max(abs(a.display_fft_peak_A(1:4:end,:)-a.fft_peak_A),[],'all')<1e-10,'补零显示改变了原频点幅值。');
assert(numel(a.display_frequency_Hz)==4*(numel(a.frequency_Hz)-1)+1);
offTheta=2*pi*52.3*t;off=2*sin(offTheta+phase)+.2*sin(5*(offTheta+phase));
b=pmsm_current_spectrum(t,off,offTheta,[0 .08],19);assert(max(abs(b.harmonic_peak_A(5,:)-.2))<1e-10,'非整频点回归错误');
invalid={@()pmsm_current_spectrum(t,x,theta,[0 .02],19), ...
 @()pmsm_current_spectrum(t+[zeros(100,1);1e-7*ones(numel(t)-100,1)],x,theta,[0 .08],19), ...
 @()pmsm_current_spectrum(t,x,2*pi*(40*t+125*t.^2),[0 .08],19), ...
 @()pmsm_current_spectrum(t,ones(size(x)),theta,[0 .08],19)};
for k=1:numel(invalid),rejected=false;try,invalid{k}();catch,rejected=true;end;assert(rejected);end
source=fullfile(here,'experiments','runs','20261013_133919_965_low_speed_compensation_c1e40d81');
before=teach_hash(fullfile(source,'record.json'));modelHash=teach_hash(fullfile(root,'PMSM_FOC_R2026a.slx'));
folder=fullfile(here,'frequency','deadtime_v1');r=export_pmsm_deadtime_spectrum(source,folder);
first=load(fullfile(folder,'analysis.mat'),'analyses');
repeat=fullfile(root,'.build','spectrum_repeat');export_pmsm_deadtime_spectrum(source,repeat);
second=load(fullfile(repeat,'analysis.mat'),'analyses');assert(isequaln(first.analyses,second.analyses),'频谱分析不能逐点复现。');
assert(strcmp(before,teach_hash(fullfile(source,'record.json')))&&strcmp(modelHash,teach_hash(fullfile(root,'PMSM_FOC_R2026a.slx'))));
pmsm_experiment_verify(source);
report=struct('passed',true,'matlab_version',version,'synthetic_amplitude_and_ratio',true, ...
 'off_bin_regression',true,'invalid_inputs_rejected',numel(invalid),'archived_source_verified',true, ...
 'repeat_exact',true,'model_sha256',modelHash,'source_record_sha256',before, ...
 'source_run_id',r.source_run_id,'window_s',r.window_s,'derived_manifest_sha256',teach_hash(fullfile(folder,'manifest.json')));
teach_writejson(fullfile(here,'frequency','spectrum_validation.json'),report);disp('SPECTRUM_VALIDATED');
end
