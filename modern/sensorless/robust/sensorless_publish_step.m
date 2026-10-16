function [s,o]=sensorless_publish_step(s,packet,present,now_s,pwm_apply_s,c,live_input_valid,live_timing_valid)
%#codegen
% Three angle timestamps; permission never follows a stale numeric value.
now=tick(now_s,c.h_s);apply=tick(pwm_apply_s,c.h_s);reason=uint16(0);
assert(islogical(live_input_valid)&&isscalar(live_input_valid)&&islogical(live_timing_valid)&&isscalar(live_timing_valid));
% Current faults must win before the next computed packet becomes available.
if ~live_input_valid,reason=bitor(reason,uint16(2));end
if ~live_timing_valid,reason=bitor(reason,uint16(8));end
if present
 assert(isfinite(packet.sequence)&&packet.sequence>=0&&packet.sequence==floor(packet.sequence));
 assert(isfinite(packet.theta_rad)&&isfinite(packet.omega_e_rad_s));
 reference=tick(packet.reference_time_s,c.h_s);available=tick(packet.available_time_s,c.h_s);
 assert(reference<=available,'sensorless:PacketTime','Packet available before its measurement.');
 if available>now,reason=bitor(reason,uint16(32));
 elseif ~s.has_packet,s.packet=packet;s.has_packet=true;
 elseif packet.sequence==s.packet.sequence
  if ~same_packet(packet,s.packet),reason=bitor(reason,uint16(64));end
 elseif packet.sequence==s.packet.sequence+1
  if reference<=tick(s.packet.reference_time_s,c.h_s),reason=bitor(reason,uint16(32));
  else,s.packet=packet;
  end
 else,reason=bitor(reason,uint16(64));
 end
end
p=s.packet;reference=tick(p.reference_time_s,c.h_s);available=tick(p.available_time_s,c.h_s);
age=now-reference;horizon=apply-reference;
if ~s.has_packet,reason=bitor(reason,uint16(1));
else
 if ~p.input_valid,reason=bitor(reason,uint16(2));end
 if ~p.observer_valid,reason=bitor(reason,uint16(4));end
 if ~p.timing_valid,reason=bitor(reason,uint16(8));end
 if age>floor(c.maximum_state_age_s/c.h_s+1e-9),reason=bitor(reason,uint16(16));end
 if now<available||age<0||apply<now,reason=bitor(reason,uint16(32));end
 if horizon>floor(c.maximum_apply_prediction_s/c.h_s+1e-9),reason=bitor(reason,uint16(128));end
 if abs(p.omega_e_rad_s)>c.omega_limit_rad_s,reason=bitor(reason,uint16(256));end
end
sample=mod(p.theta_rad,2*pi);at_now=sample;at_apply=sample;
if age>=0&&age<=floor(c.maximum_state_age_s/c.h_s+1e-9),at_now=mod(sample+p.omega_e_rad_s*age*c.h_s,2*pi);end
if horizon>=0&&horizon<=floor(c.maximum_apply_prediction_s/c.h_s+1e-9),at_apply=mod(sample+p.omega_e_rad_s*horizon*c.h_s,2*pi);end
permit=reason==0;control_sample=0;control_apply=0;control_speed=0;
if permit,control_sample=sample;control_apply=at_apply;control_speed=p.omega_e_rad_s/c.pole_pairs*60/(2*pi);end
o=struct('sequence',p.sequence,'reference_time_s',p.reference_time_s,'available_time_s',p.available_time_s,...
 'age_s',age*c.h_s,'theta_sample_rad',sample,'theta_now_rad',at_now,'theta_pwm_rad',at_apply,...
 'raw_speed_rpm',p.omega_e_rad_s/c.pole_pairs*60/(2*pi),'control_theta_sample_rad',control_sample,...
 'control_theta_pwm_rad',control_apply,'control_speed_rpm',control_speed,...
 'control_permit',permit,'reason',reason,'reset_request',bitand(reason,uint16(64))~=0);
end

function n=tick(t,h)
assert(isscalar(t)&&isfinite(t)&&t>=0);n=round(t/h);
assert(abs(t-n*h)<=1e-12,'sensorless:PacketGrid','Off-grid packet time.');
end

function yes=same_packet(a,b)
yes=a.sequence==b.sequence&&a.reference_time_s==b.reference_time_s&&a.available_time_s==b.available_time_s&&...
 a.theta_rad==b.theta_rad&&a.omega_e_rad_s==b.omega_e_rad_s&&a.input_valid==b.input_valid&&...
 a.observer_valid==b.observer_valid&&a.timing_valid==b.timing_valid;
end
