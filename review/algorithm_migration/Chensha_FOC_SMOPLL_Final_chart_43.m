function [y,ialpha_est,ibeta_est] = fcn(ialpha,ibeta,ualpha,ubeta)

%%%%%%%%%%%%%%%%%%  position 滑模观测器 idot形式 %%%%%%%%%%%%%%%%%%%% 


persistent ialpha_est_old Ealpha_est_old  ibeta_est_old  Ebeta_est_old Ealpha_est_LPF Ebeta_est_LPF
if isempty(ialpha_est_old)
    ialpha_est_old = 0;
    Ealpha_est_old = 0;
    ibeta_est_old = 0;
    Ebeta_est_old = 0;
    Ealpha_est_LPF = 0;
    Ebeta_est_LPF = 0;
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
                wc =100*2*pi;
             
%                 sat_erro_ialpha = max(min(ialpha_est - ialpha, E0), -E0);  %  饱和函数 

                sat_erro_ialpha =  max(min(ialpha_est - ialpha,5), -5);  %  饱和函数
                Ealpha_est_temp  =  Kslide * sat_erro_ialpha ;                
                Ealpha_est_LPF =Ealpha_est_LPF*1/(1+Tsc*wc) + Ealpha_est_temp *Tsc*wc/(1+Tsc*wc);  % 低通滤波
                Ealpha_est_old = Ealpha_est_LPF;

                
                  
%                 sat_erro_ibeta =  max(min(ibeta_est - ibeta, E0), -E0);  %  饱和函数
%                 sat_erro_ibeta = sign(ibeta_est - ibeta);

                sat_erro_ibeta =  max(min(ibeta_est - ibeta, 5), -5);  %  饱和函数
                Ebeta_est_temp  =  Kslide * sat_erro_ibeta ;  
                Ebeta_est_LPF =Ebeta_est_LPF*1/(1+Tsc*wc) + Ebeta_est_temp *Tsc*wc/(1+Tsc*wc);
                Ebeta_est_old =  Ebeta_est_LPF;
 

                theta_est = atan2(-Ealpha_est_LPF,Ebeta_est_LPF);
                if theta_est <= 0
                theta_est = theta_est+2*pi;
                else
                    theta_est = theta_est;
                end
                theta_out2 = theta_est;
                 


y = theta_out2;
