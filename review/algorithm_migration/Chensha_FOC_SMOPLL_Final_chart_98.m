function [theta_out,we_out,ialpha_est,ibeta_est] = fcn(ialpha,ibeta,ualpha,ubeta)

%%%%%%%%%%%%%%%%%%  position 滑模观测器 idot形式 %%%%%%%%%%%%%%%%%%%% 


persistent ialpha_est_old Ealpha_est_old  ibeta_est_old  Ebeta_est_old Ealpha_est_LPF Ebeta_est_LPF 
persistent omega_est_old theta_pll_old integral_pll_old
if isempty(ialpha_est_old)
    ialpha_est_old = 0;
    Ealpha_est_old = 0;
    ibeta_est_old = 0;
    Ebeta_est_old = 0;
    Ealpha_est_LPF = 0;
    Ebeta_est_LPF = 0;
    omega_est_old = 0;
    integral_pll_old = 0;
    theta_pll_old = 0;
end



              Ld = 5.25e-3;
              Rs = 0.958;
              Tsc = 1e-6;

              Ualpha_old = ualpha;
              Ubeta_old = ubeta;

                ialpha_dot = - Rs * ialpha_est_old /Ld + Ualpha_old/Ld  -  Ealpha_est_old /Ld  ;
                ialpha_est = ialpha_est_old + ialpha_dot*Tsc;
                ialpha_est_old = ialpha_est;

                ibeta_dot = - Rs * ibeta_est_old /Ld  + Ubeta_old /Ld  -  Ebeta_est_old /Ld ; 
                ibeta_est = ibeta_est_old + ibeta_dot*Tsc;
                ibeta_est_old = ibeta_est;
                
                E0 = 10;
                Kslide = 200;                
                wc =200*2*pi;
             

                sat_erro_ialpha =  max(min(ialpha_est - ialpha,1), -1);  %  饱和函数
                Ealpha_est_temp  =  Kslide * sat_erro_ialpha ;                
                Ealpha_est_LPF =Ealpha_est_LPF*1/(1+Tsc*wc) + Ealpha_est_temp *Tsc*wc/(1+Tsc*wc);  % 低通滤波
                Ealpha_est_old = Ealpha_est_LPF;

              
                sat_erro_ibeta =  max(min(ibeta_est - ibeta, 1), -1);  %  饱和函数
                Ebeta_est_temp  =  Kslide * sat_erro_ibeta ;  
                Ebeta_est_LPF =Ebeta_est_LPF*1/(1+Tsc*wc) + Ebeta_est_temp *Tsc*wc/(1+Tsc*wc);
                Ebeta_est_old =  Ebeta_est_LPF;
 


                Kp_pll =15;   % PLL比例系数
                Ki_pll = 1500; % PLL积分系数
                
                pll_err = -Ealpha_est_LPF * cos(theta_pll_old) - Ebeta_est_LPF * sin(theta_pll_old);
                
                proportional = Kp_pll * pll_err;                
                integral_pll = integral_pll_old + Ki_pll * pll_err * Tsc; 
                omega_est = proportional + integral_pll;       
                
                omega_est = max(min(omega_est, 2000), -2000);  % 角速度限幅
                
                theta_est = theta_pll_old + omega_est * Tsc;
                
                % 5. 角度限幅 0~2π
                if theta_est <= 0
                    theta_est = theta_est + 2*pi;
                elseif theta_est > 2*pi
                    theta_est = theta_est - 2*pi;
                end
                
                % 6. 更新PLL历史变量
                theta_pll_old = theta_est;
                omega_est_old = omega_est;
                %% ===================== PLL替换完成 =====================
                
                theta_out = theta_est;
                we_out = omega_est;
