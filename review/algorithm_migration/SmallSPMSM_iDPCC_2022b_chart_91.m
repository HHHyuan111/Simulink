function [Ualpha_ref,Ubeta_ref] = fcn(id, iq, theta, wr_act, id_ref, iq_ref, Udc, Ld, Lq, Rs, Phif, Pn, Tsc)
    % =========================================================================
    % 基于增量模型的无差拍预测电流控制 (Incremental DPCC)
    persistent id_last iq_last Ud_last Uq_last delta_Ud_last delta_Uq_last U_max
    
    if isempty(id_last)
        id_last = id;  % 初始时刻假设上一拍电流等于当前电流
        iq_last = iq;
        Ud_last = 0;
        Uq_last = 0;
        delta_Ud_last = 0;
        delta_Uq_last = 0;
        U_max = Udc/sqrt(3);
    end

    % 电角速度计算
    we = wr_act * (2*pi/60) * Pn;

    delta_id_k = id - id_last;
    delta_iq_k = iq - iq_last;

    % 预估 k+1 时刻的电流增量与绝对值
    % 驱动电流从 k 到 k+1 变化的是上一拍算出的电压增量 delta_Ud_last
    delta_id_k1 = (1 - Rs*Tsc/Ld) * delta_id_k + (Lq*Tsc*we/Ld) * delta_iq_k + (Tsc/Ld) * delta_Ud_last;
    delta_iq_k1 = (1 - Rs*Tsc/Lq) * delta_iq_k - (Ld*Tsc*we/Lq) * delta_id_k + (Tsc/Lq) * delta_Uq_last;

    % 累加得到 k+1 时刻的绝对电流预测值
    id_k1 = id + delta_id_k1;
    iq_k1 = iq + delta_iq_k1;

    % 求解 k 时刻所需的电压增量 delta_u(k)
    delta_Ud_k = (Ld/Tsc)*(id_ref - id_k1) - (Ld/Tsc - Rs)*delta_id_k1 - we*Lq*delta_iq_k1;
    delta_Uq_k = (Lq/Tsc)*(iq_ref - iq_k1) - (Lq/Tsc - Rs)*delta_iq_k1 + we*Ld*delta_id_k1;

    % 合成实际输出电压
    Ud_raw = Ud_last + delta_Ud_k;
    Uq_raw = Uq_last + delta_Uq_k;

    % 电压矢量限幅与积分抗饱和
    U_mag = sqrt(Ud_raw^2 + Uq_raw^2);
    if U_mag > U_max
        scale = U_max / U_mag;
        Udout = Ud_raw * scale;
        Uqout = Uq_raw * scale;
        
        delta_Ud_k = Udout - Ud_last;
        delta_Uq_k = Uqout - Uq_last;
    else
        Udout = Ud_raw;
        Uqout = Uq_raw;
    end

    id_last = id;
    iq_last = iq;
    Ud_last = Udout;
    Uq_last = Uqout;
    delta_Ud_last = delta_Ud_k;
    delta_Uq_last = delta_Uq_k;

    % 补偿 1.5 拍的延迟角度
    theta_comp = theta + 1.5 * we * Tsc;
    Ualpha_ref = Udout * cos(theta_comp) - Uqout * sin(theta_comp);
    Ubeta_ref  = Udout * sin(theta_comp) + Uqout * cos(theta_comp);
end