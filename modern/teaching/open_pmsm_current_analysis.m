function [fig,analysis]=open_pmsm_current_analysis(out,window)
% Native MATLAB axes from the latest real output, never a hidden archive.
source='传入的仿真输出';
if nargin<1
 assert(evalin('base','exist(''out'',''var'')==1'),'请先在原模型运行一次，生成out，或显式传入SimulationOutput。');
 out=evalin('base','out');source='工作区最近一次out';
end
assert(isa(out,'Simulink.SimulationOutput'),'输入须为Simulink.SimulationOutput。');
x=out.get('log_iabc_true');assert(isa(x,'timeseries'),'输出缺少真实三相电流log_iabc_true。');
t=double(x.Time(:));current=teach_values(x);
assert(size(current,2)==3,'真实三相电流应包含3个通道。');
assert(numel(t)>=256,'当前输出不足256个样本，请延长仿真时间后重新运行。');
assert(all(isfinite(t))&&all(isfinite(current),'all')&&all(diff(t)>0));
if nargin<2,window=[max(t(1),t(end)-.02) t(end)];end
validateattributes(window,{'double'},{'vector','numel',2,'finite'});assert(window(1)<window(2)&&window(1)>=t(1)&&window(2)<=t(end));
keep=t>=window(1)&t<=window(2);t=t(keep);current=current(keep,:);N=numel(t);assert(N>=256,'分析区间至少需要256个原始样本。');
dt=median(diff(t));assert(max(abs(diff(t)-dt))<=max(1e-12,dt*1e-6),'FFT要求等间隔原始样本；本入口不插值。');
fs=1/dt;w=.5-.5*cos(2*pi*(0:N-1)'/N);signal=current-mean(current,1);
transform=fft(signal.*w);n=floor(N/2)+1;frequency=(0:n-1)'*fs/N;
amplitude=abs(transform(1:n,:))/sum(w);psd=abs(transform(1:n,:)).^2/(fs*sum(w.^2));
factor=2*ones(n,1);factor(1)=1;if mod(N,2)==0,factor(end)=1;end
amplitude=amplitude.*factor;psd=psd.*factor;
analysis=struct('source',source,'signal','log_iabc_true','actual_window_s',[t(1) t(end)],'sample_count',N,...
 'sample_rate_Hz',fs,'bin_spacing_Hz',fs/N,'window','periodic Hann','removed_mean_A',mean(current,1),...
 'frequency_Hz',frequency,'amplitude_peak_A',amplitude,'psd_A2_per_Hz',psd,...
 'boundary','Windowed spectrum of this output; no automatic steady-state/THD/bandwidth claim; no interpolation or FFT padding.');
fig=figure('Name','电流时域与频谱','NumberTitle','off','Color','white','Units','pixels',...
 'Position',[80 60 1120 800],'UserData',rmfield(analysis,{'frequency_Hz','amplitude_peak_A','psd_A2_per_Hz'}));
layout=tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');colors=[0 .447 .741;.84 .15 .16;.5 .5 .5];
ax=nexttile(layout,1);draw(ax,t*1e3,current,colors);title(ax,'三相电流');xlabel(ax,'时间 [ms]');ylabel(ax,'电流 [A]');
ax=nexttile(layout,2);draw(ax,frequency,amplitude,colors);title(ax,'低频电流频谱');xlabel(ax,'频率 [Hz]');ylabel(ax,'幅值 [A]');xlim(ax,[0 min(2000,fs/2)]);
ax=nexttile(layout,3);draw(ax,frequency,amplitude,colors);title(ax,'电流频谱');xlabel(ax,'频率 [Hz]');ylabel(ax,'幅值 [A]');xlim(ax,[0 min(40000,fs/2)]);
ax=nexttile(layout,4);draw(ax,frequency,10*log10(max(psd,realmin)),colors);title(ax,'电流功率谱密度');xlabel(ax,'频率 [Hz]');ylabel(ax,'PSD [dB(A²/Hz)]');xlim(ax,[0 min(40000,fs/2)]);
end
function draw(ax,x,y,colors)
hold(ax,'on');for k=1:3,line=plot(ax,x,y(:,k),'Color',colors(k,:),'LineWidth',1.3,'DisplayName',char('A'+k-1));if k==3,line.LineStyle='--';end,end
grid(ax,'on');ax.Color='white';ax.XColor='black';ax.YColor='black';ax.FontSize=11;legend(ax,'show','Location','best');
end
