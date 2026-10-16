function result=test_deadtime_components(h)
if nargin<1,h=62.5e-9;end
Ts=50e-6;td=.5e-6;N=round(Ts/h);t=(0:10*N-1)'*h;
cfg=[1 h td];blank=zeros(numel(t),3);g=zeros(numel(t),6);raw=g;D=[.3 .5 .7];
clear gate_deadtime;
for k=1:numel(t)
 phase=mod(k-1,N);hi=double(phase<D*N/2 | phase>=N-D*N/2);
 r=zeros(1,6);r(1:2:5)=hi;r(2:2:6)=1-hi;
 [g(k,:),blank(k,:)]=gate_deadtime(t(k),r,cfg);raw(k,:)=r;
end
assert(all(g(:,1:2:5)+g(:,2:2:6)<=1,'all'));
for k=1:6
 rise=find(diff([0;raw(:,k)])>0);actual=find(diff([0;g(:,k)])>0);
 assert(isequal(actual,rise+round(td/h)));fall=find(diff(raw(:,k))<0)+1;assert(all(g(fall,k)==0));
end
result.rising_delay_ns=td*1e9;result.no_shootthrough=true;
% A short requested high pulse must vanish, and its canceled edge never fire.
clear gate_deadtime;short=zeros(30,6);
for k=1:30
 r=[0 1 0 1 0 1];if k>=12&&k<=13,r(1:2)=[1 0];end
 short(k,:)=gate_deadtime((k-1)*h,r,cfg);
end
assert(all(short(:,1)==0));result.short_pulse_suppressed=true;

state=[3 1/sqrt(3) 0 0];bridge=[5 .00565685424949238 .01 0 .01 .7];Vdc=24;
ideal=zeros(numel(t),3);actual=ideal;opposite=ideal;
for k=1:numel(t)
 ideal(k,:)=bridge_freewheel(raw(k,:),state,Vdc,bridge);
 actual(k,:)=bridge_freewheel(g(k,:),state,Vdc,bridge);
 opposite(k,:)=bridge_freewheel(g(k,:),-state,Vdc,bridge);
end
keep=(0:numel(t)-1)'>=N;expected=-Vdc*td/Ts*([1 -1 -1]-mean([1 -1 -1]));
err=mean(actual(keep,:)-ideal(keep,:),1);
assert(max(abs(err-expected))<1e-10,'Mean error %s expected %s',mat2str(err,12),mat2str(expected,12));
assert(max(abs(mean(opposite(keep,:)-ideal(keep,:),1)+expected))<1e-10);
result.mean_phase_error_V=err;
[v,diag]=bridge_freewheel(zeros(1,6),state,Vdc,bridge);
assert(isequal(diag(1:3),[-1 1 1])&&sum(v.*diag(7:9))<0);result.freewheel_passive=true;
[v,~]=bridge_freewheel(zeros(1,6),[0 0 100 0],Vdc,bridge);
e=-500*bridge(2)*sin([0 -2*pi/3 2*pi/3]);assert(max(abs(v-e))<1e-12);result.zero_current_open_emf=true;

clear deadtime_comp;[dq,c]=deadtime_comp([3 -1 -2],0,Vdc,[1 td Ts .05]);
assert(max(abs(c(1:3)+expected))<1e-12&&max(abs(dq-[.32 0]))<1e-12);
[~,held]=deadtime_comp([.01 -.01 0],0,Vdc,[1 td Ts .05]);assert(isequal(c(6:8),held(6:8)));
[~,flipped]=deadtime_comp([-3 1 2],0,Vdc,[1 td Ts .05]);assert(isequal(flipped(6:8),[-1 1 1]));
result.measured_polarity_hysteresis=true;
% Independent fixed-current PWM integration validates compensation gain/sign.
clear gate_deadtime;corrected=zeros(numel(t),3);D2=D+td/Ts*[1 -1 -1];
for k=1:numel(t)
 phase=mod(k-1,N);hi=double(phase<round(D2*N/2) | phase>=N-round(D2*N/2));
 r=zeros(1,6);r(1:2:5)=hi;r(2:2:6)=1-hi;
 gates=gate_deadtime(t(k),r,cfg);corrected(k,:)=bridge_freewheel(gates,state,Vdc,bridge);
end
result.compensated_average_error_V=mean(corrected(keep,:)-ideal(keep,:),1);
assert(max(abs(result.compensated_average_error_V))<1e-10);
result.all_passed=true;fprintf('DEADTIME_COMPONENTS_PASS\n');
end
