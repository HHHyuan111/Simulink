function r=pmsm_noise_psd(t,x,y,window,segmentLength)
% Welch PSD and H1 from paired noise components, using only native fft.
if nargin<5,segmentLength=256;end
t=t(:);assert(numel(t)==size(x,1)&&isequal(size(x),size(y)),'成对噪声记录尺寸不符。');
assert(all(isfinite([t x y]),'all')&&all(diff(t)>0),'输入必须有限且时间递增。');
dt=median(diff(t));assert(max(abs(diff(t)-dt))<dt*1e-6,'PSD需要均匀采样。');
L=segmentLength;assert(isscalar(L)&&L>=16&&L==fix(L)&&mod(L,2)==0,'分段长度应为不小于16的偶数。');
assert(numel(window)==2&&all(isfinite(window))&&window(2)>window(1),'时间窗口无效。');
lo=round((window(1)-t(1))/dt);hi=round((window(2)-t(1))/dt);ticks=round((t-t(1))/dt);
assert(max(abs(t(1)+[lo hi]*dt-window))<dt*1e-5,'窗口必须落在采样网格。');
ix=ticks>=lo&ticks<hi;assert(sum(ix)==hi-lo&&sum(ix)>=L+L/2,'至少需要两个重叠分段。');
x=x(ix,:);y=y(ix,:);N=size(x,1);means=[mean(x,1);mean(y,1)];rawRms=[sqrt(mean(x.^2,1));sqrt(mean(y.^2,1))];
x=x-means(1,:);y=y-means(2,:);w=.5-.5*cos(2*pi*(0:L-1)'/L);fs=1/dt;
starts=1:L/2:N-L+1;Sxx=zeros(L,size(x,2));Syy=Sxx;Syx=complex(Sxx);weighted=zeros(2,size(x,2));
displayN=4*L;Dxx=zeros(displayN,size(x,2));Dyy=Dxx;Dyx=complex(Dxx);
for first=starts
 j=first:first+L-1;X=fft(x(j,:).*w);Y=fft(y(j,:).*w);
 Sxx=Sxx+abs(X).^2;Syy=Syy+abs(Y).^2;Syx=Syx+Y.*conj(X);
 DX=fft(x(j,:).*w,displayN);DY=fft(y(j,:).*w,displayN);
 Dxx=Dxx+abs(DX).^2;Dyy=Dyy+abs(DY).^2;Dyx=Dyx+DY.*conj(DX);
 weighted=weighted+[sum((x(j,:).*w).^2,1);sum((y(j,:).*w).^2,1)]/sum(w.^2);
end
normalizer=numel(starts)*fs*sum(w.^2);Sxx=Sxx/normalizer;Syy=Syy/normalizer;Syx=Syx/normalizer;
bins=1:L/2+1;Pxx=Sxx(bins,:);Pyy=Syy(bins,:);Pxx(2:end-1,:)=2*Pxx(2:end-1,:);Pyy(2:end-1,:)=2*Pyy(2:end-1,:);
area=[sum(Pxx,1);sum(Pyy,1)]*fs/L;weighted=weighted/numel(starts);
Dxx=Dxx/normalizer;Dyy=Dyy/normalizer;Dyx=Dyx/normalizer;dbins=1:displayN/2+1;
DPxx=Dxx(dbins,:);DPyy=Dyy(dbins,:);DPxx(2:end-1,:)=2*DPxx(2:end-1,:);DPyy(2:end-1,:)=2*DPyy(2:end-1,:);
assert(max(abs(area-weighted),[],'all')<1e-10*max(1,max(weighted,[],'all')),'PSD面积不满足加窗Parseval核对。');
r=struct('schema',1,'window_s',window,'fs_Hz',fs,'sample_count',N,'segment_length',L, ...
 'segment_count',numel(starts),'overlap_samples',L/2,'window','periodic Hann', ...
 'bin_width_Hz',fs/L,'enbw_Hz',fs*sum(w.^2)/sum(w)^2,'frequency_Hz',(0:L/2)'*fs/L, ...
 'input_psd_A2_per_Hz',Pxx,'output_psd_A2_per_Hz',Pyy,'h1_estimate',Syx(bins,:)./max(Sxx(bins,:),realmin), ...
 'input_valid_bins',Sxx(bins,:)>max(Sxx(bins,:),[],1)*1e-10,'means_A',means,'time_rms_A',rawRms, ...
 'display_frequency_Hz',(0:displayN/2)'*fs/displayN,'display_input_psd_A2_per_Hz',DPxx, ...
 'display_output_psd_A2_per_Hz',DPyy,'display_h1_estimate',Dyx(dbins,:)./max(Dxx(dbins,:),realmin), ...
 'display_input_valid_bins',Dxx(dbins,:)>max(Dxx(dbins,:),[],1)*1e-10,'display_zero_padding_factor',4, ...
 'time_ac_rms_A',[sqrt(mean(x.^2,1));sqrt(mean(y.^2,1))],'psd_integral_rms_A',sqrt(area), ...
 'weighted_segment_power_A2',weighted,'parseval_max_error_A2',max(abs(area-weighted),[],'all'), ...
 'definition','Whole-window mean removed; periodic Hann, 50% overlap, one-sided Welch PSD in A^2/Hz. H1=Syx/Sxx on paired input/output noise. PSD integral equals averaged window-weighted segment power, not exactly unweighted finite-record RMS.');
end
