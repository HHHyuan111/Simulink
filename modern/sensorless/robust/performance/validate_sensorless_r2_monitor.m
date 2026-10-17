function result=validate_sensorless_r2_monitor(folder)
% Synthetic native traces: exact threshold, one tick above, angle wrap,
% stale/live faults, final-interval closure and enabled-event reconstruction.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));
addpath(here,base,fileparts(here),fullfile(fileparts(here),'integration'),fullfile(fileparts(base),'teaching'));
record=sensorless_r2_snapshot_sources(folder);h=62.5e-9;Ts=50e-6;last=40000;
traces=cell(7,1);result=struct('cases',7,'all_passed',true);
for fixture=1:7
 s=sensorless_r2_monitor_state;events=zeros(last+1,16);counters=zeros(last+1,12);count=0;expected=false(last+1,1);expectedViolations=false(last+1,1);
 for tick=0:last
  t=tick*h;pub=zeros(13,1);pub(1)=floor(t/Ts);pub(2)=floor(t/Ts)*Ts;pub(3)=pub(2);pub(4)=t-pub(2);
  pub(6)=.2;pub(8)=1000;pub(9:11)=1;truth=.2;speed=1000;permit=true;reason=0;adc=true;timing=true;reset=false;
  if fixture==1,truth=.2+8*pi/180+1e-9;permit=tick<32000;
  elseif fixture==2,truth=.2+8*pi/180+1e-9;permit=tick<32001;
  elseif fixture==3,pub(6)=2*pi-.01;truth=.01;
  elseif fixture==4,adc=tick<123;permit=adc;reason=2*double(~adc);
  elseif fixture==5,truth=.2+.3;permit=tick>=100&&tick<1000||tick>=2000;
  elseif fixture==6,adc=~(tick>=123&&tick<176);reset=tick>=1000&&tick<1003;
  else,if tick>=16000,pub(4)=61e-6;end
  end
  if ~permit,pub(9:11)=0;end
  expected(tick+1)=permit&&(abs(atan2(sin(pub(6)-truth),cos(pub(6)-truth))*180/pi)>8||abs(pub(8)-speed)/max(abs(speed),1)>.03);
  expectedViolations(tick+1)=permit&&(~adc||~timing||reset||reason~=0||pub(4)>60e-6+1e-12||pub(3)>t+1e-12);
  [s,c,event,change]=sensorless_r2_monitor_step(s,t,pub,permit,reason,adc,timing,reset,truth,speed,h,Ts);
  counters(tick+1,:)=c';if change,count=count+1;events(count,:)=event';end
 end
 events=events(1:count,:);audit=sensorless_r2_event_audit(events,counters,h);
 padded=[false;expected(1:end-1);false];lengths=find(diff(padded)==-1)-find(diff(padded)==1);
 maximum=0;if ~isempty(lengths),maximum=max(lengths);end
 assert(round(counters(end,2)/h)==maximum&&round(counters(end,3)/h)==sum(expected(1:end-1)));
 assert(counters(end,5)==sum(expectedViolations));
 if fixture==1,assert(audit.false_valid_longest_s==.002);end
 if fixture==2,assert(audit.false_valid_longest_s>.002);end
 traces{fixture}=struct('events',events,'counters',counters,'expected_bad',expected,'audit',audit);
end
save(fullfile(folder,'monitor.mat'),'traces','result','-v7.3');sensorless_v2_guard_sources(record);
record.status='passed';record.phase='completed';record.all_passed=true;record.raw_sha256=teach_hash(fullfile(folder,'monitor.mat'));
teach_writejson(fullfile(folder,'record.json'),record);teach_writejson(fullfile(folder,'metrics.json'),result);
fprintf('R2_NATIVE_MONITOR_COMPONENT_PASSED %s\n',folder);
end
