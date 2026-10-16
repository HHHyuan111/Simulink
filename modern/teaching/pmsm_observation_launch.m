function result=pmsm_observation_launch(kind)
% Model-canvas shortcuts: open existing native scopes and archived figures.
here=fileparts(mfilename('fullpath'));addpath(here,fullfile(fileparts(here),'layout','appearance'));result=[];
try
 switch kind
  case 'time',result=open_pmsm_observations('time');
  case 'frequency',result=open_pmsm_observations('frequency');
  case 'current_fft',result=open_pmsm_current_analysis;
  case 'd_loop',result=open_pmsm_current_frequency;
  case 'q_loop',result=open_pmsm_q_frequency;
  case 'speed_loop',result=open_pmsm_speed_probe;
  otherwise,error('未知观测入口：%s',kind);
 end
catch err
 errordlg(err.message,'观测未打开','modal');
end
end
