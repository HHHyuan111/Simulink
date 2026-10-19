function [theta_sample,theta_pwm,speed_feedback,omega_feedback,id_ref,iq_ref,n_ref,state,beta,age,pi_values]=sless_closed_control_block(t,pub,permit,request,cfg)
%#codegen
% No actual rotor angle/speed input. All state feedback is published SMO data.
persistent theta_if phase good_since switch_t integral last_iq start_id last_good theta_good omega_good speed_good
if isempty(phase)
 theta_if=0;phase=1;good_since=-1;switch_t=-1;integral=0;last_iq=0;start_id=0;
 last_good=-1;theta_good=0;omega_good=0;speed_good=0;
end
Ts=cfg(1);offset=cfg(2);pairs=cfg(3);align_end=cfg(4);rotate_s=cfg(5);ramp_end=cfg(6);
open_rpm=cfg(7);align_A=cfg(8);open_A=cfg(9);earliest=cfg(10);hold_s=cfg(11);blend_s=cfg(12);decay_s=cfg(13);
speed_ramp_s=cfg(14);Kp=cfg(15);Ki=cfg(16);Ks=cfg(17);limit=cfg(18);Kt=cfg(19);divider=round(cfg(20));
k=max(0,round((t-offset)/Ts));
open_fraction=max(0,min(1,(t-align_end)/(ramp_end-align_end)));
open_fraction=open_fraction^3*(10-15*open_fraction+6*open_fraction^2);open_speed=open_rpm*open_fraction;
open_omega=open_speed*(2*pi/60)*pairs;
if t>align_end,theta_if=mod(theta_if+Ts*open_omega,2*pi);end
if permit&&pub(1)>=0
 last_good=t;theta_good=pub(6);speed_good=pub(8);omega_good=speed_good*(2*pi/60)*pairs;
end
% Qualify the intended I/F direction and speed, using estimates only.
if permit&&pub(8)>0&&abs(pub(8)-open_speed)<=max(100,.2*open_rpm)
 if good_since<0,good_since=t;end
else,good_since=-1;
end
age=1;if last_good>=0,age=t-last_good;end
estimated=mod(theta_good+omega_good*max(0,t-last_good),2*pi);
beta=0;theta_sample=theta_if;omega_feedback=open_omega;speed_feedback=open_speed;n_ref=open_speed;
id_ref=0;iq_ref=0;
if phase==1&&t>=align_end,phase=2;end
if phase==2&&t>=earliest&&good_since>=0&&t-good_since>=hold_s-Ts/2
 phase=3;switch_t=t;
end
if phase>=3&&phase<=5&&age>1e-3,phase=6;end
if phase==1
 id_ref=align_A;
elseif phase==2
 f=max(0,min(1,(t-align_end)/rotate_s));f=f^3*(10-15*f+6*f^2);
 phi=(pi/2)*f;id_ref=align_A*cos(phi);iq_ref=open_A*sin(phi);
elseif phase==3
 beta=max(0,min(1,(t-switch_t)/blend_s));
 delta=atan2(sin(estimated-theta_if),cos(estimated-theta_if));
 theta_sample=mod(theta_if+beta*delta,2*pi);
 omega_feedback=(1-beta)*open_omega+beta*omega_good+delta/blend_s;
 speed_feedback=(1-beta)*open_speed+beta*speed_good;
 % Preserve the stator current vector while rotating the controller frame.
 id_ref=open_A*sin(beta*delta);iq_ref=open_A*cos(beta*delta);
 integral=Kt*iq_ref-Kp*(n_ref-speed_feedback);last_iq=iq_ref;
 if beta>=1,phase=4;start_id=id_ref;end
elseif phase==4||phase==5
 beta=1;theta_sample=estimated;omega_feedback=omega_good;speed_feedback=speed_good;
 closed_t=switch_t+blend_s;decay=max(0,min(1,(t-closed_t)/decay_s));id_ref=start_id*(1-decay);
 ramp=max(0,min(1,(t-closed_t-decay_s)/speed_ramp_s));n_ref=open_rpm+(request-open_rpm)*ramp;
 error=n_ref-speed_feedback;
 if mod(k,divider)==0
  raw=Kp*error+integral;torque=max(-limit,min(limit,raw));
  integral=integral+Ki*(divider*Ts)*(error-Ks*(raw-torque));last_iq=torque/Kt;
 end
 iq_ref=last_iq;
 if decay>=1,phase=5;end
else
 beta=0;id_ref=0;iq_ref=0;omega_feedback=0;speed_feedback=0;n_ref=0;
end
lead=max(0,min(Ts,pub(12)-t));theta_pwm=mod(theta_sample+omega_feedback*lead,2*pi);
proportional=Kp*(n_ref-speed_feedback);
if phase<=2,integral=Kt*iq_ref-proportional;elseif phase==6,integral=0;end
pi_values=[proportional;integral;proportional+integral;Kt*iq_ref];
state=double(phase);
end
