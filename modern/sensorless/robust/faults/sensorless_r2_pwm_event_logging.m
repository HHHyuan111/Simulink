function sensorless_r2_pwm_event_logging(mdl)
% Native PWM UEV/write events; original 1us display cannot resolve62.5ns.
p=[mdl '/无感观测/观测'];
add_block('simulink/Signal Routing/From',[p '/PWM事件来源'],'GotoTag','ObsPWMTiming','Position',[2500 1150 2700 1180]);
add_block('simulink/User-Defined Functions/Fcn',[p '/PWM发生事件'],'Expr','u(3)+u(4)+u(5)','Position',[2750 1220 2930 1250]);
add_line(p,'PWM事件来源/1','PWM发生事件/1','autorouting','on');
e=[p '/PWM原生记录'];add_block('built-in/SubSystem',e,'Position',[3100 1140 3310 1210]);
add_block('built-in/Inport',[e '/数据'],'Position',[25 50 55 70],'PortDimensions','[1 12]');
add_block('built-in/EnablePort',[e '/事件'],'Position',[95 10 115 30]);
add_block('simulink/Sinks/To Workspace',[e '/保存'],'Position',[110 45 310 75],'VariableName','obs_sless_r2_pwm_events',...
 'SaveFormat','Timeseries','SampleTime','-1','MaxDataPoints','inf');
add_line(e,'数据/1','保存/1','autorouting','on');add_line(p,'PWM事件来源/1','PWM原生记录/1','autorouting','on');
add_line(p,'PWM发生事件/1','PWM原生记录/Enable','autorouting','on');
end
