function diagnose_timing
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);addpath(fullfile(root,'teaching'));work=fullfile(root,'.build','timing_stage');
a=load(fullfile(work,'baseline.mat'));b=load(fullfile(work,'off_probe.mat'));keys=a.baseline.who;
for k=1:numel(keys)
 x=a.baseline.get(keys{k});if ~isa(x,'timeseries'),continue;end;y=b.o.get(keys{k});xx=teach_values(x);yy=teach_values(y);
 fprintf('%s | %s %s | times %d | max %.17g | unequal %d\n',keys{k},mat2str(size(xx)),mat2str(size(yy)),isequal(x.Time,y.Time),max(abs(xx-yy),[],'all'),nnz(xx~=yy));
end
mdl='PMSM_FOC_R2026a';load_system(fullfile(work,[mdl '.slx']));g=onCleanup(@()close_system(mdl,0));
feval(mdl,[],[],[],'compile');
for p={[mdl '/SVPWM Function v1.0'],[mdl '/输出延迟/选择'],[mdl '/输出延迟/输出方式'],[mdl '/采样设置/采样方式'],[mdl '/采样设置/捕获'],getfullname(Simulink.ID.getHandle([mdl ':442']))}
 fprintf('RATE %s %s\n',p{1},jsonencode(get_param(p{1},'CompiledSampleTime')));
end
feval(mdl,[],[],[],'term');
set_param([mdl '/时序设置'],'real_on','on');fprintf('REAL COMPILE PROBE\n');set_param(mdl,'SimulationCommand','update');
fprintf('REAL COMPILE OK\n');in=Simulink.SimulationInput(mdl);in=in.setModelParameter('StopTime','.001');o=sim(in);save(fullfile(work,'real_probe.mat'),'o','-v7.3');
end
