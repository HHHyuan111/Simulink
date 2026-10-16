function[id_ref_out,iq_ref_out] = fcn(wr,wr_ref)

persistent Kp_speed Ki_speed wr_inter_old Tsc 
if isempty(Kp_speed)
wr_inter_old = 0;  % 转速环PI积分回路储存值
Kp_speed =0.3;    % 转速环PI参数
Ki_speed =10;
Tsc = 0.0001;
end 
iq_limit = 11.5;

% %%%%%%%%%%%%%%%%%%%%  speed loop %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
erro_wr = wr_ref - wr ;                             %转速环PI调节器
wr_inter_old = wr_inter_old + Ki_speed*erro_wr*Tsc;
iq_ref = Kp_speed*erro_wr + wr_inter_old; 
if wr_inter_old>=iq_limit                           %% 积分限幅值
   wr_inter_old = iq_limit;
elseif wr_inter_old <=-iq_limit
    wr_inter_old  = -iq_limit;
end

if iq_ref>=iq_limit                                 %% 转速环限幅值
   iq_ref = iq_limit;
elseif iq_ref<=-iq_limit
    iq_ref = -iq_limit;
end
id_ref = 0;


iq_ref_out = iq_ref;
id_ref_out = id_ref;