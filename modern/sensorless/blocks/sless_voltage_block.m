function [weighted,interval,ready,native]=sless_voltage_block(t,threshold,carrier,bus,diag,cfg)
%#codegen
persistent s
if isempty(s)
 s=struct('published',zeros(2,1),'interval',zeros(2,1),'ready',false,...
  'last_tick',-1,'acc',zeros(2,1),'previous_voltage',zeros(2,1),'started',false,...
  'start_time',0,'previous_threshold',-ones(3,1),'previous_sequence',-2,'piece_count',0);
end
[s,weighted,interval,ready,native]=sensorless_voltage_step(s,t,threshold,carrier,bus,diag(7),cfg);
end
