function status=startup_step(t,speed,adc,cfg)
%#codegen
% cfg: on/start/stop/restart seconds, window enabled, invalid interval seconds.
% status: state/current permit/speed permit/PWM permit/reason/request/accepted/enabled.
persistent state previous accepted enabled
if isempty(state),state=0;previous=false;accepted=-1;enabled=-1;end
request=(t>=cfg(2)&&t<cfg(3))||t>=cfg(4);
ready=speed(4)>.5;
if cfg(6)>=0&&t>=cfg(6)&&t<cfg(7),ready=false;end
reason=0;
if cfg(1)==0
 status=[4 1 1 1 0 double(request) accepted enabled];return;
end
if ~request
 state=0;reason=1;enabled=-1;
elseif state>=2&&~ready
 state=0;reason=2;enabled=-1;
elseif state==0
 if request&&~previous,state=1;accepted=t;end
elseif state==1
 if ready,state=2;enabled=t;end
elseif state==2
 % Next JEOS follows a complete acquisition cycle after enabling low sides.
 fresh=t>enabled+25e-6&&adc(6)>.5;
 valid=cfg(5)==0||all(adc(7:9)>.5);
 if fresh&&valid,state=3;end
elseif state==3
 % Native diagnostic 14 is the real speed-task pulse; no separate guessed phase.
 if adc(14)>.5,state=4;end
end
previous=request;
status=[state double(state>=3) double(state==4) double(state>=2) reason double(request) accepted enabled];
end
