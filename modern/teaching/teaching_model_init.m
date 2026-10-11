% Embedded verbatim in the model InitFcn; no helper file is needed to run SLX.
teach_model = bdroot;
teach_workspace = get_param(teach_model,'ModelWorkspace');
teach_cfg_path = [teach_model '/时序设置'];
teach_divider = str2double(get_param(teach_cfg_path,'speed_divider'));
teach_cycles = str2double(get_param(teach_cfg_path,'pwm_cycles'));
validateattributes(teach_divider,{'double'},{'scalar','real','finite','integer','>=',1,'<=',1000});
validateattributes(teach_cycles,{'double'},{'scalar','real','finite','integer','>=',1,'<=',20});
teach_dt = getVariable(teach_workspace,'dt');
teach_period = getVariable(teach_workspace,'Ts_speed');
if strcmp(get_param(teach_cfg_path,'speed_on'),'on')
    teach_period = teach_dt*teach_divider;
end
assert(teach_period >= teach_dt && abs(teach_period/teach_dt-round(teach_period/teach_dt))<1e-9, ...
    '速度环周期必须为电流控制周期的正整数倍。');
teach_names = {'teaching_Ts_speed','teach_pwm_on','teach_pwm_cycles'};
teach_values_to_set = {teach_period,double(strcmp(get_param(teach_cfg_path,'pwm_on'),'on')),teach_cycles};
for teach_index = 1:numel(teach_names)
    if ~isequaln(getVariable(teach_workspace,teach_names{teach_index}),teach_values_to_set{teach_index})
        assignin(teach_workspace,teach_names{teach_index},teach_values_to_set{teach_index});
    end
end
