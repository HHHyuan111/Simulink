function [Ualpha_ref,Ubeta_ref,Udout,Uqout] = fcn(id, iq, theta, wr_act, id_ref, iq_ref,Udc,Ld,Lq,Rs,Phif,Pn,Tsc,Udk,Uqk)
    persistent id_est_k Fdk iq_est_k Fqk U_max
    if isempty(id_est_k)
        id_est_k = 0;
        Fdk = 0;
        iq_est_k = 0;
        Fqk = 0;
        U_max = Udc/sqrt(3); % SVPWM线性区最大输出电压
    end
    
    % 计算电角速度
    we = wr_act * (2*pi/60) * Pn;

    w0 = 4000;                       
    alphad = 1 / Ld;                  
    alphaq = 1 / Lq;            
    beta1 = 2 * w0;                  
    beta2 = w0 * w0;
    
    % LESO
    % d轴扩展状态观测器
    erro_id = id_est_k - id;
    id_est_k1 = id_est_k + Tsc * (Fdk + alphad * Udk - beta1 * erro_id);
    Fdk1 = Fdk - Tsc * beta2 * erro_id;
    
    % q轴扩展状态观测器
    erro_iq = iq_est_k - iq;
    iq_est_k1 = iq_est_k + Tsc * (Fqk + alphaq * Uqk - beta1 * erro_iq);
    Fqk1 = Fqk - Tsc * beta2 * erro_iq;
    
    % 控制律计算 
    Ud_raw = ((id_ref - id_est_k1) / Tsc - Fdk1) / alphad;
    Uq_raw = ((iq_ref - iq_est_k1) / Tsc - Fqk1) / alphaq;
    
    % 动态限幅 (防止逆变器饱和) 
    U_mag = sqrt(Ud_raw^2 + Uq_raw^2);
    if U_mag > U_max
        scale = U_max / U_mag;
        Udout = Ud_raw * scale;
        Uqout = Uq_raw * scale;
    else
        Udout = Ud_raw;
        Uqout = Uq_raw;
    end
    
    % 数据存储 
    id_est_k = id_est_k1;
    Fdk = Fdk1;
    iq_est_k = iq_est_k1;
    Fqk = Fqk1;

    % 角度补偿 (1.5拍延时补偿) + 反Park变换
    theta_comp = theta + 1.5 * we * Tsc;
    Ualpha_ref = Udout * cos(theta_comp) - Uqout * sin(theta_comp);
    Ubeta_ref  = Udout * sin(theta_comp) + Uqout * cos(theta_comp);
end