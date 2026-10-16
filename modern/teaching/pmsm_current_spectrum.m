function r=pmsm_current_spectrum(t,current,theta,window,maxOrder)
% Native MATLAB FFT plus rotor-synchronous harmonic regression, no resampling.
if nargin<5,maxOrder=19;end
t=t(:);theta=unwrap(theta(:));
assert(numel(t)==size(current,1)&&size(current,2)==3&&numel(theta)==numel(t),'记录尺寸不符。');
assert(all(isfinite([t theta current]),'all')&&all(diff(t)>0),'记录必须有限且时间递增。');
assert(isscalar(maxOrder)&&maxOrder>=2&&maxOrder==fix(maxOrder),'谐波上限必须为整数。');
dt=median(diff(t));assert(max(abs(diff(t)-dt))<dt*1e-6,'FFT需要均匀采样。');
assert(numel(window)==2&&window(2)>window(1),'时间窗口无效。');
% Select by integer sample ticks, not floating-point endpoint comparisons.
ticks=round((t-t(1))/dt);lo=round((window(1)-t(1))/dt);hi=round((window(2)-t(1))/dt);
assert(abs(t(1)+lo*dt-window(1))<dt*1e-5&&abs(t(1)+hi*dt-window(2))<dt*1e-5,'窗口必须落在采样网格。');
ix=ticks>=lo&ticks<hi;assert(sum(ix)==hi-lo&&sum(ix)>=80,'窗口超出记录或样本不足。');
t=t(ix);x=current(ix,:);th=theta(ix);N=numel(t);fs=1/dt;
assert(all(diff(th)>0),'本分析要求正向单调电角度。');
fe=(th(end)-th(1))/(2*pi*(t(end)-t(1)));cycles=fe*N*dt;
assert(cycles>=3-1e-6,'至少需要三个电周期；请延长记录窗口。');
assert(maxOrder*fe<fs/2,'谐波上限超出奈奎斯特频率。');
instant=diff(th)./diff(t)/(2*pi);speedSpan=(max(instant)-min(instant))/fe;
assert(speedSpan<.01,'窗口转速变化超过1%，不适合当前稳态频谱比较。');
design=ones(N,2*maxOrder+1);
for h=1:maxOrder,design(:,2*h)=sin(h*th);design(:,2*h+1)=cos(h*th);end
coeff=design\x;amp=hypot(coeff(2:2:end,:),coeff(3:2:end,:));
assert(all(amp(1,:)>1e-6),'基波过小，不能归一化谐波。');
halves=zeros(2,3);
for k=1:2
 if k==1,j=1:floor(N/2);else,j=floor(N/2)+1:N;end
 b=[ones(numel(j),1) sin(th(j)) cos(th(j))]\x(j,:);halves(k,:)=hypot(b(2,:),b(3,:));
end
ampDrift=abs(diff(halves))./mean(halves,1);assert(all(ampDrift<.05),'窗口电流幅值漂移超过5%。');
w=.5-.5*cos(2*pi*(0:N-1)'/N);dc=mean(x,1);Y=fft((x-dc).*w);
count=floor(N/2)+1;peak=2*abs(Y(1:count,:))/sum(w);peak(1,:)=peak(1,:)/2;
if mod(N,2)==0,peak(end,:)=peak(end,:)/2;end
% Denser DFT evaluation for display only; original bins and metrics stay intact.
displayN=4*N;displayY=fft((x-dc).*w,displayN);displayCount=floor(displayN/2)+1;
displayPeak=2*abs(displayY(1:displayCount,:))/sum(w);displayPeak(1,:)=displayPeak(1,:)/2;
displayPeak(end,:)=displayPeak(end,:)/2;
r=struct('schema',1,'window_s',window,'sample_times_s',[t(1) t(end)],'sample_count',N, ...
 'fs_Hz',fs,'bin_width_Hz',fs/N,'window','periodic Hann','coherent_gain',mean(w), ...
 'enbw_Hz',fs*sum(w.^2)/sum(w)^2,'fe_Hz',fe,'electrical_cycles',cycles, ...
 'relative_speed_span',speedSpan,'relative_amplitude_drift_ABC',ampDrift, ...
 'frequency_Hz',(0:count-1)'*fs/N,'fft_peak_A',peak,'dc_A',coeff(1,:), ...
 'display_frequency_Hz',(0:displayCount-1)'*fs/displayN,'display_fft_peak_A',displayPeak, ...
 'display_zero_padding_factor',4, ...
 'harmonic_orders',(1:maxOrder)','harmonic_peak_A',amp,'harmonic_percent',100*amp./amp(1,:), ...
 'low_order_ratio_percent',100*sqrt(sum(amp(2:end,:).^2,1))./amp(1,:), ...
 'definition','FFT: DC removed, periodic Hann, single-sided peak amplitude. Harmonics: simultaneous least-squares fit of DC and orders 1..H to recorded true electrical angle. Ratio excludes switching and asynchronous components; not full-band THD.');
end
