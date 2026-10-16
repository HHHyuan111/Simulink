function [Ualpha_ref,Ubeta_ref] = fcn(id, iq, theta, wr_act, id_ref, iq_ref, Udc, Ld, Lq, Rs, Phif, Pn, Tsc)
    % 存储上一拍的电压指令与限幅值
    persistent Ud_last Uq_last U_max
    if isempty(Ud_last)
        Ud_last = 0;
        Uq_last = 0;
        U_max = Udc/sqrt(3);
    end

    % 电角速度计算
    we = wr_act * (2*pi/60) * Pn;

    %% 1. 第一步预测：观测 k+1 时刻电流
    % 利用 k 时刻采样值和正在执行的 u(k-1) 预估 k+1 时刻状态
    id_k1 = (1 - Rs*Tsc/Ld) * id + (Lq*Tsc*we/Ld) * iq + (Tsc/Ld) * Ud_last;
    iq_k1 = (1 - Rs*Tsc/Lq) * iq - (Tsc*we/Lq) * (Ld*id + Phif) + (Tsc/Lq) * Uq_last;

    %% 2. 第二步预测：求解 k 时刻电压指令 u(k)
    % 目标是使 k+2 时刻电流达到给定值，此处假设 i_ref(k+2) = i_ref(k)
    Ud_raw = Rs * id_k1 + (Ld/Tsc) * (id_ref - id_k1) - we * Lq * iq_k1;
    Uq_raw = Rs * iq_k1 + (Lq/Tsc) * (iq_ref - iq_k1) + we * (Ld * id_k1 + Phif);

    %% 3. 电压矢量限幅
    U_mag = sqrt(Ud_raw^2 + Uq_raw^2);
    if U_mag > U_max
        scale = U_max / U_mag;
        Udout = Ud_raw * scale;
        Uqout = Uq_raw * scale;
    else
        Udout = Ud_raw;
        Uqout = Uq_raw;
    end

    %% 4. 更新持久变量
    % 存入本次计算的指令，供下一拍预测使用
    Ud_last = Udout;
    Uq_last = Uqout;

    %% 5. 坐标变换与角度补偿
    % 考虑采样到执行的延迟，通常补偿 1.5 拍角度
    theta_comp = theta + 1.5 * we * Tsc;
    Ualpha_ref = Udout * cos(theta_comp) - Uqout * sin(theta_comp);
    Ubeta_ref  = Udout * sin(theta_comp) + Uqout * cos(theta_comp);
end