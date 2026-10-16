function report=audit_pmsm_startup_interfaces
% Read-only interface audit. This does not implement or validate a startup loop.
here=fileparts(mfilename('fullpath'));root=fileparts(here);
source=fullfile(root,'PMSM_FOC_R2026a.slx');
reference=fullfile(here,'reference_v1','manifest.json');
assert(isfile(reference));
before=struct('model',teach_hash(source),'reference',teach_hash(reference));
assert(strcmp(before.model,'a0f7cbae9e7c334c25aa9dcf6e7e88d65fd89bd1888a0fa2ec0cd04f6cce262d'));
mdl='PMSM_FOC_R2026a';assert(~bdIsLoaded(mdl),'Use a separate batch process; preserve the desktop model.');
work=fullfile(root,'.build',['startup_audit_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
mkdir(work);candidate=fullfile(work,[mdl '.slx']);copyfile(source,candidate);
addpath(fullfile(root,'deadtime'),fullfile(root,'timing'));
load_system(candidate);guard=onCleanup(@()close_system(mdl,0));
assert(strcmpi(strrep(get_param(mdl,'FileName'),'\','/'),strrep(candidate,'\','/')));
report=struct('kind','read_only_startup_interface_audit','generated_at',char(datetime('now')),...
 'startup_implemented',false,'model_sha256',before.model,'reference_manifest_sha256',before.reference);
report.audit_script_sha256=teach_hash([mfilename('fullpath') '.m']);
ids={'155','439','453'};roles={'speed','d_current','q_current'};
for k=1:3
 p=getfullname(Simulink.ID.getHandle([mdl ':' ids{k}]));
 ints=find_system(p,'LookUnderMasks','all','FollowLinks','on','BlockType','DiscreteIntegrator');assert(numel(ints)==1);
 i=ints{1};ph=get_param(p,'PortHandles');
 v=struct('sid',ids{k},'path',p,'inputs',numel(ph.Inport),'outputs',numel(ph.Outport),...
  'enable_ports',numel(ph.Enable),'reset_ports',numel(ph.Reset),'integrator',i,...
  'external_reset',get_param(i,'ExternalReset'),'initial_condition',get_param(i,'InitialCondition'),...
  'method',get_param(i,'IntegratorMethod'),'sample_time',get_param(i,'SampleTime'));
 assert(v.inputs==1&&v.enable_ports==0&&v.reset_ports==0&&strcmp(v.external_reset,'none'));
 assert(strcmp(v.method,'Integration: Backward Euler'));
 report.pi.(roles{k})=v;
end
rt=sfroot;
chartPaths={'输出延迟/CCR预装载','Universal Bridge/续流','Universal Bridge/门极死区'};
filePaths={fullfile(root,'timing','timing_pwm.m'),fullfile(root,'deadtime','bridge_freewheel.m'),fullfile(root,'deadtime','gate_deadtime.m')};
for k=1:3
 c=rt.find('-isa','Stateflow.EMChart','Path',[mdl '/' chartPaths{k}]);assert(isscalar(c));
 assert(strcmp(strtrim(strrep(c.Script,char(13),'')),strtrim(strrep(fileread(filePaths{k}),char(13),''))));
 report.embedded_sources(k)=struct('chart',chartPaths{k},'file',filePaths{k},'sha256',teach_hash(filePaths{k}),'matches',true);
end
% Evaluate the stored ideal-bridge expressions, including the both-OFF case.
ideal=zeros(1,3);names={'phase_A','phase_B','phase_C'};
for k=1:3
 expr=get_param([mdl '/Universal Bridge/' names{k}],'Expr');
 f=str2func(['@(u)' expr]);ideal(k)=f([zeros(1,6) 24]);
 report.ideal_expressions{k}=expr;
end
assert(isequal(ideal,zeros(1,3)));
mw=get_param(mdl,'ModelWorkspace');cfg=[getVariable(mw,'p') getVariable(mw,'phis') .01 0 .01 .7];
[freewheel,channels]=bridge_freewheel(zeros(1,6),[3 1/sqrt(3) 0 0],24,cfg);
assert(any(abs(freewheel)>1)&&any(channels(1:3)~=0));
[openEmf,~]=bridge_freewheel(zeros(1,6),[0 0 100 0],24,cfg);
expected=-cfg(1)*100*cfg(2)*sin([0 -2*pi/3 2*pi/3]);expected=expected-mean(expected);
assert(max(abs(openEmf-expected))<1e-12);
report.power=struct('ideal_all_off_phase_V',ideal,'detailed_all_off_phase_V',freewheel,...
 'detailed_all_off_diode_paths',channels(1:3),'open_circuit_emf_V',openEmf,...
 'all_off_is_not_zero_voltage',true,'neutral_duty_is_not_power_off',true);
% Existing CCR routine has no stop/reset input: a pending write still latches.
clear timing_pwm;
h=62.5e-9;Ts=50e-6;tCfg=[1 h Ts 24.375e-6 1.1875e-6 1.5e-6 0 5e-6 0 4000];
timing_pwm(0,Ts/8*ones(1,3),tCfg);
[~,written]=timing_pwm(33.875e-6,Ts/8*ones(1,3),tCfg);
[active,latched]=timing_pwm(50e-6,Ts/4*ones(1,3),tCfg);
assert(written(8)==1&&latched(5)==1&&latched(7)==1&&max(abs(active-Ts/8))<1e-15);
report.ccr=struct('stop_reset_input_present',false,'write_diagnostic',written,...
 'next_uev_diagnostic',latched,'applied_threshold_s',active,'pending_write_survives_request_change',true);
% A stop interlock must act on all six gate requests, including pending rises.
clear gate_deadtime;
gCfg=[1 h 2e-6];gate_deadtime(0,[1 0 1 0 1 0],gCfg);
[off,~]=gate_deadtime(h,zeros(1,6),gCfg);
[later,~]=gate_deadtime(3e-6,zeros(1,6),gCfg);
assert(all(off==0)&&all(later==0));
report.gate_all_off_cancels_armed_rises=true;
fw='D:/AxDr_L/firmware/AxDr_App/User';
files={'drive/drive.c','drive/drive_reset.c','drive/drive_pwm.c','bsp/target_pwm.c','algorithm/control_pid.c','app/control_cycle.c','motor/foc_drv.c'};
for k=1:numel(files)
 file=fullfile(fw,files{k});assert(isfile(file));
 report.firmware_files(k)=struct('file',file,'sha256',teach_hash(file));
end
[status,commit]=system('git -C D:/AxDr_L rev-parse HEAD');assert(status==0);report.firmware_head=strtrim(commit);
assert(strcmp(teach_hash(source),before.model)&&strcmp(teach_hash(reference),before.reference));
report.source_files_preserved=true;
report.interface_audit_passed=true;
report.limitations={'No startup subsystem installed; no closed-loop startup simulation performed.',...
 'Bridge check uses the existing static non-salient PMSM freewheel approximation; no hardware power-off claim.',...
 'Firmware hashes record inspected local files; the simulator is not a cycle-exact firmware port.'};
teach_writejson(fullfile(here,'startup_interface_audit.json'),report);
fprintf('STARTUP_INTERFACE_AUDIT_PASS\n');
end
