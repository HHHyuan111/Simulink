function s=sensorless_v2_queue_state
r=sensorless_robust_state;
s=struct('output',r.output,'pending',r.output.packet,'has_pending',false,'last_capture',-1,...
 'fault_latched',false,'observed_unlocked',false);
end
