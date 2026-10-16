function [Ualpha_ref,Ubeta_ref]  = fcn(id, iq, theta, wr_act, id_ref, iq_ref,Udc,Ld,Lq,Rs,Phif,Pn,Tsc)
    persistent int_d int_q Kp Ki U_max 
    if isempty(int_d)
        int_d = 0;
        int_q = 0;
        U_max = Udc/sqrt(3);
    end
    
        Kp = Ld/4/Tsc;
        Ki = Rs/3/Tsc;

    we = wr_act * (2*pi/60) * Pn;
    
    err_d = id_ref - id;
    err_q = iq_ref - iq;
    
    int_d = int_d + Ki * err_d * Tsc;
    int_q = int_q + Ki * err_q * Tsc;

    %%%%%%%%% 积分限幅 %%%%%%%%%%%%
    if int_d > U_max 
        int_d = U_max;
    elseif int_d < -U_max
        int_d = -U_max;
    else
    end

    if int_q > U_max 
        int_q = U_max;
    elseif int_q < -U_max
        int_q = -U_max;
    else
    end

    %%%%%%%%%%% PI 输出 %%%%%%%%%%%
    Ud_raw = Kp * err_d + int_d;
    Uq_raw = Kp * err_q + int_q;
    
    
    U_mag = sqrt(Ud_raw^2 + Uq_raw^2);
    if U_mag > U_max
        scale = U_max / U_mag;
        Udout = Ud_raw * scale;
        Uqout = Uq_raw * scale;
    else
        Udout = Ud_raw;
        Uqout = Uq_raw;
    end
    
    theta_comp = theta + 1.5 * we * Tsc;
    Ualpha_ref = Udout * cos(theta_comp) - Uqout * sin(theta_comp);
    Ubeta_ref  = Udout * sin(theta_comp) + Uqout * cos(theta_comp);
end