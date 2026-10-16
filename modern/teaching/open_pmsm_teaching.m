function fig=open_pmsm_teaching(visible)
% Add a native Scope entry without changing the archived launcher fingerprint.
if nargin<1,visible='on';end
teach=fileparts(mfilename('fullpath'));root=fileparts(teach);addpath(root,fullfile(root,'framework'));
fig=open_pmsm_framework(visible);g=findobj(fig,'Type','uigridlayout','Parent',fig);
observations=uimenu(fig,'Text','观测');
uimenu(observations,'Text','电流与采样','MenuSelectedFcn',@(~,~)openSampling);
uimenu(observations,'Text','电流采样演示','MenuSelectedFcn',@(~,~)runSamplingPreview);
uimenu(observations,'Text','最近演示统计','MenuSelectedFcn',@(~,~)openSamplingMetrics);
frequency=uimenu(fig,'Text','频域');uimenu(frequency,'Text','死区电流频谱','MenuSelectedFcn',@(~,~)openSpectrum);
uimenu(frequency,'Text','噪声与滤波频谱','MenuSelectedFcn',@(~,~)openNoiseSpectrum);
hint=findall(fig,'Type','uilabel','Text','先用单项实验理解一个因素，再用整机基线查看组合运行。电机及硬件参数尚待实测校准。');
hint.Visible='off';
b=uibutton(g,'Text','控制响应','FontSize',16,'Tag','native_scope_entry','ButtonPushedFcn',@openLesson);
b.Layout.Row=5;b.Layout.Column=1;
b=uibutton(g,'Text','电流与电压','FontSize',16,'Tag','electrical_scope_entry','ButtonPushedFcn',@openElectrical);
b.Layout.Row=5;b.Layout.Column=2;
b=uibutton(g,'Text','PWM与采样','FontSize',16,'Tag','pwm_scope_entry','ButtonPushedFcn',@openPWM);
b.Layout.Row=5;b.Layout.Column=3;
 function openSpectrum
  try,open_pmsm_spectrum;catch err,uialert(fig,err.message,'频谱未打开');end
 end
 function openSampling
  try,open_pmsm_current_sampling_scope;catch err,uialert(fig,err.message,'Scope未打开');end
 end
 function runSamplingPreview
  try,preview_pmsm_current_sampling;catch err,uialert(fig,err.message,'演示未完成');end
 end
 function openSamplingMetrics
  try,open_pmsm_sampling_metrics;catch err,uialert(fig,err.message,'统计未打开');end
 end
 function openNoiseSpectrum
  try,open_pmsm_noise_spectrum;catch err,uialert(fig,err.message,'频谱未打开');end
 end
 function openPWM(~,~)
  try,open_pmsm_pwm_scope;catch err,uialert(fig,err.message,'Scope未打开');end
 end
 function openElectrical(~,~)
  try,open_pmsm_electrical_scope;catch err,uialert(fig,err.message,'Scope未打开');end
 end
 function openLesson(~,~)
  try,open_pmsm_control_scope;catch err,uialert(fig,err.message,'Scope未打开');end
 end
end
