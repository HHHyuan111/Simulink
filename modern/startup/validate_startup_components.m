function report=validate_startup_components
% Component tests deliberately exercise stop priorities and queued writes.
here=fileparts(mfilename('fullpath'));root=fileparts(here);addpath(fullfile(root,'timing'),fullfile(root,'teaching'));
dt=50e-6;offset=28.875e-6;times=(0:49)'*dt+offset;
for test=1:3
 clear startup_step;
 cfg=[1 0 .001 .0015 double(test==2) -1 -1];if test==3,cfg(6:7)=[.0006 .0008];end
 trace=zeros(numel(times),8);previous=0;
 for k=1:numel(times)
  speed=zeros(1,7);speed(4)=double(k>2);adc=zeros(1,15);adc(6)=1;adc(14)=double(mod(k,2)==0);
  if test~=2||previous==2,adc(7:9)=1;end
  trace(k,:)=startup_step(times(k),speed,adc,cfg);previous=trace(k,1);
 end
 assert(all(ismember(0:4,unique(trace(:,1)))));
 assert(all(trace(times>=.001&times<.0015,1)==0));
 assert(all(trace(trace(:,1)<3,2)==0)&&all(trace(trace(:,1)<4,3)==0));
 for edge=find(diff(trace(:,1)==4)==1)'+1,assert(mod(edge,2)==0);end
 if test==3,assert(all(trace(times>=.0006&times<.0015,1)==0));end
end
% Disabled path must be numerically identical to the archived PWM routine.
h=62.5e-9;cfg=[1 h dt 24.375e-6 1.1875e-6 1.5e-6 0 5e-6 0 4000];
clear startup_pwm timing_pwm;
for tick=0:2400
 t=tick*h;r=dt/2*[.2 .5 .8]+sin(t*1e5)*1e-6;
 [a,b]=timing_pwm(t,r,cfg);[c,d]=startup_pwm(t,r,cfg,[0 1 1 1]);assert(isequal(a,c)&&isequal(b,d));
end
% Clear a pending non-neutral write exactly on an update boundary.
clear startup_pwm;
startup_pwm(0,dt/8*ones(1,3),cfg,[1 1 1 1]);
[~,written]=startup_pwm(33.875e-6,dt/8*ones(1,3),cfg,[1 1 1 1]);assert(written(8)==1);
[value,cleared]=startup_pwm(50e-6,dt/8*ones(1,3),cfg,[1 0 0 0]);
assert(all(value==dt/4)&&all(cleared(4:9)==0));
[value,~]=startup_pwm(75e-6,dt/8*ones(1,3),cfg,[1 0 0 1]);assert(all(value==dt/4));
assert(isequal(startup_gate(ones(1,6),[1 0 0 0]),zeros(1,6)));
assert(isequal(startup_gate(zeros(1,6),[1 0 0 1]),[0 1 0 1 0 1]));
assert(isequal(startup_gate(1:6,[0 0 0 0]),1:6));
report=struct('passed',true,'state_and_priority_cases',3,'legacy_pwm_exact_ticks',2401,...
 'queued_write_cancelled_at_update',true,'gate_modes_checked',true);
teach_writejson(fullfile(here,'component_validation.json'),report);fprintf('STARTUP_COMPONENTS_VALIDATED\n');
end
