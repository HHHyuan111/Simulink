function [Tcm,sector,diagnostic] = fcn(alpha,beta,Vdc,Ts)
% Original six-sector construction, with simultaneous overmodulation scaling.
% Tcm is a threshold in [0,Ts/2]; upper duty = 1-2*Tcm/Ts.
% diagnostic: t1,t2,total zero-vector time,Da,Db,Dc,overmodulated,bounds_guard.
Tcm=ones(1,3)*Ts/4;sector=0;
diagnostic=[0 0 Ts .5 .5 .5 0 0];
if Vdc<=0 || Ts<=0 || (alpha==0 && beta==0),return;end
ref1=beta;ref2=(-beta+sqrt(3)*alpha)/2;ref3=(-beta-sqrt(3)*alpha)/2;
sector=4*double(ref3>0)+2*double(ref2>0)+double(ref1>0);
X=Ts*sqrt(3)/Vdc*beta;
Y=Ts*sqrt(3)/Vdc*(sqrt(3)*alpha+beta)/2;
Z=Ts*sqrt(3)/Vdc*(-sqrt(3)*alpha+beta)/2;
switch sector
 case 1,t1=Z;t2=Y;
 case 2,t1=Y;t2=-X;
 case 3,t1=-Z;t2=X;
 case 4,t1=-X;t2=Z;
 case 5,t1=X;t2=-Y;
 otherwise,t1=-Y;t2=-Z;
end
t1=max(0,t1);t2=max(0,t2);
total=t1+t2;over=double(total>Ts);
if total>Ts
 scale=Ts/total;t1=t1*scale;t2=t2*scale;
end
tzero=max(0,Ts-t1-t2);
ta=tzero/4;tb=ta+t1/2;tc=tb+t2/2;
switch sector
 case 1,Tcm=[tb ta tc];
 case 2,Tcm=[ta tc tb];
 case 3,Tcm=[ta tb tc];
 case 4,Tcm=[tc tb ta];
 case 5,Tcm=[tc ta tb];
 case 6,Tcm=[tb tc ta];
end
guard=double(any(Tcm<-1e-12) || any(Tcm>Ts/2+1e-12));
Tcm=min(Ts/2,max(0,Tcm));
diagnostic=[t1 t2 tzero 1-2*Tcm/Ts over guard];
end
