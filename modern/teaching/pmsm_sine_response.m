function r=pmsm_sine_response(t,signals,f)
% Joint synchronous least-squares fit: each column has the same exact grid.
validateattributes(t,{'double'},{'column','finite','increasing'});
assert(size(signals,1)==numel(t)&&size(signals,2)>=3&&all(isfinite(signals),'all')&&f>0);
dt=median(diff(t));assert(max(abs(diff(t)-dt))<max(1e-12,dt*1e-6));assert(f<.5/dt);
phase=2*pi*f*(t-t(1));X=[sin(phase) cos(phase) ones(size(t))];coef=X\signals;
phasor=coef(2,:)-1i*coef(1,:);amp=abs(phasor);assert(amp(1)>1e-8);
residual=sqrt(mean((signals-X*coef).^2,1))./max(amp/sqrt(2),1e-10);
half=floor(numel(t)/2);parts=zeros(2,size(signals,2));
for k=1:2,if k==1,ix=1:half;else,ix=half+1:numel(t);end;h=X(ix,:)\signals(ix,:);parts(k,:)=h(2,:)-1i*h(1,:);end
r=struct('phasor',phasor,'amplitude',amp,'relative_residual',residual,...
 'relative_half_drift',abs(parts(2,:)-parts(1,:))./max(amp,1e-10),...
 'T_true',phasor(2)/phasor(1),'T_feedback',(phasor(1)-phasor(3))/phasor(1),...
 'loop',NaN,'reference_identity_error',NaN);
% columns: injected reference, true d current, exact PI error, feedback.
if size(signals,2)>=4
 r.reference_identity_error=max(abs(signals(:,1)-signals(:,3)-signals(:,4)));
 if amp(3)>1e-6,r.loop=phasor(4)/phasor(3);end
end
end
