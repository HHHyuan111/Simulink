% Append after existing timing InitFcn. Defaults preserve the timing baseline.
dead_m=bdroot;dead_ws=get_param(dead_m,'ModelWorkspace');dead_path=[dead_m '/功率设置'];
dead_gate=double(strcmp(get_param(dead_path,'gate_on'),'on'));
dead_comp=double(strcmp(get_param(dead_path,'comp_on'),'on'));
dead_dt=str2double(get_param(dead_path,'gate_us'))*1e-6;
dead_ct=str2double(get_param(dead_path,'comp_us'))*1e-6;
dead_band=str2double(get_param(dead_path,'hysteresis_A'));
dead_zero=str2double(get_param(dead_path,'zero_A'));
validateattributes([dead_dt dead_ct dead_band dead_zero],{'double'},{'real','finite','nonnegative'});
assert(~dead_comp||dead_gate,'先启用门极死区，再启用补偿，避免给理想桥额外施加电压误差。');
assert(~dead_gate||strcmp(get_param(dead_path,'dead_on'),'off'),'真实门极死区与旧平均死区压降互斥，避免重复计算。');
dead_step=getVariable(dead_ws,'timing_h');
if dead_gate
 assert(abs(getVariable(dead_ws,'Ld')-getVariable(dead_ws,'Lq'))<1e-12,'本轮近零续流模型适用于当前Ld=Lq的PMSM。');
 dead_step=min(dead_step,62.5e-9);
 assert(dead_dt<getVariable(dead_ws,'Ts')/4,'死区应小于PWM周期的四分之一。');
 assert(abs(dead_dt/dead_step-round(dead_dt/dead_step))<1e-7,'门极死区必须落在事件网格上。');
 assignin(dead_ws,'timing_h',dead_step);
end
dead_drop=double(strcmp(get_param(dead_path,'drop_on'),'on'));
assignin(dead_ws,'dead_gate_on',dead_gate);assignin(dead_ws,'dead_h',dead_step);
assignin(dead_ws,'dead_gate_cfg',[dead_gate dead_step dead_dt]);
assignin(dead_ws,'dead_comp_cfg',[dead_comp dead_ct getVariable(dead_ws,'Ts') dead_band]);
assignin(dead_ws,'dead_bridge_cfg',[getVariable(dead_ws,'p') getVariable(dead_ws,'phis') dead_zero dead_drop ...
 str2double(get_param(dead_path,'ron')) str2double(get_param(dead_path,'vf'))]);
set_param(dead_m,'FixedStep','timing_h');
