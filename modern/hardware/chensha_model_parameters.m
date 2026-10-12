% Embedded reference for the CHENSHA 200W nominal firmware profile.
% Source: AxDr_L dev 48d6e86814ac6657b1313b4c92ef24c88f492e07,
% User/config/motor_config.h. Not a measured plant identification.
% This script is embedded into the SLX Model Workspace; no path dependency.
T=1e-6; % Numerical step [s]; switching detail remains ideal/average equivalent
MotorProfile='CHENSHA 200W / firmware profile revision 2';
MotorSourceCommit='48d6e86814ac6657b1313b4c92ef24c88f492e07';
Pn=200; % Nameplate power [W], stored as specified; not forced to equal Tn*wm
Un=24; Vdc=24;
I_rated_rms=11.5; % Phase RMS [A], nameplate
I_peak_rms=23; % Phase RMS [A], nameplate peak
In=sqrt(2)*I_rated_rms; % Phase amplitude / dq nominal current [A]
I_peak=sqrt(2)*I_peak_rms; % Phase amplitude [A]
n=3000; % Speed reference and nominal speed [rpm]
p=5; % Pole pairs
Rs=0.105125; % Phase resistance [ohm], firmware profile convention
Ld=103.7615e-6; Lq=103.7615e-6; Ls=Ld; % dq inductance [H]
phis=0.06/(sqrt(2)*1.5*p); % Flux [Wb], derived from Kt_rms; Ke definition pending
J=32e-6; % Rotor inertia [kg*m^2], profile value; coupled inertia not identified
F=0; % Firmware profile placeholder; does not prove physical friction is zero
Kt=1.5*p*phis; % Torque per dq amplitude [N*m/A]
Tn=0.69; T_peak=1.38; % Nameplate torque [N*m]
Iq_limit=8; % Firmware bench command limit [A], not RMS nameplate current
accel_limit_rad_s2=1200; % Stored only; a command ramp is not implemented here
speed_peak_rad_s=335; % Stored only; speed protection is not implemented here
I_protection_A=10; Vbus_protection_high_V=30; Vbus_protection_low_V=10;
% Protection values above are references, not active trip logic in this model.
RE=10000; rr=2*pi/RE; % Mechanical counts/revolution; ABZ estimator not implemented
encoder_direction=-1; % Stored firmware setting; ideal plant angle stays unchanged
fN=p*n/60; wN=2*pi*fN;
ki_p=0.8; ki_i=1; % Original unused/auxiliary constants retained
fc=20e3; Ts=1/fc; dt=Ts;
Ts_speed=2*dt; % Base speed task 10kHz; current/PWM 20kHz
w_sb=2*pi*fN*1.2;
fcb=1000; fwb=50; wc=2*pi*fcb; wsc=2*pi*fwb;
% fcb/fwb describe the previous gain design, not measured bandwidth of this motor.
K=30/pi; % Mechanical rad/s to rpm
% PI_GAINS_FROZEN: inserted from the validated previous workspace, bit-for-bit.
kp_w=0.00069087230807625508;
ki_w=0.04340878735241975;
ks_w=0.98718608264211138;
kp_id=0.7539822368615503;
ki_id=879.64594300514204;
ks_id=1.1309733552923253;
kp_iq=0.7539822368615503;
ki_iq=879.64594300514204;
ks_iq=1.1309733552923253;
Bm=0;
uplimit_w=Kt*Iq_limit; downlimit_w=-uplimit_w; % Speed PI output is torque [N*m]
% Ld=Lq and id_ref=0, so Te_ref/Kt is exactly the iq demand before dynamics.
uplimit_id=Vdc/sqrt(3); downlimit_id=-uplimit_id;
uplimit_iq=Vdc/sqrt(3); downlimit_iq=-uplimit_iq;
teaching_Ts_speed=Ts_speed; teach_pwm_on=0; teach_pwm_cycles=1;
