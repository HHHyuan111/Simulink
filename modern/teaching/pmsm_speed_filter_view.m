function path=pmsm_speed_filter_view(value)
if nargin<1,value=[];end
p=pmsm_experiment_plan('speed_filter',value);pmsm_speed_feedback_view([p.value(1:2) 4*p.value(2)]);
path=pmsm_speed_filter_model('install');set_param(path,'filter_on','on','cutoff_hz',num2str(p.value(3),17));open_system(path);set_param(path,'ZoomFactor','FitSystem');
end
