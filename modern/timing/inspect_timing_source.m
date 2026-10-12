function inspect_timing_source
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);addpath(fullfile(root,'teaching'));
work=fullfile(root,'.build','timing_stage');mdl='PMSM_FOC_R2026a';source=fullfile(root,[mdl '.slx']);
assert(strcmp(teach_hash(source),'a61192106edbe22425ff55814ffc3d009203baddd9fe8bfc2f245179f99e7548'));
copyfile(source,fullfile(work,'PMSM_FOC_before_timing.slx'));load_system(source);g=onCleanup(@()close_system(mdl,0));
before=teach_snapshot(mdl);mw=get_param(mdl,'ModelWorkspace');code=mw.MATLABCode;init=get_param(mdl,'InitFcn');
save(fullfile(work,'before.mat'),'before','code','init');
fid=fopen(fullfile(work,'inventory.txt'),'w','n','UTF-8');c=onCleanup(@()fclose(fid));
fprintf(fid,'%s\nINIT\n%s\n',code,init);
for b=before.blocks
 if isfield(b.params,'SampleTime'),fprintf(fid,'%s | %s | %s\n',b.sid,b.path,b.params.SampleTime);end
 if strcmp(b.type,'DiscreteIntegrator'),fprintf(fid,'INTEGRATOR %s\n',jsonencode(get_param(b.path,'DialogParameters')));end
end
fprintf('TIMING_BASELINE_SHORT\n');in=Simulink.SimulationInput(mdl);in=in.setModelParameter('StopTime','.02');baseline=sim(in);save(fullfile(work,'baseline.mat'),'baseline','-v7.3');
% Determine whether the preserved integrator supports phased sample times.
h=Simulink.ID.getHandle([mdl ':442']);set_param(h,'SampleTime','[dt 28.875e-6]');
try,set_param(mdl,'SimulationCommand','update');fprintf('PHASED_INTEGRATOR_SUPPORTED\n');catch e,fprintf('PHASED_INTEGRATOR_ERROR %s\n',e.message);end
end
