function report=validate_sensorless_r2_fault_cores(folder)
% Independent event/geometry oracles. No plant model load or simulation.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);
for d={'sensorless','sensorless/robust','sensorless/robust/integration','sensorless/robust/performance','sensorless/robust/faults','timing','teaching'},addpath(fullfile(modern,d{1}));end
assert(~isfolder(folder));mkdir(folder);report=struct('status','running','all_passed',false,'model_loaded',false);
for f=dir(fullfile(here,'*.m'))',report.sources.(erase(f.name,'.m'))=teach_hash(fullfile(f.folder,f.name));end
teach_writejson(fullfile(folder,'report.json'),report);
v=sensorless_v2_config_values(.105125,.0001037615,20,12,false,0);c=sensorless_v2_config_rt(v);h=c.h_s;N=round(c.period_s/h);first=round((c.adc_trigger_s+3*c.adc_rank_s)/h);delay=round(c.observer_exec_s/h);
% Nominal ingress and queue are byte-identical to their local R1 core.
a=sensorless_v2_measure_state;b=a;
for k=0:99
 t=(first+k*N)*h;measured=[sin(k);cos(k);-sin(k)-cos(k)];adc=measured;
 [a,x1,y1,p1,d1,f1,m1]=sensorless_v2_measure_step(a,t,measured,adc,ones(1,15),c);
 [b,x2,y2,p2,d2,f2,m2]=sensorless_r2_ingress_step(b,t,measured,adc,ones(1,15),c,false,false);
 assert(isequaln(a,b)&&isequaln([x1;y1;double(p1);double(d1);double(f1);m1],[x2;y2;double(p2);double(d2);double(f2);m2]));
end
[sa,xa,ya,pa,da,fa,ma]=sensorless_r2_ingress_step(b,.6,[NaN;Inf;-Inf],[Inf;NaN;Inf],ones(1,15),c,true,false);
[sb,xb,yb,pb,db,fb,mb]=sensorless_r2_ingress_step(b,.6,[99;-87;13],[-90;70;80],zeros(1,15),c,true,false);
assert(isequaln(sa,sb)&&isequaln([xa;ya;double(pa);double(da);double(fa);ma],[xb;yb;double(pb);double(db);double(fb);mb])&&sa.count==0);
left=sensorless_v2_queue_state;right=sensorless_r2_fault_queue_state;
for tick=0:2400
 t=tick*h;theta=mod(500*t,2*pi);[left,x,p,r]=sensorless_v2_queue_step(left,t,theta,500,true,true,true,c);
 [right,y,q,s]=sensorless_r2_fault_queue_step(right,t,theta,500,true,true,true,false,false,0,c);
 assert(isequaln(x,y)&&p==q&&r==s);
end
% Sparse event calls are sufficient for this pure queue: no tick integral.
% Exactly five missing captures, and a single reset, each followed by599
% synthetic unlocked/relock-quality samples (the R1 quality core is separate).
for fixture=1:2
 state=sensorless_r2_fault_queue_state;fault=first+N;healthy=first+(1+5*(fixture==1)+1*(fixture==2))*N;
 safe=healthy+598*N;refs=first+(0:608)*N;ticks=unique([0 refs-1 refs refs+delay-1 refs+delay]);ticks=ticks(ticks>=0);
 accepted=0;ever_before=false;ever_after=false;
 for tick=ticks
  missing=fixture==1&&tick>=fault&&tick<healthy;reset=fixture==2&&tick>=fault&&tick<healthy;
  quality=tick<fault||tick>=safe;
  [state,values,permit,reason,diag]=sensorless_r2_fault_queue_step(state,tick*h,mod(500*tick*h,2*pi),500,quality,~missing,true,reset,missing,0,c);
  accepted=accepted+diag(5);
  if tick<fault&&permit,ever_before=true;end
  if tick>=fault&&tick<safe+delay,assert(~permit&&all(values(9:11)==0));end
  if tick>=safe+delay&&permit,ever_after=true;end
  if tick==fault,assert(~permit);end
  if reset,assert(bitand(uint16(reason),uint16(1024))~=0);end
 end
 assert(ever_before&&ever_after&&state.epoch==1);
 expected=numel(refs)-5*(fixture==1);assert(accepted==expected);
 report.recovery(fixture)=struct('kind',fixture,'accepted_packets',accepted,'epoch',double(state.epoch),'first_healthy_s',healthy*h,'earliest_permit_s',(safe+delay)*h);
end
% One-us release jitter: duplicate evaluation cannot add the delay twice.
state=sensorless_r2_fault_queue_state;cj=c;cj.interference_s=1e-6;
[state,~,~,~]=sensorless_r2_fault_queue_step(state,first*h,.7,500,true,true,true,false,false,1e-6,cj);
[state,~,~,~]=sensorless_r2_fault_queue_step(state,first*h,1.9,500,true,true,true,false,false,1e-6,cj);
[state,values,permit]=sensorless_r2_fault_queue_step(state,(first+delay)*h,.7,500,true,true,true,false,false,1e-6,cj);assert(~permit&&values(13)==0);
[state,values,permit]=sensorless_r2_fault_queue_step(state,(first+delay+16)*h,.7,500,true,true,true,false,false,1e-6,cj);assert(permit&&values(13)==1&&values(5)==.7&&values(3)==(first+delay+16)*h);
% Unknown sequence faults must stay latched even while an old packet is fresh.
state=sensorless_r2_fault_queue_state;
for tick=[first first+delay first+N]
 [state,~,~,~]=sensorless_r2_fault_queue_step(state,tick*h,1,500,true,true,true,false,false,0,c);
end
state.queue.pending.sequence=17;
[state,values,permit,reason]=sensorless_r2_fault_queue_step(state,(first+N+delay)*h,1,500,true,true,true,false,false,0,c);
assert(~permit&&bitand(uint16(reason),uint16(64))~=0);
[state,values,permit,reason]=sensorless_r2_fault_queue_step(state,(first+N+delay+1)*h,1,500,true,true,true,false,false,0,c);
assert(~permit&&bitand(uint16(reason),uint16(4096))~=0&&all(values(9:11)==0));
% Original physical PWM actor equality for continuously changing requests.
cfg=[1 h c.period_s c.adc_trigger_s c.adc_aperture_s c.adc_rank_s 0 8e-6 0 4000];program=zeros(1,22);state=sensorless_r2_pwm_state(cfg);clear timing_pwm;
for tick=0:2400
 t=tick*h;request=c.period_s*[.25+.02*sin(30000*t) .31+.01*cos(23000*t) .17+.03*sin(17000*t)];
 [x,a]=timing_pwm(t,request,cfg);[state,y,b]=sensorless_r2_pwm_step(state,t,request,cfg,program);assert(isequaln(x,y)&&isequaln(a,b));
end
for extra=[10e-6 13.125e-6 30e-6]
 state=sensorless_r2_pwm_state(cfg);program=zeros(1,22);program(1)=3;program(6)=1;program(10)=extra;
 write=first+round((8e-6+extra)/h);apply=(floor(write/(N/2))+1)*N/2;
 for tick=0:apply
  [state,~,diag]=sensorless_r2_pwm_step(state,tick*h,c.period_s/3*ones(1,3),cfg,program);
  if tick==write,assert(diag(4)==1&&diag(7)==0);end
 end
 assert(diag(5)==1&&diag(7)==1&&abs(diag(9)-(apply-first)*h)<1e-12);
end
program=zeros(1,22);program(1)=3;program(6)=1;program(10)=60e-6;state=sensorless_r2_pwm_state(cfg);rejected=false;
try
 for tick=0:first+N,[state,~,~]=sensorless_r2_pwm_step(state,tick*h,c.period_s/3*ones(1,3),cfg,program);end
catch err,rejected=strcmp(err.identifier,'sensorless:R2UnsupportedOverlap');end
assert(rejected);
% Same voltage equations with good anchors; unavailable anchors ignore data.
left=sensorless_v2_voltage_state;right=left;
for tick=0:2400
 t=tick*h;I=4*[sin(500*t);sin(500*t-2*pi/3);sin(500*t+2*pi/3)];threshold=c.period_s*[.25 .33 .18];carrier=abs(mod(t,c.period_s)-c.period_s/2);vec=3*[cos(500*t);sin(500*t)];
 [left,x1,i1,r1,n1,u1]=sensorless_v2_voltage_step(left,t,threshold,carrier,24,0,I,vec,500,1,c);
 [right,x2,i2,r2,n2,u2]=sensorless_r2_voltage_step(right,t,threshold,carrier,24,0,I,vec,500,1,c,true);
 assert(isequaln(left,right)&&isequaln([x1;i1;double(r1);n1;u1],[x2;i2;double(r2);n2;u2]));
 if tick==first-1,pre=right;end
end
[a,x1,i1,r1,n1,u1]=sensorless_r2_voltage_step(pre,first*h,threshold,carrier,24,0,[Inf;NaN;-Inf],vec,500,1,c,false);
[b,x2,i2,r2,n2,u2]=sensorless_r2_voltage_step(pre,first*h,threshold,carrier,24,0,[99;-99;0],vec,500,1,c,false);
assert(isequaln(a,b)&&isequaln([x1;i1;double(r1);n1;u1],[x2;i2;double(r2);n2;u2])&&a.anchor_count==0);
report.nominal_queue_ticks=2401;report.nominal_pwm_ticks=2401;report.nominal_voltage_ticks=2401;report.nominal_ingress_frames=100;report.unavailable_data_independence=true;
report.timing_boundary_cases=3;report.overlap_rejected=true;report.integrity_latch_verified=true;report.all_passed=true;report.status='passed';
for f=dir(fullfile(here,'*.m'))',assert(strcmp(report.sources.(erase(f.name,'.m')),teach_hash(fullfile(f.folder,f.name))));end
teach_writejson(fullfile(folder,'report.json'),report);fprintf('R2_FAULT_CORES_PASSED no_model_load=1\n');
end
