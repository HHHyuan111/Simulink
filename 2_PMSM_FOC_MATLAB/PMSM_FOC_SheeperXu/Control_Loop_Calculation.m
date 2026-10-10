%------------------------------------------------------------
% Control Loop Calculation of PMSM_FOC_AEEICWork 2023/11
%------------------------------------------------------------

%% Current Control Loop
s=tf('s');
Gsc=(kp_id+ki_id/s)*(1/(Rs+Ld*s));
P=bodeoptions;
P.Title.String={["Bode Diagram For Designed Speed Control Loop"]};
P.Grid='on';
P.FreqUnits='Hz';
figure(1);
bode(Gsc,P);
[gpeak,fpeak] = getPeakGain(Gsc);
gpeak_dB = 20*log10(gpeak)
fpeak_hz = fpeak/(2*pi)

%% Speed Control Loop
s=tf('s');
Gsc=(kp_w+ki_w/s)*(wc/(s+wc))*K/J/s;
P=bodeoptions;
P.Title.String={["Bode Diagram For Designed Speed Control Loop"]};
P.Grid='on';
P.FreqUnits='Hz';
figure(1);
bode(Gsc,P);
[gpeak,fpeak] = getPeakGain(Gsc);
gpeak_dB = 20*log10(gpeak)
fpeak_hz = fpeak/(2*pi)