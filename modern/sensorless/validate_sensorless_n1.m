function record=validate_sensorless_n1
% Frozen-contract component tests. Never opens or changes the PMSM model.
here=fileparts(mfilename('fullpath'));addpath(here,fullfile(fileparts(here),'teaching'));
contract=jsondecode(fileread(fullfile(here,'contracts','acceptance_v1.json')));
plan=jsondecode(fileread(fullfile(here,'contracts','test_plan_v1.json')));
id=['N1_' char(datetime('now','TimeZone','Asia/Shanghai','Format','yyyyMMdd_HHmmss_SSS')) '_' char(java.util.UUID.randomUUID)];
folder=fullfile(here,'runs',id);mkdir(folder);
record=struct('schema',1,'node','N1','folder',folder,'status','running','model_loaded',false,...
 'matlab_version',version,'matlab_release',version('-release'),'source_files',struct('path',{},'sha256',{}),...
 'contract_sha256',teach_hash(fullfile(here,'contracts','acceptance_v1.json')),...
 'test_plan_sha256',teach_hash(fullfile(here,'contracts','test_plan_v1.json')));
for f=dir(fullfile(here,'*.m'))'
 record.source_files(end+1)=struct('path',f.name,'sha256',teach_hash(fullfile(here,f.name))); %#ok<AGROW>
end
mkdir(fullfile(folder,'source'));
for f=record.source_files(:)',copyfile(fullfile(here,f.path),fullfile(folder,'source',f.path));end
teach_writejson(fullfile(folder,'record.json'),record);
raw=struct;checks=struct('name',{},'passed',{});metrics=struct;
try
 assert(~bdIsLoaded('PMSM_FOC_R2026a'),'组件验收须使用独立MATLAB进程。');
 c=sensorless_parameters;teach_writejson(fullfile(folder,'effective_parameters.json'),c);
 [metrics.parameters,raw.parameters]=parameter_tests(c,contract);
 add('parameters',metrics.parameters.all_passed);
 [metrics.smo,raw.smo]=smo_tests(c,contract);
 add('smo_independent_oracle',metrics.smo.all_passed);
 [metrics.pll,raw.pll]=sensorless_n1_pll_tests(c,contract,plan);
 add('pll_72_cases',all([metrics.pll.passed]));
 [metrics.phase,raw.phase]=phase_tests(c,contract);
 add('emf_filter_phase',all([metrics.phase.passed]));
 [metrics.synthetic,raw.synthetic]=synthetic_tests(c,contract);
 add('synthetic_full_chain',all([metrics.synthetic.passed]));
 [metrics.state,raw.state]=state_tests(c);
 add('reset_missing_saturation',metrics.state.all_passed);
 save(fullfile(folder,'raw.mat'),'raw','-v7.3');
 record.raw_sha256=teach_hash(fullfile(folder,'raw.mat'));
 record.checks=checks;record.all_passed=all([checks.passed]);
 record.model_loaded=bdIsLoaded('PMSM_FOC_R2026a');assert(~record.model_loaded);
 for f=record.source_files(:)',assert(strcmp(f.sha256,teach_hash(fullfile(here,f.path))),'验收期间源码改变。');end
 if record.all_passed,record.status='passed';else,record.status='failed';end
 teach_writejson(fullfile(folder,'metrics.json'),metrics);
 teach_writejson(fullfile(folder,'record.json'),record);
 fprintf('N1_COMPONENT_STATUS=%s folder=%s\n',record.status,folder);
 assert(record.all_passed,'sensorless:N1Failed','N1必选检查失败，保留结果包。');
catch err
 record.status='failed';record.error=err.message;
 save(fullfile(folder,'raw.mat'),'raw','-v7.3');
 record.raw_sha256=teach_hash(fullfile(folder,'raw.mat'));
 teach_writejson(fullfile(folder,'metrics.json'),metrics);
 teach_writejson(fullfile(folder,'record.json'),record);rethrow(err);
end
 function add(name,passed)
  checks(end+1)=struct('name',name,'passed',logical(passed));
  fprintf('N1_CHECK %s=%d\n',name,passed);
 end
end

function [m,raw]=parameter_tests(c,a)
% Independent formulas, including augmented discrete PI phase-error matrix.
T=c.sample_s;R=c.R_hat;L=c.L_hat;wn=2*pi*c.pll_fn_hz;
actual=[c.a c.b c.g c.filter_r c.pll_Kp c.pll_Ki c.observer_pole c.emf_at_3000rpm_V];
expected=[exp(-R*T/L),(1-exp(-R*T/L))/R,c.Kslide_V/c.boundary_A,...
 exp(-2*pi*c.emf_filter_hz*T),2*c.pll_zeta*wn,wn^2,...
 exp(-R*T/L)/(1+((1-exp(-R*T/L))/R)*c.Kslide_V/c.boundary_A),c.flux_hat*c.pole_pairs*100*pi];
tol=a.correctness.parameter_absolute_tolerance+a.correctness.parameter_relative_tolerance*abs(expected);
inventory=jsondecode(fileread(fullfile(fileparts(mfilename('fullpath')),'baseline','n0_inventory.json')));
motor=inventory.motor_and_tasks;bad={struct('sample_s',0),struct('sample_s',20e-6),struct('R_hat',NaN),...
 struct('L_hat',-1),struct('pole_pairs',1.5),struct('emf_filter_hz',10000),...
 struct('pll_fn_hz',10000),struct('unknown',1),struct('pll_fn_hz',9000)};
rejected=false(size(bad));
for k=1:numel(bad),try,sensorless_parameters(motor,bad{k});catch,rejected(k)=true;end,end
motor.Lq=2*motor.Ld;saliency=false;try,sensorless_parameters(motor);catch,saliency=true;end
m=struct('all_passed',all(abs(actual-expected)<=tol)&&all(rejected)&&saliency,...
 'max_absolute_error',max(abs(actual-expected)),'invalid_cases_rejected',sum(rejected)+saliency,...
 'observer_pole',c.observer_pole,'pll_spectral_radius',c.pll_spectral_radius);
raw=struct('actual',actual,'expected',expected,'tolerance',tol,'rejected',rejected);
end

function [m,raw]=smo_tests(c,a)
stream=RandStream('mt19937ar','Seed',20261016);
maxres=0;maxerr=0;count=0;raw=zeros(0,8);
for gain=[12 14 16]
 for phi=[.1 .2 .4]
  q=c;q.Kslide_V=gain;q.boundary_A=phi;q.g=gain/phi;
  boundary=phi+q.b*gain;
  deltas=[0,1e-12,-1e-12,boundary,-boundary,boundary*(1-1e-9),boundary*(1+1e-9),...
   -boundary*(1-1e-9),-boundary*(1+1e-9),30*(rand(stream,1,41)-.5)];
  for delta=deltas
   current=[.7;-.2];previous=struct('i',[0;0],'z',[0;0]);voltage=(current+[delta;-delta])/q.b;
   [next,~]=sensorless_smo_step(previous,current,voltage,q,true,false);
   oracle=zeros(2,1);
   for axis=1:2
    d=delta;if axis==2,d=-d;end
    fun=@(s)s+q.b*q.Kslide_V*max(-1,min(1,s/q.boundary_A))-d;
    oracle(axis)=fzero(fun,[-abs(d)-q.b*q.Kslide_V-1,abs(d)+q.b*q.Kslide_V+1]);
   end
   residual=next.i-current;equation=residual+q.b*next.z-[delta;-delta];
   maxres=max(maxres,max(abs(equation)));maxerr=max(maxerr,max(abs(residual-oracle)));count=count+2;
   raw(end+1,:)=[gain phi delta residual' oracle' max(abs(equation))]; %#ok<AGROW>
  end
 end
end
% Multi-step state recurrence is independently solved at every sample.
previous=struct('i',zeros(2,1),'z',zeros(2,1));oracle_i=zeros(2,1);T=c.sample_s;
trace=zeros(2001,7);multistep=0;
for k=0:2000
 time=k*T;imeas=[2*cos(500*time);2*sin(500*time)];v=[8*cos(500*time+.7);8*sin(500*time+.7)];
 [previous,~]=sensorless_smo_step(previous,imeas,v,c,true,false);
 for axis=1:2
  ip=c.a*oracle_i(axis)+c.b*v(axis);fun=@(x)x+c.b*c.Kslide_V*max(-1,min(1,(x-imeas(axis))/c.boundary_A))-ip;
  oracle_i(axis)=fzero(fun,[-100,100]);
 end
 multistep=max(multistep,max(abs(previous.i-oracle_i)));
 trace(k+1,:)=[time,previous.i',oracle_i',previous.z'];
end
raw=struct('piecewise',raw,'multistep',trace);
limit=a.correctness.smo_equation_residual_absolute_A+a.correctness.smo_equation_residual_relative*100;
m=struct('all_passed',maxres<=limit&&maxerr<=limit&&multistep<=limit,...
 'axis_cases',count,'max_equation_residual_A',maxres,'max_oracle_error_A',maxerr,'multistep_oracle_error_A',multistep);
end

function [rows,traces]=phase_tests(c,a)
rows=struct('frequency_Hz',{},'interval',{},'relative_complex_error',{},'corrected_phase_abs_deg',{},'passed',{});
traces=cell(0,1);count=0;T=c.sample_s;time=(0:6000)'*T;win=time>=.2;
for convention={'left_zoh','rl_weighted_rotating'}
 q=c;q.interval_convention=convention{1};
 for freq=[-250 -166.66666666666666 -83.33333333333333 83.33333333333333 166.66666666666666 250]
  count=count+1;omega=2*pi*freq;E=1i*q.flux_hat*omega*exp(1i*omega*time);I=2*exp(1i*(omega*time+.4));
  if strcmp(q.interval_convention,'left_zoh')
   vprevious=[0;(I(2:end)-q.a*I(1:end-1))/q.b+E(1:end-1)];W=1;
  else
   V=(q.R_hat+1i*omega*q.L_hat)*I+E;
   W=(exp(1i*omega*T)-q.a)/(q.L_hat*q.b*(q.R_hat/q.L_hat+1i*omega));
   vprevious=[0;V(1:end-1)*W];
  end
  s=struct('i',zeros(2,1),'z',zeros(2,1));ef=zeros(2,1);data=zeros(numel(time),6);
  for k=1:numel(time)
   [s,~]=sensorless_smo_step(s,[real(I(k));imag(I(k))],[real(vprevious(k));imag(vprevious(k))],q,true,k==1);
   [ef,o]=sensorless_emf_step(ef,s.z,omega,sign(freq),q,true,k==1);
   corrected=complex(o.vector(1),o.vector(2));
   data(k,:)=[time(k),s.z',ef',atan2(imag(corrected*exp(-1i*omega*time(k))),real(corrected*exp(-1i*omega*time(k))))];
  end
  zinv=exp(-1i*omega*T);
  expected=(q.b*q.g/(1+q.b*q.g))*zinv/(1-q.observer_pole*zinv)*(1-q.filter_r)/(1-q.filter_r*zinv)*W;
  measured=sum(complex(data(win,4),data(win,5)).*conj(E(win)))/sum(abs(E(win)).^2);
  relative=abs(measured-expected)/abs(expected);phase_deg=max(abs(data(win,6)))*180/pi;
  % Same parameter-calculation tolerance for analytic steady harmonic response.
  passed=relative<=a.correctness.parameter_absolute_tolerance+a.correctness.parameter_relative_tolerance&&phase_deg<=a.correctness.pll_settle_angle_rms_deg;
  rows(count)=struct('frequency_Hz',freq,'interval',q.interval_convention,'relative_complex_error',relative,'corrected_phase_abs_deg',phase_deg,'passed',passed);
  traces{count}=data;
 end
end
end

function [rows,traces]=synthetic_tests(c,a)
% Independent analytic continuous RL signals, not a second PMSM plant.
rows=struct('speed_rpm',{},'angle_rms_deg',{},'angle_abs_max_deg',{},'speed_mean_relative',{},'valid_fraction',{},'passed',{});
traces=cell(0,1);time=(0:6000)'*c.sample_s;win=time>=.2;
speeds=[1000 2000 3000 -1000 -3000];
for j=1:numel(speeds)
 speed=speeds(j);omega=speed*c.pole_pairs*2*pi/60;
 E=1i*c.flux_hat*omega*exp(1i*omega*time);I=2*exp(1i*(omega*time+.4));
 V=(c.R_hat+1i*omega*c.L_hat)*I+E;
 W=(exp(1i*omega*c.sample_s)-c.a)/(c.L_hat*c.b*(c.R_hat/c.L_hat+1i*omega));
 voltage=[0;V(1:end-1)*W];s=sensorless_state(c);data=zeros(numel(time),16);
 for k=1:numel(time)
  [s,o]=sensorless_observer_step(s,[real(I(k));imag(I(k))],[real(voltage(k));imag(voltage(k))],sign(speed),true,k==1,c);
  err=atan2(sin(o.theta-omega*time(k)),cos(o.theta-omega*time(k)))*180/pi;
  data(k,:)=[time(k),o.theta,o.speed_rpm,err,o.valid,o.emf',o.i_hat',o.pll_error,o.pll_integral,o.phase_correction,o.injection',o.emf_magnitude,o.state];
 end
 rms_angle=sqrt(mean(data(win,4).^2));max_angle=max(abs(data(win,4)));speederror=abs(mean(data(win,3))-speed)/abs(speed);valid=mean(data(win,5));
 passed=rms_angle<=a.steady.angle_rms_max_electrical_deg&&max_angle<=a.steady.angle_abs_max_electrical_deg&&speederror<=a.steady.speed_mean_error_relative_max&&valid>=a.steady.valid_fraction_min;
 rows(j)=struct('speed_rpm',speed,'angle_rms_deg',rms_angle,'angle_abs_max_deg',max_angle,'speed_mean_relative',speederror,'valid_fraction',valid,'passed',passed);
 traces{j}=data;
end
end

function [m,raw]=state_tests(c)
% Saturation and disabled-step oracles use state equations, not a second call.
q=c;q.omega_limit_rad_s=10;s=struct('theta',0,'integral',0,'omega',0);
[next,p]=sensorless_pll_step(s,[0;1],q,true,false);
no_windup=next.integral==0&&p.saturated&&p.omega==10;
[held,h]=sensorless_pll_step(next,[0;0],q,false,false);
held_ok=held.integral==next.integral&&h.omega==next.omega;
[reset,r]=sensorless_pll_step(held,[0;1],q,true,true);
reset_ok=reset.theta==0&&reset.integral==0&&reset.omega==0&&r.theta==0;
smo=struct('i',[1;2],'z',[3;4]);v=[5;6];
[pred,d]=sensorless_smo_step(smo,[1e6;-1e6],v,c,false,false);
missing_ok=max(abs(pred.i-(c.a*smo.i+c.b*(v-smo.z))))<=1e-12&&isequal(pred.z,smo.z)&&~d.corrected;
% Lock acquisition, immediate invalidation, reset priority and direction change.
T=c.sample_s;omega=c.pole_pairs*2000*2*pi/60;s=sensorless_state(c);N=10000;trace=zeros(N,6);
first_valid=Inf;drop_ok=true;reset_all=true;direction_ok=true;
for k=1:N
 t=(k-1)*T;current=2*exp(1i*(omega*t+.4));E=1i*c.flux_hat*omega*exp(1i*omega*t);
 V=(c.R_hat+1i*omega*c.L_hat)*current+E;
 W=(exp(1i*omega*T)-c.a)/(c.L_hat*c.b*(c.R_hat/c.L_hat+1i*omega));
 previous=V*exp(-1i*omega*T)*W;valid=~(k>=6001&&k<=6005);reset_now=k==1||k==8001;
 direction=1;if k>=9001,direction=0;end
 [s,o]=sensorless_observer_step(s,[real(current);imag(current)],[real(previous);imag(previous)],direction,valid,reset_now,c);
 if o.valid&&isinf(first_valid),first_valid=t;end
 if ~valid,drop_ok=drop_ok&&~o.valid&&s.lock_count==0;end
 if reset_now,reset_all=reset_all&&isequal(s.smo.i,zeros(2,1))&&isequal(s.emf,zeros(2,1))&&s.pll.integral==0&&~o.valid;end
 if direction==0,direction_ok=direction_ok&&~o.valid;end
 trace(k,:)=[t,o.valid,o.state,s.lock_count,s.history_count,o.pll_integral];
end
reacquire=trace(6006:6404,2);lock_delay_ok=~any(reacquire)&&any(trace(6606:7999,2));
finite=all(isfinite(trace),'all');
m=struct('all_passed',no_windup&&held_ok&&reset_ok&&missing_ok&&drop_ok&&reset_all&&direction_ok&&lock_delay_ok&&finite&&isfinite(first_valid),...
 'saturation_antiwindup',no_windup,'disabled_prediction',held_ok,'pll_reset',reset_ok,...
 'missing_sample_prediction',missing_ok,'immediate_invalid',drop_ok,'full_reset_priority',reset_all,...
 'zero_direction_invalid',direction_ok,'reacquire_not_early',lock_delay_ok,'finite',finite,'first_valid_s',first_valid);
raw=struct('validity_trace',trace,'missing_prediction',pred.i,'pll_saturation',[p.omega,next.integral]);
end
