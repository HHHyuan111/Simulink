function build_pmsm_r2026a
% Build a runnable PMSM copy using only MATLAB and Simulink.
% The archived model is never overwritten. The original controllers and
% SVPWM are retained; the missing SPS plant becomes an ideal switching
% bridge and the standard continuous dq PMSM equations.
root = fileparts(fileparts(mfilename('fullpath')));
outDir = fullfile(root,'modern');
if isfile(fullfile(outDir,'PMSM_FOC_R2026a.slx'))
    error('现有主模型已经存在。为保护手工整理和后续算法修改，首次迁移脚本拒绝覆盖；请直接打开主模型。');
end
sourceDir = fullfile(root,'2_PMSM_FOC_MATLAB','PMSM_FOC_SheeperXu');
sourceFile = fullfile(sourceDir,'PMSM_FOC.slx');
mdl = 'PMSM_FOC_R2026a';
cd(outDir);
addpath(sourceDir);
load_system(sourceFile);
stagingDir=fullfile(outDir,'.build');
if ~isfolder(stagingDir), mkdir(stagingDir); end
save_system('PMSM_FOC',fullfile(stagingDir,[mdl '.slx']));

% Embed parameters in the model workspace so opening the model is enough.
parameterCode = fileread(fullfile(sourceDir,'PMSM_FOC_parameters.m'));
parameterCode = regexprep(parameterCode,'(?m)^[ \t]*clear all;[ \t]*\r?$','');
parameterCode = regexprep(parameterCode,'(?m)^[ \t]*clc;[ \t]*\r?$','');
parameterCode = strrep(parameterCode,'fcb=1000 %','fcb=1000; %');
parameterCode = strrep(parameterCode,'fwb=50 %','fwb=50; %');
mws = get_param(mdl,'ModelWorkspace');
mws.DataSource = 'MATLAB Code';
mws.MATLABCode = parameterCode;
reload(mws);

% Snapshot existing signal connections. Rebuild top-level wiring after the
% physical electrical connectors have been replaced by signal connectors.
blocks = find_system(mdl,'SearchDepth',1,'Type','Block');
connections = struct('source',{},'sourceport',{},'dest',{},'destport',{});
for k=1:numel(blocks)
    b=blocks{k}; ph=get_param(b,'PortHandles');
    for j=1:numel(ph.Inport)
        lh=get_param(ph.Inport(j),'Line');
        if lh<=0, continue; end
        sp=get_param(lh,'SrcPortHandle');
        if sp<=0, continue; end
        connections(end+1)=struct('source',get_param(get_param(sp,'Parent'),'Name'), ...
            'sourceport',get_param(sp,'PortNumber'),'dest',get_param(b,'Name'),'destport',j); %#ok<AGROW>
    end
end
lines=find_system(mdl,'FindAll','on','SearchDepth',1,'Type','line');
for k=1:numel(lines)
    try, delete_line(lines(k)); catch, end % A deleted root also deletes branches.
end

machine=sprintf('Permanent Magnet\nSynchronous Machine');
measurement=sprintf('Three-Phase\nV-I Measurement');
clarke=sprintf('abc to\nAlpha-Beta-Zero');
park=sprintf('Alpha-Beta-Zero\nto dq0');
inversePark=sprintf('dq0 to\nAlpha-Beta-Zero');
selector=sprintf('Bus\nSelector');
selectorV=sprintf('Bus\nSelector1');

% Transform convention: amplitude-invariant Clarke, d aligned with phase A,
% q=-alpha*sin(theta)+beta*cos(theta), electrical angle=p*theta_m.
path=replaceSubsystem(mdl,clarke);
add_block('simulink/Sources/In1',[path '/abc'],'Position',[30 65 60 85]);
add_block('simulink/Math Operations/Gain',[path '/Clarke matrix'], ...
    'Gain','[2/3 -1/3 -1/3;0 1/sqrt(3) -1/sqrt(3);1/3 1/3 1/3]', ...
    'Multiplication','Matrix(K*u)','Position',[110 45 260 105]);
add_block('simulink/Sinks/Out1',[path '/alpha_beta_zero'],'Position',[310 65 340 85]);
wire(path,'abc',1,'Clarke matrix',1); wire(path,'Clarke matrix',1,'alpha_beta_zero',1);

path=replaceSubsystem(mdl,park);
transform(path,{'alpha_beta_zero','theta_e'}, ...
    {'u(1)*cos(u(4))+u(2)*sin(u(4))','-u(1)*sin(u(4))+u(2)*cos(u(4))','u(3)'},'dq0');
path=replaceSubsystem(mdl,inversePark);
transform(path,{'dq0','theta_e'}, ...
    {'u(1)*cos(u(4))-u(2)*sin(u(4))','u(1)*sin(u(4))+u(2)*cos(u(4))','u(3)'},'alpha_beta_zero');

path=replaceSubsystem(mdl,'Universal Bridge');
addIn(path,'six_gates',1,[25 35 55 55]);
addIn(path,'Vdc',2,[25 100 55 120]);
add_block('simulink/Signal Attributes/Data Type Conversion',[path '/double gates'], ...
    'OutDataTypeStr','double','Position',[90 30 155 60]);
add_block('simulink/Signal Routing/Mux',[path '/gates_and_bus'],'Inputs','2','Position',[195 40 200 120]);
wire(path,'six_gates',1,'double gates',1);wire(path,'double gates',1,'gates_and_bus',1);
wire(path,'Vdc',1,'gates_and_bus',2);
% Pole voltages are +/-Vdc/2 for complementary gates. Remove floating neutral.
expr={ 'u(7)*(2*(u(1)-u(2))-(u(3)-u(4))-(u(5)-u(6)))/6', ...
       'u(7)*(2*(u(3)-u(4))-(u(1)-u(2))-(u(5)-u(6)))/6', ...
       'u(7)*(2*(u(5)-u(6))-(u(1)-u(2))-(u(3)-u(4)))/6'};
fcnVector(path,'gates_and_bus',expr,{'phase_A','phase_B','phase_C'},'phase_voltage',280);
addOut(path,'Vabc',1,[700 75 730 95]);wire(path,'phase_voltage',1,'Vabc',1);
annotate(path,'Ideal switching bridge: [AH AL BH BL CH CL]. Complementary gates only.\nFloating star neutral; no device losses, dead time or DC-link dynamics.',[50 200]);

path=replaceSubsystem(mdl,machine);
buildMotor(path);

% Measurement vector [ia ib ic wm theta_m Te vq vd] retains original outputs.
path=replaceSubsystem(mdl,selector); vectorSelector(path,1:6);
path=replaceSubsystem(mdl,selectorV); vectorSelector(path,7:8);

path=replaceSubsystem(mdl,measurement);
addIn(path,'Vabc',1,[25 40 55 60]);addIn(path,'Iabc',2,[25 125 55 145]);
fcnVector(path,'Vabc',{'u(1)-u(2)','u(2)-u(3)','u(3)-u(1)'}, ...
    {'Vab','Vbc','Vca'},'line_voltage',120);
addOut(path,'Vab_Vbc_Vca',1,[550 55 580 75]);wire(path,'line_voltage',1,'Vab_Vbc_Vca',1);
addOut(path,'Iabc_measured',2,[550 125 580 145]);wire(path,'Iabc',1,'Iabc_measured',1);
addOut(path,'Vabc_to_motor',3,[550 195 580 215]);wire(path,'Vabc',1,'Vabc_to_motor',1);

replaceSimple(mdl,'DC Voltage Source','simulink/Sources/Constant',{'Value','Vdc'});
replaceSimple(mdl,'Voltage Measurement','simulink/Math Operations/Gain',{'Gain','1'});
delete_block([mdl '/AC Voltage Source']); % Originally unconnected; no applied ripple.
delete_block([mdl '/powergui']);           % No physical-network solver remains.

% DSP toolbox Chirp blocks were monitoring sources, not controller inputs.
for k=1:2
    name=sprintf('Chirp%d',k); path=replaceSubsystem(mdl,name);
    target=500; if k==2, target=5000; end
    add_block('simulink/Sources/Repeating Sequence',[path '/sweep_time'], ...
        'rep_seq_t','[0 10]','rep_seq_y','[0 10]','Position',[30 40 80 70]);
    add_block('simulink/User-Defined Functions/Fcn',[path '/linear_chirp'], ...
        'Expr',sprintf('cos(pi*%g/10*u(1)^2)',target),'Position',[120 40 300 70]);
    add_block('simulink/Discrete/Zero-Order Hold',[path '/sample'], ...
        'SampleTime','dt','Position',[340 40 390 70]);
    addOut(path,'chirp',1,[440 45 470 65]);
    wire(path,'sweep_time',1,'linear_chirp',1);wire(path,'linear_chirp',1,'sample',1);wire(path,'sample',1,'chirp',1);
end

% Restore existing controller and monitoring wiring, remapping load input.
for k=1:numel(connections)
    c=connections(k);
    if strcmp(c.dest,machine), c.destport=2; end
    if getSimulinkBlockHandle([mdl '/' c.source])<=0 || getSimulinkBlockHandle([mdl '/' c.dest])<=0, continue; end
    wire(mdl,c.source,c.sourceport,c.dest,c.destport);
end
wire(mdl,'DC Voltage Source',1,'Universal Bridge',2);
wire(mdl,'DC Voltage Source',1,'Voltage Measurement',1);
wire(mdl,'Universal Bridge',1,measurement,1);
wire(mdl,measurement,3,machine,1);
wire(mdl,machine,2,measurement,2);
add_block('simulink/Signal Routing/Goto',[mdl '/Measured phase currents'], ...
    'GotoTag','Currentabc','TagVisibility','global','Position',[950 320 1060 340]);
wire(mdl,measurement,2,'Measured phase currents',1);

% Make the copy independent of image files without changing PI mathematics.
masked=find_system(mdl,'LookUnderMasks','all','FollowLinks','off','Mask','on');
for k=1:numel(masked)
    display=get_param(masked{k},'MaskDisplay');
    if contains(display,'PI.png')
        set_param(masked{k},'MaskDisplay',sprintf("disp('Discrete PI');\nport_label('input',1,'error');\nport_label('output',1,'out');"));
    elseif contains(display,'SVPWM.png')
        set_param(masked{k},'MaskDisplay',"disp('SVPWM');");
    end
end
set_param(mdl,'SolverType','Fixed-step','Solver','ode4','FixedStep','T', ...
    'StopTime','1','SaveTime','off','SaveOutput','off','SaveState','off', ...
    'SignalLogging','off','ReturnWorkspaceOutputs','on');
% Monitoring only: avoid dividing the speed error by zero at n=0.
set_param([mdl '/Constant11'],'Value','max(abs(0.1*n),1)');
annotate(mdl,'R2026a / MATLAB + Simulink only\nIdeal switching bridge + continuous dq PMSM\nParameters embedded in model workspace. Original FOC retained.',[700 5]);

% Logging at the controller sampling interval, without opening Scope windows.
logPath=[mdl '/Validation logging'];
add_block('built-in/SubSystem',logPath,'Position',[680 1030 865 1085],'BackgroundColor','gray');
% These tags were local in the archived model; the logger is a child system.
for tagBlock={'Goto16','Goto18','Goto19'}
    set_param([mdl '/' tagBlock{1}],'TagVisibility','global');
end
tags={'speed','id','iq','iq_ref','Te','v_alpha','v_beta','SW','UDC','TL','nref'};
for k=1:numel(tags)
    from=['Log ' tags{k}]; sink=['Save ' tags{k}]; y=55*k;
    add_block('simulink/Signal Routing/From',[logPath '/' from], ...
        'GotoTag',tags{k},'Position',[25 y 105 y+20]);
    add_block('simulink/Sinks/To Workspace',[logPath '/' sink], ...
        'VariableName',['log_' tags{k}],'SaveFormat','Timeseries', ...
        'SampleTime','dt','MaxDataPoints','inf','Position',[170 y-5 280 y+25]);
    wire(logPath,from,1,sink,1);
end
add_block('simulink/Signal Routing/Goto',[mdl '/PWM threshold tag'], ...
    'GotoTag','Tcm','TagVisibility','global','Position',[1790 350 1850 370]);
wire(mdl,'SVPWM Function v1.0',1,'PWM threshold tag',1);
add_block('simulink/Signal Routing/From',[logPath '/PWM thresholds'], ...
    'GotoTag','Tcm','Position',[25 680 105 700]);
add_block('simulink/Sinks/To Workspace',[logPath '/Save PWM thresholds'], ...
    'VariableName','log_Tcm','SaveFormat','Timeseries','SampleTime','dt','MaxDataPoints','inf', ...
    'Position',[170 675 280 705]);
wire(logPath,'PWM thresholds',1,'Save PWM thresholds',1);
set_param(mdl,'ZoomFactor','FitSystem');
set_param(mdl,'SimulationCommand','update');
fprintf('\nUPDATE_PASSED\n');
unresolved=find_system(mdl,'LookUnderMasks','all','FollowLinks','off','LinkStatus','unresolved');
assert(isempty(unresolved),'Unresolved library links remain.');
fprintf('UNRESOLVED_LINKS 0\n');
save_system(mdl,fullfile(outDir,[mdl '.slx']));
fprintf('\nMODEL_SAVED %s\n',fullfile(outDir,[mdl '.slx']));
end

function path=replaceSubsystem(mdl,name)
path=[mdl '/' name]; pos=get_param(path,'Position');
delete_block(path);
add_block('built-in/SubSystem',path,'Position',pos,'BackgroundColor','lightBlue');
end

function replaceSimple(mdl,name,library,args)
path=[mdl '/' name]; pos=get_param(path,'Position');delete_block(path);
add_block(library,path,'Position',pos,args{:});
end

function wire(parent,src,sp,dst,dp)
source=get_param([parent '/' src],'PortHandles');dest=get_param([parent '/' dst],'PortHandles');
add_line(parent,source.Outport(sp),dest.Inport(dp),'autorouting','on');
end

function addIn(parent,name,port,position)
add_block('simulink/Sources/In1',[parent '/' name],'Port',num2str(port),'Position',position);
end

function addOut(parent,name,port,position)
add_block('simulink/Sinks/Out1',[parent '/' name],'Port',num2str(port),'Position',position);
end

function annotate(parent,message,position)
a=Simulink.Annotation(parent,sprintf(message));a.Position=position;a.FontSize=12;
end

function transform(path,inputs,expressions,outname)
addIn(path,inputs{1},1,[25 30 55 50]);addIn(path,inputs{2},2,[25 110 55 130]);
add_block('simulink/Signal Routing/Mux',[path '/input_vector'],'Inputs','2','Position',[95 35 100 125]);
wire(path,inputs{1},1,'input_vector',1);wire(path,inputs{2},1,'input_vector',2);
fcnVector(path,'input_vector',expressions,{'axis_1','axis_2','axis_0'},'result',160);
addOut(path,outname,1,[570 85 600 105]);wire(path,'result',1,outname,1);
end

function fcnVector(path,source,expressions,names,muxname,x)
n=numel(expressions);
add_block('simulink/Signal Routing/Mux',[path '/' muxname],'Inputs',num2str(n),'Position',[x+300 30 x+305 30+60*n]);
for k=1:n
    y=30+60*(k-1);
    add_block('simulink/User-Defined Functions/Fcn',[path '/' names{k}], ...
        'Expr',expressions{k},'Position',[x y x+250 y+30]);
    wire(path,source,1,names{k},1);wire(path,names{k},1,muxname,k);
end
end

function vectorSelector(path,indices)
addIn(path,'measurement_vector',1,[25 65 55 85]);
add_block('simulink/Signal Routing/Demux',[path '/signals'],'Outputs','8','Position',[120 20 125 350]);
wire(path,'measurement_vector',1,'signals',1);
for k=1:numel(indices)
    name=sprintf('signal_%d',indices(k));addOut(path,name,k,[250 30+40*k 280 50+40*k]);
    wire(path,'signals',indices(k),name,1);
end
for k=setdiff(1:8,indices)
    name=sprintf('unused_%d',k);
    add_block('simulink/Sinks/Terminator',[path '/' name],'Position',[180 400+20*k 200 420+20*k]);
    wire(path,'signals',k,name,1);
end
end

function buildMotor(path)
addIn(path,'Vabc',1,[25 35 55 55]);addIn(path,'load_torque',2,[25 330 55 350]);
add_block('simulink/Continuous/Integrator',[path '/id_iq_wm_theta'], ...
    'InitialCondition','[0;0;0;0]','Position',[700 220 760 280]);
add_block('simulink/Signal Routing/Mux',[path '/v_state_load'],'Inputs','3','Position',[130 40 135 350]);
wire(path,'Vabc',1,'v_state_load',1);wire(path,'id_iq_wm_theta',1,'v_state_load',2);
wire(path,'load_torque',1,'v_state_load',3);
% Input order: va vb vc id iq wm theta_m Tload.
vd='(2/3)*(u(1)*cos(p*u(7))+u(2)*cos(p*u(7)-2*pi/3)+u(3)*cos(p*u(7)+2*pi/3))';
vq='(-2/3)*(u(1)*sin(p*u(7))+u(2)*sin(p*u(7)-2*pi/3)+u(3)*sin(p*u(7)+2*pi/3))';
te='1.5*p*(phis*u(5)+(Ld-Lq)*u(4)*u(5))';
expr={['(' vd '-Rs*u(4)+p*u(6)*Lq*u(5))/Ld'], ...
      ['(' vq '-Rs*u(5)-p*u(6)*(Ld*u(4)+phis))/Lq'], ...
      ['(' te '-u(8)-F*u(6))/J'],'u(6)'};
fcnVector(path,'v_state_load',expr,{'did_dt','diq_dt','dwm_dt','dtheta_dt'},'derivatives',210);
wire(path,'derivatives',1,'id_iq_wm_theta',1);
% Measurement outputs derive from the continuous states, not current commands.
measure={ 'u(4)*cos(p*u(7))-u(5)*sin(p*u(7))', ...
          'u(4)*cos(p*u(7)-2*pi/3)-u(5)*sin(p*u(7)-2*pi/3)', ...
          'u(4)*cos(p*u(7)+2*pi/3)-u(5)*sin(p*u(7)+2*pi/3)', ...
          'u(6)','u(7)',te,vq,vd};
fcnVector(path,'v_state_load',measure,{'ia','ib','ic','wm','theta_m','Te','vq_actual','vd_actual'},'measurement',900);
addOut(path,'measurement_vector',1,[1280 240 1310 260]);wire(path,'measurement',1,'measurement_vector',1);
add_block('simulink/Signal Routing/Mux',[path '/current_vector'],'Inputs','3','Position',[1235 540 1240 680]);
currentNames={'ia','ib','ic'};
for k=1:3, wire(path,currentNames{k},1,'current_vector',k); end
addOut(path,'Iabc',2,[1280 600 1310 620]);wire(path,'current_vector',1,'Iabc',1);
annotate(path,'Sinusoidal PMSM, floating star, amplitude-invariant dq.\nLd*did/dt=vd-Rs*id+we*Lq*iq\nLq*diq/dt=vq-Rs*iq-we*(Ld*id+phis)\nJ*dwm/dt=Te-Tload-F*wm; dtheta_m/dt=wm\nTe=1.5*p*(phis*iq+(Ld-Lq)*id*iq)',[200 650]);
end
