function values=teach_values(signal)
% Timeseries stores matrix-valued Simulink signals with time in the last axis.
if signal.IsTimeFirst
 values=reshape(double(signal.Data),numel(signal.Time),[]);
else
 values=reshape(double(signal.Data),[],numel(signal.Time)).';
end
end
