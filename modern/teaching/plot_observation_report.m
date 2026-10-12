function metrics=plot_observation_report(o,label,folder)
% Separate control-rate observations from numerical-grid switching waveforms.
if nargin<2,label='当前工况';end
if nargin<3,folder=fileparts(mfilename('fullpath'));end
if ~isfolder(folder),mkdir(folder);end
t=o.log_speed.Time;speed=teach_values(o.log_speed);ref=teach_values(o.log_nref);
id=teach_values(o.log_id);iq=teach_values(o.log_iq);ir=teach_values(o.log_iq_ref);dr=teach_values(o.obs_id_ref);state=teach_values(o.obs_state);
truth=teach_values(o.log_iabc_true);meas=teach_values(o.log_iabc_meas);err=meas-truth;
vd=teach_values(o.obs_vd);vq=teach_values(o.obs_vq);vlim=teach_values(o.log_UDC)/sqrt(3);
tail=t>=max(0,t(end)-0.02);
metrics=struct('label',label,'stop_time_s',t(end),'control_log_period_s',median(diff(t)), ...
 'fast_log_period_s',median(diff(o.obs_gates_fast.Time)), ...
 'steady_window_s',[t(find(tail,1)) t(end)], ...
 'speed_error_rms_rpm',sqrt(mean((ref(tail)-speed(tail)).^2)), ...
 'id_tracking_error_rms_A',sqrt(mean((dr(tail)-id(tail)).^2)), ...
 'iq_tracking_error_rms_A',sqrt(mean((ir(tail)-iq(tail)).^2)), ...
 'measurement_error_rms_A',sqrt(mean(err(tail,:).^2,1)), ...
 'peak_iq_A',max(abs(iq)), ...
 'max_voltage_command_ratio',max(hypot(vd,vq)./vlim));
for axis={'speed','d','q'}
 p=teach_values(o.get(['obs_pi_' axis{1}]));metrics.(['pi_' axis{1} '_clipped_sample_fraction'])=mean(abs(p(:,3)-p(:,4))>1e-10);
end
thresholds=teach_values(o.log_Tcm_applied);dt=median(diff(t));duty=1-2*thresholds/dt;
metrics.thresholds_inside_carrier_range=all(thresholds(:)>=-1e-12&thresholds(:)<=dt/2+1e-12);
metrics.notes={'Control logs are synchronous samples, not switching ripple measurements.', ...
 'Cycle-mean-removed phase RMS includes within-cycle fundamental change; not a THD measurement.', ...
 'Power-stage deadtime is an average equivalent; ideal gates remain complementary.'};
algorithmStage2=ismember('obs_voltage',o.who);
if algorithmStage2
 voltage=teach_values(o.obs_voltage);metrics.max_final_voltage_utilization=max(voltage(:,7));metrics.vector_saturation_fraction=mean(voltage(:,8));
 metrics.notes{end+1}='Final dq circle limit uses 0.96*max(Vbus,0)/sqrt(3), after PI plus feedforward.';
else
 metrics.notes{end+1}='Historical model: final vector saturation was not implemented.';
end

f=page('01 跟踪与机械响应',label);
nexttile;plot(t,[ref speed]);decorate('转速跟踪','rpm',{'给定','反馈'});
nexttile;plot(t,ref-speed);decorate('转速误差','rpm',{});
nexttile;plot(t,[dr id state(:,1)]);decorate('d 轴：给定、控制器反馈、真值','A',{'给定','反馈','真值'});
nexttile;plot(t,[ir iq state(:,2)]);decorate('q 轴：给定、控制器反馈、真值','A',{'给定','反馈','真值'});
nexttile;piSpeed=teach_values(o.obs_pi_speed);plot(t,[piSpeed(:,4) teach_values(o.log_Te) teach_values(o.log_TL)]);decorate('转矩关系','N·m',{'指令','电磁转矩','负载'});
nexttile;plot(t,state(:,3));decorate('机械角速度（固件常用单位）','rad/s',{});
finish(f,folder,'observation_tracking.png');

f=page('02 PI 状态与限幅',label);
for axis={'speed','d','q'}
 name=axis{1};p=teach_values(o.get(['obs_pi_' name]));unit='V';if strcmp(name,'speed'),unit='N·m';end
 nexttile;plot(t,p(:,1:2));decorate([name ' 轴 PI 分量'],unit,{'P','I'});
 nexttile;plot(t,p(:,3:4));decorate([name ' 轴限幅前后'],unit,{'限幅前','限幅后'});
end
finish(f,folder,'observation_pi.png');

f=page('03 测量链与误差',label);
nexttile;plot(t,[truth(:,1) meas(:,1)]);xlim(tailRange(t,0.01));decorate('A 相真实 / 测量','A',{'真值','测量'});
nexttile;plot(t,err);xlim(tailRange(t,0.01));decorate('三相测量误差（含滤波滞后）','A',{'A','B','C'});
nexttile;analog=teach_values(o.obs_analog_current);plot(t,[truth(:,1) analog(:,1)]);xlim(tailRange(t,0.01));decorate('采样前模拟通道','A',{'真值','模拟输出'});
nexttile;adc=teach_values(o.log_iabc_adc);flt=teach_values(o.log_iabc_filter);plot(t,[adc(:,1) flt(:,1) meas(:,1)]);xlim(tailRange(t,0.01));decorate('ADC → 数字滤波 → 控制输入','A',{'ADC后','数字滤波后','最终输入'});
nexttile;plot(t,[teach_values(o.log_theta_true) teach_values(o.log_theta_meas)]*180/pi);xlim(tailRange(t,0.01));decorate('电角度','°',{'真值','测量'});
nexttile;plot(t,teach_values(o.log_theta_error)*180/pi);decorate('最短电角误差','°',{});
finish(f,folder,'observation_measurement.png');

tf=o.obs_gates_fast.Time;gates=teach_values(o.obs_gates_fast);carrier=teach_values(o.obs_carrier_fast);
f=page('04 调制、时序与电压裕量',label);
nexttile;plot(t,duty);decorate('理想上管占空比 D = 1 − 2Tcm/Ts','ratio',{'A','B','C'});
nexttile;raw=teach_values(o.log_Tcm_requested);plot(t,[raw(:,1) thresholds(:,1)]*1e6);xlim(tailRange(t,0.001));decorate('A 相指令 / 生效阈值','μs',{'指令','生效'});
nexttile;
if algorithmStage2,plot(t,voltage(:,[6 7]));yline(1,'r--');decorate('请求 / 最终矢量相对可用电压','ratio',{'请求','最终'});
else,plot(t,hypot(vd,vq)./vlim);yline(1,'r--');decorate('电压矢量 / (Vdc/√3)：历史诊断','ratio',{});end
nexttile;stairs(tf,[gates(:,1) gates(:,2)+1.3]);xlim(tailRange(tf,4*dt));yticks([0 1 1.3 2.3]);decorate('A 相门极：T 分辨率，无真实死区空白','logic + offset',{'上管','下管+1.3'});
nexttile;plot(o.obs_carrier_fast.Time,carrier*1e6);hold on;stairs(t,thresholds(:,1)*1e6);xlim(tailRange(tf,4*dt));decorate('载波 / A 相阈值','μs',{'载波','阈值'});
nexttile;stairs(t,teach_values(o.obs_sector));decorate('原 SVPWM 扇区编码','code',{});
finish(f,folder,'observation_modulation.png');

fi=o.obs_current_fast.Time;fastI=teach_values(o.obs_current_fast);fastV=teach_values(o.obs_phase_actual);idealV=teach_values(o.obs_phase_ideal);
assert(isequal(fi,o.obs_phase_actual.Time));
P=sum(fastI.*fastV,2);T=median(diff(fi));samplesPerCycle=round(dt/T);
cycles=floor((numel(fi)-1)/samplesPerCycle);n=cycles*samplesPerCycle;ct=mean(reshape(fi(1:n),samplesPerCycle,cycles),1)';
cycleP=mean(reshape(P(1:n),samplesPerCycle,cycles),1)';vdq=teach_values(o.obs_vdq_fast);cycleV=zeros(cycles,2);
phaseRMS=zeros(cycles,3);
for k=1:2,cycleV(:,k)=mean(reshape(vdq(1:n,k),samplesPerCycle,cycles),1)';end
for k=1:3
 part=reshape(fastI(1:n,k),samplesPerCycle,cycles);phaseRMS(:,k)=sqrt(mean((part-mean(part,1)).^2,1))';
end
last=ct>=max(0,ct(end)-0.02);metrics.mean_motor_electrical_input_W=mean(cycleP(last));
metrics.cycle_demeaned_phase_rms_A=mean(phaseRMS(last,:),1);
f=page('05 功率级与快速波形',label);
nexttile;plot(fi,[idealV(:,1) fastV(:,1)]);xlim(tailRange(fi,4*dt));decorate('A 相理想 / 实际电压','V',{'理想','扣除等效压降后'});
nexttile;plot(o.obs_power_drop.Time,teach_values(o.obs_power_drop));xlim(tailRange(t,0.01));decorate('去共模后的平均压降','V',{'A','B','C'});
nexttile;plot(fi,fastI);xlim(tailRange(fi,4*dt));decorate('三相电流：T 分辨率','A',{'A','B','C'});
nexttile;plot(ct,phaseRMS);decorate('每周期去均值电流 RMS（含基波变化）','A',{'A','B','C'});
nexttile;plot(t,[vd vq]);hold on;plot(ct,cycleV,'--');decorate('指令 / 每 PWM 周期平均实际 dq 电压','V',{'vd 指令','vq 指令','vd 周期均值','vq 周期均值'});
nexttile;plot(ct,cycleP);decorate('每 PWM 周期平均电机电输入功率','W',{});
finish(f,folder,'observation_power.png');
if algorithmStage2
 f=page('06 前馈、最终限压与回算',label);pd=teach_values(o.obs_pi_d);pq=teach_values(o.obs_pi_q);ad=teach_values(o.obs_aw_d);aq=teach_values(o.obs_aw_q);
 nexttile;plot(t,[pd(:,4) voltage(:,1)-pd(:,4) voltage(:,1) voltage(:,3)]);decorate('d轴电压链','V',{'PI','前馈','请求','最终'});
 nexttile;plot(t,[pq(:,4) voltage(:,2)-pq(:,4) voltage(:,2) voltage(:,4)]);decorate('q轴电压链','V',{'PI','前馈','请求','最终'});
 nexttile;plot(t,voltage(:,[6 7 8]));yline(1,'r--');decorate('电压利用率与饱和标志','ratio / logic',{'请求','最终','饱和'});
 nexttile;plot(t,[pd(:,2) pq(:,2)]);decorate('积分器状态','V',{'d','q'});
 nexttile;plot(t,[ad(:,1) aq(:,1)]);decorate('最终残差：Vfinal − Vrequest','V',{'d','q'});
 nexttile;plot(t,[ad(:,2) aq(:,2)]);decorate('合并回算修正：乘Ki后进入积分器','A',{'d','q'});
 finish(f,folder,'observation_voltage_limit.png');
end
end

function f=page(titleText,label)
f=figure('Visible','off','Color','white','Position',[50 50 1400 1000]);
set(f,'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei','DefaultAxesFontSize',10);
tiledlayout(3,2,'TileSpacing','compact','Padding','compact');sgtitle([titleText ' | ' label ' | 参数与局限见记录'],'FontName','Microsoft YaHei');
end
function decorate(titleText,unit,labels)
grid on;title(titleText,'Interpreter','none');xlabel('时间 [s]');ylabel(unit,'Interpreter','none');if ~isempty(labels),legend(labels,'Location','best');end
end
function r=tailRange(t,width),r=[max(t(1),t(end)-width) t(end)];end
function finish(f,folder,name),exportgraphics(f,fullfile(folder,name),'Resolution',130);close(f);end
