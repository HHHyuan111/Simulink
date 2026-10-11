function validate_pmsm_r2026a
% Closed-loop, sign, disturbance and integration-convergence checks.
% This function works in a fresh MATLAB session, without running parameters.
folder=fileparts(mfilename('fullpath'));cd(folder);
mdl='PMSM_FOC_R2026a';load_system(fullfile(folder,[mdl '.slx']));
set_param(mdl,'SimulationCommand','update');
unresolved=find_system(mdl,'LookUnderMasks','all','FollowLinks','off','LinkStatus','unresolved');
assert(isempty(unresolved),'Unresolved library references.');
fprintf('START_CLOSED_LOOP_VALIDATION\n');
loadBlocks=find_system(mdl,'LookUnderMasks','all','FollowLinks','off','BlockType','Step','Name','T_load1');
assert(numel(loadBlocks)==1,'Expected one load-torque input.');
loadPath=loadBlocks{1};
specs={ 'default_1s',3000,'1','0','0.3*Tn','0.3*Tn','T'; ...
        'zero_command',0,'0.08','0','0','0','T'; ...
        'reverse',-1500,'0.2','0','-0.3*Tn','-0.3*Tn','T'; ...
        'load_step',3000,'0.2','0.08','0.3*Tn','0.6*Tn','T'; ...
        'half_solver_step',3000,'0.2','0','0.3*Tn','0.3*Tn','5e-7'};
resultCells=cell(size(specs,1),1);outputs=cell(size(specs,1),1);
for k=1:size(specs,1)
    in=Simulink.SimulationInput(mdl);
    in=setVariable(in,'n',specs{k,2},'Workspace',mdl);
    in=setModelParameter(in,'StopTime',specs{k,3},'FixedStep',specs{k,7});
    in=setBlockParameter(in,loadPath,'Time',specs{k,4});
    in=setBlockParameter(in,loadPath,'Before',specs{k,5});
    in=setBlockParameter(in,loadPath,'After',specs{k,6});
    fprintf('RUN %s\n',specs{k,1});t0=tic;
    out=sim(in);outputs{k}=out;
    r=summarize(out);r.name=specs{k,1};r.target_rpm=specs{k,2};r.wall_seconds=toc(t0);
    r.tracking_error_rpm=abs(r.speed_mean_last_20ms-r.target_rpm);
    r.passed=r.finite && r.complementary_gates && r.thresholds_valid && r.tracking_error_rpm<5;
    resultCells{k}=r;
    fprintf('RESULT %s: speed %.6f rpm, error %.6f rpm, passed %d\n',r.name,r.speed_mean_last_20ms,r.tracking_error_rpm,r.passed);
end
results=[resultCells{:}];
% Torque balance includes viscous friction, independently of PI output.
expectedTorque=0.3*0.29808+0.0001*(3000*pi/30);
torqueBalanceError=abs(results(1).torque_mean_last_20ms-expectedTorque);
convergenceError=abs(results(5).speed_mean_last_20ms-results(1).speed_mean_last_20ms);
summary=struct('matlab',version,'unresolved_links',numel(unresolved), ...
    'scenarios',results,'expected_steady_torque_Nm',expectedTorque, ...
    'torque_balance_error_Nm',torqueBalanceError, ...
    'half_step_speed_difference_rpm',convergenceError, ...
    'all_passed',all([results.passed]) && torqueBalanceError<0.015 && convergenceError<5);
fid=fopen(fullfile(folder,'validation_results.json'),'w','n','UTF-8');
fprintf(fid,'%s',jsonencode(summary,PrettyPrint=true));fclose(fid);
out=outputs{1};save(fullfile(folder,'validation_results.mat'),'out','summary','-v7');
idx=1:20:numel(out.log_speed.Time);
writetable(table(out.log_speed.Time(idx),double(out.log_speed.Data(idx)),double(out.log_id.Data(idx)), ...
    double(out.log_iq.Data(idx)),double(out.log_Te.Data(idx)), ...
    'VariableNames',{'time_s','speed_rpm','id_A','iq_A','Te_Nm'}),fullfile(folder,'validation_default.csv'));
makePlot(outputs{1},outputs{4},folder);
disp(summary);
assert(summary.all_passed,'Validation failed; inspect validation_results.json.');
fprintf('ALL_VALIDATION_PASSED\n');
end

function r=summarize(out)
speed=out.log_speed;id=out.log_id;iq=out.log_iq;te=out.log_Te;threshold=out.log_Tcm;gate=out.log_SW;
tail=speed.Time>=speed.Time(end)-0.02;
r=struct;
r.stop_time_s=speed.Time(end);r.speed_final=double(speed.Data(end));
r.speed_mean_last_20ms=mean(double(speed.Data(tail)));
r.speed_min=min(double(speed.Data));r.speed_max=max(double(speed.Data));
r.id_peak=max(abs(double(id.Data(:))));r.iq_peak=max(abs(double(iq.Data(:))));
r.torque_mean_last_20ms=mean(double(te.Data(tail)));
r.threshold_min=min(double(threshold.Data(:)));r.threshold_max=max(double(threshold.Data(:)));
r.finite=all(isfinite([speed.Data(:);id.Data(:);iq.Data(:);te.Data(:);threshold.Data(:)]));
g=reshape(double(gate.Data),[],6);
r.complementary_gates=all(g(:,1)+g(:,2)==1 & g(:,3)+g(:,4)==1 & g(:,5)+g(:,6)==1);
r.thresholds_valid=r.threshold_min>=-1e-12 && r.threshold_max<=25e-6+1e-12;
end

function makePlot(base,step,folder)
fig=figure('Visible','off','Position',[100 100 1200 800],'Color','white');
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
nexttile;plot(base.log_speed.Time,base.log_speed.Data,'LineWidth',1.2);hold on;yline(3000,'--');
xlim([0 0.2]);grid on;xlabel('Time (s)');ylabel('Speed (rpm)');title('Default: 3000 rpm command');
nexttile;plot(base.log_id.Time,base.log_id.Data,base.log_iq.Time,base.log_iq.Data,'LineWidth',1);
xlim([0 0.2]);grid on;xlabel('Time (s)');ylabel('Current (A)');legend('i_d','i_q');title('Original discrete current controllers');
nexttile;plot(step.log_speed.Time,step.log_speed.Data,'LineWidth',1.2);hold on;xline(0.08,'--');
grid on;xlabel('Time (s)');ylabel('Speed (rpm)');title('Load step: 0.3 T_n to 0.6 T_n at 0.08 s');
nexttile;plot(step.log_Te.Time,step.log_Te.Data,step.log_TL.Time,step.log_TL.Data,'LineWidth',1);
grid on;xlabel('Time (s)');ylabel('Torque (N m)');legend('Electromagnetic','Load');title('Torque response; viscous friction retained');
sgtitle('PMSM FOC / R2026a / MATLAB + Simulink only');
exportgraphics(fig,fullfile(folder,'validation_waveforms.png'),'Resolution',130);
close(fig);
end
