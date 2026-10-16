function [rows,traces]=sensorless_n1_pll_tests(c,a,plan)
p=plan.pll_component;time=(0:round(p.duration_s/c.sample_s))'*c.sample_s;
rows=struct('frequency_Hz',{},'amplitude',{},'initial_error_deg',{},'angle_rms_deg',{},'speed_mean_relative',{},'capture_s',{},'passed',{});
traces=cell(0,1);count=0;
for freq=p.electrical_frequency_Hz(:)'
 for amplitude=p.amplitudes(:)'
  for phase=p.initial_phase_error_deg(:)'
   count=count+1;s=struct('theta',mod(phase*pi/180,2*pi),'integral',0,'omega',0);
   truth=2*pi*freq*time;data=zeros(numel(time),7);
   for k=1:numel(time)
    vector=amplitude*[cos(truth(k));sin(truth(k))];[s,o]=sensorless_pll_step(s,vector,c,true,false);
    error=atan2(sin(o.theta-truth(k)),cos(o.theta-truth(k)))*180/pi;
    data(k,:)=[time(k),o.theta,o.omega,error,o.integral,o.error,o.saturated];
   end
   win=time>=p.window_s(1)&time<=p.window_s(2);rms_angle=sqrt(mean(data(win,4).^2));
   mean_speed=abs(mean(data(win,3))-2*pi*freq)/abs(2*pi*freq);
   capture=capture_time(time,abs(data(:,4))<=a.correctness.pll_capture_angle_abs_deg,a.correctness.pll_capture_hold_s,c.sample_s);
   passed=rms_angle<=a.correctness.pll_settle_angle_rms_deg&&mean_speed<=a.correctness.pll_speed_mean_relative_max&&capture<=a.correctness.pll_capture_deadline_s;
   rows(count)=struct('frequency_Hz',freq,'amplitude',amplitude,'initial_error_deg',phase,...
    'angle_rms_deg',rms_angle,'speed_mean_relative',mean_speed,'capture_s',capture,'passed',passed);
   traces{count}=data;
  end
 end
end
fprintf('PLL cases=%d max_angle_RMS_deg=%g max_capture_s=%g\n',count,max([rows.angle_rms_deg]),max([rows.capture_s]));
end

function t=capture_time(time,ok,hold,T)
n=round(hold/T)+1;run=0;t=Inf;
for k=1:numel(time)
 if ok(k),run=run+1;else,run=0;end
 if run>=n,t=time(k-n+1);return;end
end
end

