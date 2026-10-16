function pmsm_sampling_comparison_menu(fig)
% Shared native menu; the historical function name is kept for compatibility.
menu=uimenu(fig,'Text','教学对比','Tag','PMSMTeachingComparisonMenu');
labels={'噪声与滤波','采样延迟','数字滤波','PWM更新','死区补偿'};
tags={'PMSMSamplingComparison','PMSMFeedbackEffects_delay','PMSMFeedbackEffects_filter','PMSMTimingFeedback','PMSMDeadtimeComparison'};
actions={@open_pmsm_sampling_comparison,@()open_pmsm_feedback_effects('delay'),@()open_pmsm_feedback_effects('filter'),@open_pmsm_timing_feedback,@open_pmsm_deadtime_comparison};
for k=1:numel(labels)
 fun=actions{k};tag=tags{k};uimenu(menu,'Text',labels{k},'Tag',['teaching_compare_' tag],'MenuSelectedFcn',@(~,~)launch(fun,tag));
end
 function launch(fun,tag)
  try
   existing=findall(groot,'Type','figure','Tag',tag);
   if isempty(existing),fun();else,figure(existing(1));end
  catch err,errordlg(err.message,'对比未打开');end
 end
end
