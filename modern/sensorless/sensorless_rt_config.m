function c=sensorless_rt_config(v)
%#codegen
% Fixed numeric configuration interface for generated MATLAB Function blocks.
c.R_hat=v(1);c.L_hat=v(2);c.sample_s=v(3);c.a=v(4);c.b=v(5);
c.g=v(6);c.Kslide_V=v(7);c.boundary_A=v(8);c.observer_pole=v(9);
c.filter_r=v(10);c.pll_Kp=v(11);c.pll_Ki=v(12);c.omega_limit_rad_s=v(13);c.pole_pairs=v(14);
c.interval_convention='rl_weighted_rotating';
c.window_samples=200;c.lock_samples=400;c.unlock_samples=100;
c.validity=struct('emf_on_min_V',v(15),'emf_off_below_V',v(16),...
 'current_residual_vector_rms_max_A',v(17),'pll_phase_error_rms_max',v(18));
end
