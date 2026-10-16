function y = fcn(Ealpha, Ebeta)


               theta_est = atan2(-Ealpha,Ebeta);
                if theta_est <= 0
                theta_est = theta_est+2*pi;
                else
                    theta_est = theta_est;
                end
y = theta_est;
