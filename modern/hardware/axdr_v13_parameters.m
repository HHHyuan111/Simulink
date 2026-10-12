function p = axdr_v13_parameters()
%AXDR_V13_PARAMETERS Schematic/firmware reference; does not modify any model.
% Values are nominal, not calibrated measurements. Read the companion review:
% review/learning/AxDr原理图与仿真对照.md
% NaN means unverified; never substitute it into a running model silently.

p.source.schematic_path = 'D:/浏览器下载/SCH_axdr_v1.3_2026-09-18 (2).pdf';
p.source.schematic_sha256 = 'e6466bb27ed6432cbbeb01eaee8d4b32a95092ee7fc8bca213aa6bde8dc8d65b';
p.source.schematic_sheet = 'P1, axdr_v1.3, title date 2025-03-23';
p.source.firmware_commit = '48d6e86814ac6657b1313b4c92ef24c88f492e07';
p.source.review_date = '2026-10-11';
p.source.status = 'nominal reference only; not an applied or calibrated profile';

p.adc.reference_V = 3.3; % U4 AVCC; actual supply/reference not measured
p.adc.bits = 12;        % Core/Src/adc.c
p.adc.levels = 2^p.adc.bits;
p.adc.maximum_code = p.adc.levels-1;
p.adc.voltage_lsb_V = p.adc.reference_V/p.adc.levels;

p.current.topology = 'three low-side shunts plus one return-bus shunt';
p.current.phase_shunt_refs = {'R81','R82','R83'};
p.current.bus_shunt_ref = 'R109';
p.current.shunt_ohm = 0.001;
p.current.input_resistor_ohm = 1000;   % A: R67/R69; B: R68/R72; C: R45/R52
p.current.feedback_resistor_ohm = 20000; % A: R65/R71; B: R66/R74; C: R42/R55
p.current.gain = p.current.feedback_resistor_ohm/p.current.input_resistor_ohm;
p.current.bias_nominal_V = p.adc.reference_V/2; % U6 buffer, R46/R57 divider option
p.current.zero_code_nominal = p.adc.levels/2;
p.current.calibrated_zero_codes = [NaN NaN NaN];
p.current.output_series_ohm = 22; % R70/R73/R53; IBUS R50
p.current.output_cap_F = 1e-9;    % C67/C68/C62; IBUS C61
p.current.output_rc_tau_s = p.current.output_series_ohm*p.current.output_cap_F;
p.current.output_rc_pole_Hz = 1/(2*pi*p.current.output_rc_tau_s);
p.current.lsb_A = p.adc.voltage_lsb_V/(p.current.shunt_ohm*p.current.gain);
p.current.nominal_half_span_A = p.current.bias_nominal_V/(p.current.shunt_ohm*p.current.gain);
p.current.decoded_code_limits_A = ([0 p.adc.maximum_code]-p.current.zero_code_nominal)*p.current.lsb_A;
p.current.output_rc_is_complete_frontend_bandwidth = false;
p.current.amplifier_part = 'unlabelled U10';
p.current.amplifier_bandwidth_Hz = NaN;
p.current.analogue_noise_rms_A = NaN;
p.current.settling_guard_s = NaN;
p.current.model_to_firmware_current_sign = NaN;
p.current.validity_note = 'Phase current is observable only while the relevant low-side path carries it and the front end has settled.';

p.voltage.high_resistors_ohm = [10000 10000];
p.voltage.low_resistor_ohm = 1000;
p.voltage.division_ratio = (sum(p.voltage.high_resistors_ohm)+p.voltage.low_resistor_ohm)/p.voltage.low_resistor_ohm;
p.voltage.thevenin_ohm = 1/(1/sum(p.voltage.high_resistors_ohm)+1/p.voltage.low_resistor_ohm);
p.voltage.lsb_V = p.adc.voltage_lsb_V*p.voltage.division_ratio;
p.voltage.nominal_full_scale_V = p.adc.reference_V*p.voltage.division_ratio;
p.voltage.maximum_decoded_V = p.adc.maximum_code*p.voltage.lsb_V;
p.voltage.phase.cap_refs = {'C75','C76','C77'};
p.voltage.phase.cap_F = 1e-6;
p.voltage.phase.tau_s = p.voltage.thevenin_ohm*p.voltage.phase.cap_F;
p.voltage.phase.pole_Hz = 1/(2*pi*p.voltage.phase.tau_s);
p.voltage.phase.reference = 'MA/MB/MC to board ground, not motor neutral or line-to-line voltage';
p.voltage.bus.cap_ref = 'C78';
p.voltage.bus.cap_F = 100e-9;
p.voltage.bus.tau_s = p.voltage.thevenin_ohm*p.voltage.bus.cap_F;
p.voltage.bus.pole_Hz = 1/(2*pi*p.voltage.bus.tau_s);

% Firmware-derived nominal timing. Excludes trigger synchronization,
% preemption of regular ADC activity, ISR entry, computation and register writes.
p.timing.timer_clock_Hz = 160e6;
p.timing.arr = 4000;
p.timing.pwm_Hz = p.timing.timer_clock_Hz/(2*p.timing.arr);
p.timing.pwm_period_s = 1/p.timing.pwm_Hz;
p.timing.ccr4 = 3900;
p.timing.adc_trigger = 'TIM1_CC4 falling edge; exact routed event phase needs verification';
p.timing.adc_clock_Hz = 40e6;
p.timing.sample_cycles = 47.5;
p.timing.conversion_cycles = 12.5; % ST STM32G4-Analog-ADC, Conversion time
p.timing.sample_aperture_s = p.timing.sample_cycles/p.timing.adc_clock_Hz;
p.timing.rank_interval_s = (p.timing.sample_cycles+p.timing.conversion_cycles)/p.timing.adc_clock_Hz;
p.timing.rank_phase = {'C','B','A'};
p.timing.rank_sample_start_s = (0:2)*p.timing.rank_interval_s;
p.timing.rank_hold_estimate_s = p.timing.rank_sample_start_s+p.timing.sample_aperture_s;
p.timing.rank_complete_estimate_s = (1:3)*p.timing.rank_interval_s;
p.timing.sequence_complete_estimate_s = p.timing.rank_complete_estimate_s(end);
p.timing.speed_divider = 2;
p.timing.speed_Hz = p.timing.pwm_Hz/p.timing.speed_divider;
p.timing.ccr_preload_enabled_in_hal = true; % stm32g4xx_hal_tim.c HAL_TIM_PWM_ConfigChannel
p.timing.compute_time_s = NaN;
p.timing.trigger_to_actuation_s = NaN;
p.timing.runtime_verified = false;

p.power.deadtime_dtg = 80;
p.power.deadtime_programmed_s = p.power.deadtime_dtg/p.timing.timer_clock_Hz; % CKD=1, linear DTG region
p.power.driver_supply_nominal_V = 12;
p.power.driver_part = 'unlabelled U7';
p.power.mosfet_part = 'unlabelled Q5-Q10';
p.power.rds_on_ohm = NaN;
p.power.diode_forward_V = NaN;
p.power.driver_propagation_s = NaN;
p.power.gate_series_ohm = 22;
p.power.gate_shunt_cap_F = 1e-9;
p.power.gate_pulldown_ohm = 10000;
p.power.bootstrap_cap_F = 1e-6;
% Explicit main banks only: C3/C4, C5-C15, C96-C104.
% Excludes upstream C16/C17 and auxiliary converter input/other small branches.
p.power.main_bank_nominal_F = 2*220e-6+(11+9)*10e-6;
p.power.capacitance_effective_F = NaN; % assembly, bias derating, ESR/ESL unknown
p.power.source_impedance_ohm = NaN;

p.pin.current_ABC = {'PA2 ADC1_IN3 JDR3','PA1 ADC1_IN2 JDR2','PA0 ADC1_IN1 JDR1'};
p.pin.phase_voltage_ABC = {'PC0 ADC2_IN6','PC1 ADC2_IN7','PC2 ADC2_IN8'};
p.pin.bus_voltage = 'PC5 ADC2_IN11 JDR1';
p.pin.upper_pwm_ABC = {'PA8 TIM1_CH1','PA9 TIM1_CH2','PA10 TIM1_CH3'};
p.pin.lower_pwm_ABC = {'PB13 TIM1_CH1N','PB14 TIM1_CH2N','PB15 TIM1_CH3N'};
p.pin.encoder_shared_nets = {'PA6 HALL_A','PA7 HALL_B','PB0 HALL_C'};
end
