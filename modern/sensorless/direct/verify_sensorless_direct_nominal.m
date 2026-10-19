function result=verify_sensorless_direct_nominal(cfg)
% Check the simplified publisher against the previous normal equations.
% This is an offline function comparison; no model or injection is created.
clear sless_direct_queue_block
c=sensorless_v2_config_rt(cfg);old=sensorless_r2_fault_queue_state;
exact=true;count=32000;
for tick=0:count-1
 t=tick*c.h_s;theta=mod(800*t,2*pi);quality=tick>=800;
 [old,a,ap,ar]=sensorless_r2_fault_queue_step(old,t,theta,800,quality,true,true,false,false,0,c);
 [b,bp,br]=sless_direct_queue_block(t,theta,800,quality,true,true,cfg);
 if ~isequaln(a,b)||ap~=bp||ar~=br,exact=false;break;end
end
clear sless_direct_queue_block
result=struct('native_points',count,'last_checked_tick',tick,'normal_outputs_exact',exact,'simulation_started',false);
assert(exact,'Simplified normal publisher changed the output.');
end
