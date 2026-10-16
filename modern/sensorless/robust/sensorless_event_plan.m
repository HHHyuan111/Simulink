function p=sensorless_event_plan(cycle,release_jitter_s,interference_s,c)
%#codegen
% Observer executes before FOC. Guard reserves slack; it is not CPU time.
assert(isscalar(cycle)&&isfinite(cycle)&&cycle>=0&&cycle==floor(cycle));
assert(isscalar(release_jitter_s)&&isfinite(release_jitter_s)&&release_jitter_s>=0);
assert(isscalar(interference_s)&&isfinite(interference_s)&&interference_s>=0);
N=round(c.period_s/c.h_s);base=cycle*N;
trigger=round((c.adc_trigger_s+c.adc_sync_s)/c.h_s);rank=round(c.adc_rank_s/c.h_s);ap=round(c.adc_aperture_s/c.h_s);
adc=base+trigger+[2*rank+ap;rank+ap;ap];jeos=base+trigger+3*rank;
release=jeos+ceil(release_jitter_s/c.h_s-1e-9);
ready=release+ceil(c.observer_exec_s/c.h_s-1e-9);
write=ready+ceil(c.foc_exec_s/c.h_s-1e-9)+ceil(interference_s/c.h_s-1e-9);
step=N/2;if c.update_mode==1,step=N;end
intended=(floor(jeos/step)+1)*step;
actual=(floor(write/step)+1)*step; % UEV wins ties with a new write.
deadline=intended-ceil(c.guard_s/c.h_s-1e-9);
p=struct('cycle',cycle,'adc_aperture_end_ABC_s',adc*c.h_s,'reference_time_s',jeos*c.h_s,...
 'task_release_s',release*c.h_s,'observer_available_s',ready*c.h_s,'ccr_write_s',write*c.h_s,...
 'intended_pwm_apply_s',intended*c.h_s,'actual_pwm_apply_s',actual*c.h_s,...
 'deadline_s',deadline*c.h_s,'reserved_slack_s',(deadline-write)*c.h_s,...
 'missed_update',actual>intended,'next_frame_overrun',write>=jeos+N,...
 'speed_task_active',mod(cycle,round(c.speed_period_s/c.period_s))==round(c.speed_period_s/c.period_s)-1,...
 'timing_valid',write<deadline&&write<jeos+N);
end
