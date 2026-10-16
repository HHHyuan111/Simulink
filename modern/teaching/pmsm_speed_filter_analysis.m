function [report,v,samples]=pmsm_speed_filter_analysis(outputs,plan)
[report,piView,samples]=pmsm_speed_feedback_analysis(outputs,plan);c=plan.comparison_contract;v=cell(1,2);W=c.window_ticks(2);dt=c.read_period_s;
for key={'filter_on','cutoff_hz','filtered_state_rpm','quantization_contribution_rpm','filter_dynamic_error_rpm','window_average_error_rpm'},samples.(key{1})=zeros(height(samples),1);end
offset=0;
for k=1:2
 s=outputs{k};t=s.log_speed.Time;truth=teach_values(s.log_speed);mech=teach_values(s.log_encoder_mechanical);raw=teach_values(s.log_speed_window);f=teach_values(s.log_speed_filter);
 ix=(W+1:numel(t))';windowTruth=zeros(size(t));windowTruth(ix)=(mech(ix)-mech(ix-W))*60/(2*pi*W*dt);
 quant=raw(:,1)-windowTruth;windowError=windowTruth-truth;
 if c.filter_on(k)
  quantContribution=lpf(quant,c.filter_a);filterDynamic=lpf(windowTruth,c.filter_a)-windowTruth;
 else,quantContribution=quant;filterDynamic=zeros(size(t));end
 total=f(:,3)-truth;valid=raw(:,2)>.5;tail=valid&t>=plan.statistics_window_s(1);
 residual=total(valid)-quantContribution(valid)-filterDynamic(valid)-windowError(valid);assert(max(abs(residual))<1e-8);
 m=report.cases(k);m.raw_quantization_rms_rpm=sqrt(mean(quant(tail).^2));m.quantization_contribution_rms_rpm=sqrt(mean(quantContribution(tail).^2));
 m.filter_dynamic_error_rms_rpm=sqrt(mean(filterDynamic(tail).^2));m.window_average_error_rms_rpm=sqrt(mean(windowError(tail).^2));m.decomposition_max_residual_rpm=max(abs(residual));
 % Add optional fields across the struct array explicitly.
 for key={'raw_quantization_rms_rpm','quantization_contribution_rms_rpm','filter_dynamic_error_rms_rpm','window_average_error_rms_rpm','decomposition_max_residual_rpm'},report.cases(k).(key{1})=m.(key{1});end
 v{k}=struct('time',t,'truth',truth,'raw',raw(:,1),'filtered_state',f(:,2),'effective',f(:,3),'valid',valid, ...
  'quantization_raw',quant,'quantization_contribution',quantContribution,'filter_dynamic',filterDynamic,'window_error',windowError, ...
  'total_error',total,'pi',piView{k},'label',plan.cases(k).label);
 [found,at]=ismember(round(piView{k}.time/c.event_step_s),round(t/c.event_step_s));assert(all(found)&&max(abs(piView{k}.time-t(at)))<1e-12);rows=offset+(1:numel(at));offset=offset+numel(at);
 samples.filter_on(rows)=c.filter_on(k);samples.cutoff_hz(rows)=c.cutoff_hz;samples.filtered_state_rpm(rows)=f(at,2);
 samples.quantization_contribution_rpm(rows)=quantContribution(at);samples.filter_dynamic_error_rpm(rows)=filterDynamic(at);samples.window_average_error_rpm(rows)=windowError(at);
end
end
function y=lpf(x,a)
y=zeros(size(x));state=0;b=1-a;for k=1:numel(x),state=b*x(k)+a*state;y(k)=state;end
end
