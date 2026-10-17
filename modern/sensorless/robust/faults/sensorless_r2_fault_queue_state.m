function s=sensorless_r2_fault_queue_state
s=struct('queue',sensorless_v2_queue_state,'last_missing',false,'last_reset',false,...
 'epoch',uint64(0),'integrity_latched',false);
end
