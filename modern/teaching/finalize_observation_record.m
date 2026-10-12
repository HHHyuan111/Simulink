function finalize_observation_record
% Add explicit effective timing to an existing record without re-simulation.
folder=fileparts(mfilename('fullpath'));directory=fullfile(folder,'report_firmware_io');
data=load(fullfile(directory,'runs.mat'));record=data.record;outputs=data.outputs;
for k=1:numel(record.cases),record.cases(k).timing=observation_timing(record.model_workspace_values,record.cases(k).settings);end
periods=arrayfun(@(c)c.timing.speed_execution_period_s,record.cases);assert(max(abs(periods-[50e-6 100e-6 100e-6]))<1e-12);
teach_writejson(fullfile(directory,'record.json'),record);save(fullfile(directory,'runs.mat'),'outputs','record','-v7.3');
fprintf('OBS_EXPLICIT_TIMING_RECORDED\n');
end
