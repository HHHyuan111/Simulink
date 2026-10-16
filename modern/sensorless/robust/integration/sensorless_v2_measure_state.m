function s=sensorless_v2_measure_state
% Explicit state, also used by the independent log composition replay.
s=struct('previous',zeros(3,1),'bias_filter',zeros(3,1),'count',0);
end
