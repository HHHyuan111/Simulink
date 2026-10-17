function [valid,diagnostic]=sensorless_r2_phase_guard(theta,vector,quality,sample_valid,reset,minimum_emf)
%#codegen
% Instantaneous packet quality. 5deg + assumed 3deg EMF budget = 8deg.
% No truth enters this function. A positive dot rejects the pi ambiguity.
valid=false;diagnostic=zeros(8,1);limit=5*pi/180;
if ~isfinite(theta)||any(~isfinite(vector))||~isfinite(minimum_emf)||minimum_emf<0,return;end
magnitude=hypot(vector(1),vector(2));if magnitude<=0||~isfinite(magnitude),return;end
dot=cos(theta)*vector(1)+sin(theta)*vector(2);
cross=cos(theta)*vector(2)-sin(theta)*vector(1);
phase_ok=dot>0&&abs(cross)<=sin(limit)*magnitude+8*eps*magnitude;
magnitude_ok=magnitude>=minimum_emf;
valid=quality&&sample_valid&&~reset&&phase_ok&&magnitude_ok;
diagnostic=[atan2(cross,dot);magnitude;dot/magnitude;cross/magnitude;double(phase_ok);...
 double(magnitude_ok);double(quality);double(valid)];
end
