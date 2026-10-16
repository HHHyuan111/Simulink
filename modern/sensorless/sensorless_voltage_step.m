function [s,weighted,interval,ready,native]=sensorless_voltage_step(s,t,threshold,carrier,bus,sequence,cfg)
%#codegen
% Native-grid reconstruction from APPLIED thresholds; no requested voltage.
% cfg=[h Ts control_offset R L sequence_available].
h=cfg(1);Ts=cfg(2);offset=cfg(3);tick=round(t/h);N=round(Ts/h);first=round(offset/h);
threshold_column=reshape(threshold,3,1);upper=double(carrier>=threshold_column);
u=bus*[(2*upper(1)-upper(2)-upper(3))/3;(upper(2)-upper(3))/sqrt(3)];
weighted=s.published;interval=s.interval;ready=s.ready;
rho=exp(-cfg(4)*h/cfg(5));
if tick>s.last_tick
 assert(tick==s.last_tick+1,'sensorless:VoltageGrid','Native voltage grid sample was skipped.');
 s.acc=rho*s.acc+(1-rho)*s.previous_voltage;
end
boundary=tick>=first&&mod(tick-first,N)==0;
if boundary
 if s.started
  weighted=s.acc/(1-exp(-cfg(4)*Ts/cfg(5)));interval=[s.start_time;t];ready=true;
 else
  weighted=zeros(2,1);interval=[t;t];ready=false;s.started=true;
 end
 s.published=weighted;s.interval=interval;s.ready=ready;s.acc=zeros(2,1);s.start_time=t;
end
seq=sequence;if cfg(6)==0,seq=-1;end
changed=any(threshold_column~=s.previous_threshold)||seq~=s.previous_sequence;
if changed,s.piece_count=s.piece_count+1;end
s.last_tick=tick;s.previous_voltage=u;s.previous_threshold=threshold_column;s.previous_sequence=seq;
% All native samples retained for independent voltage/CCR provenance checks.
native=[t;u;threshold_column;carrier;bus;seq;double(boundary);double(ready);s.piece_count];
end
