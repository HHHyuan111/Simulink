function p=pmsm_q_frequency_plan
% First q-axis lesson is explicitly an ideal locked-rotor electrical test.
p=pmsm_current_frequency_plan;p.axis='q';p.state_column=2;
p.scope='原PMSM固定参考；理想锁轴q轴电流环；速度环给定隔离；周期平均电压+共同1us数值延迟；原PI冻结；非自由转子、非实板标定';
p.injection='原q轴PI误差正端独立注入，取同一误差负端反馈；原速度环输出另行记录但不参与q给定';
p.mechanical_constraint=struct('kind','ideal_locked_rotor','initial_speed_rad_s',0,'initial_angle_rad',0,...
 'implementation','原四状态电机积分器的加速度输入临时接零；保留原电磁转矩及自由加速度计算；结束恢复原连接',...
 'reaction_torque','理想夹具提供反力矩平衡电磁转矩；无夹具柔度、摩擦、热或实际锁轴硬件模型',...
 'claims','只评价零速约束下q轴电气闭环，不能用于证明自由转子或速度环性能');
end
