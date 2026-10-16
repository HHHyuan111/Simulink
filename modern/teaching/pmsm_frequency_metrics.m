function m=pmsm_frequency_metrics(f,T,L,valid)
% Bracketed estimates only. No extrapolation or inferred infinite margins.
f=f(:);T=T(:);L=L(:);valid=logical(valid(:));assert(numel(f)==numel(T)&&numel(f)==numel(L)&&numel(f)==numel(valid)&&all(diff(f)>0));
m=struct('bandwidth_Hz',[],'gain_crossing_Hz',[],'phase_margin_deg',[],...
 'bandwidth_status','扫频未可靠覆盖-3dB交点','margin_status','扫频未可靠覆盖0dB交点',...
 'reference_gain','0dB tracking at DC; first sweep point must be within 0.25dB',...
 'boundary','仅零速d轴小信号条件下的离散扫频估计；不是全工况稳定性保证');
mag=20*log10(abs(T));lg=20*log10(abs(L));lp=unwrap(angle(L))*180/pi;
if valid(1)&&abs(mag(1))<.25
 k=find(valid(1:end-1)&valid(2:end)&mag(1:end-1)>-3&mag(2:end)<=-3,1);
 if ~isempty(k),m.bandwidth_Hz=crossing(f,mag,k,-3);m.bandwidth_status='已测点之间对数频率插值';end
end
for k=1:numel(f)-1
 if valid(k)&&valid(k+1)&&lg(k)*lg(k+1)<=0&&lg(k)~=lg(k+1)
  fc=crossing(f,lg,k,0);a=(log(fc)-log(f(k)))/(log(f(k+1))-log(f(k)));
  if isempty(m.gain_crossing_Hz)||all(abs(log(fc./m.gain_crossing_Hz))>1e-12)
   m.gain_crossing_Hz(end+1)=fc;m.phase_margin_deg(end+1)=180+lp(k)+a*(lp(k+1)-lp(k));
  end
 end
end
if ~isempty(m.phase_margin_deg),m.margin_status='反馈/误差估计返回比；已测点之间插值；仅经典局部裕度';end
end
function value=crossing(f,g,k,target)
alpha=(target-g(k))/(g(k+1)-g(k));value=exp(log(f(k))+alpha*(log(f(k+1))-log(f(k))));
end
