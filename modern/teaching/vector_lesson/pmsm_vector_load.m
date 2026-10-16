function data=pmsm_vector_load(folder)
% Read a verified archive. No model loading, parameter changes or simulation.
here=fileparts(mfilename('fullpath'));teach=fileparts(here);
if nargin<1||isempty(folder)
 example=jsondecode(fileread(fullfile(teach,'experiments','examples','angle_bias','summary.json')));
 folder=example.source_run_folder;
end
folder=char(folder);assert(isfolder(folder),'未找到原始实验档案。请先在单项实验中运行“角度偏置”，再载入该结果目录。');
r=pmsm_experiment_verify(folder);
assert(strcmp(r.scenario.id,'angle_bias')&&numel(r.cases)==2,'本课只接受已完成的两组角度偏置实验。');
assert(strcmp(r.model_sha256,'a0f7cbae9e7c334c25aa9dcf6e7e88d65fd89bd1888a0fa2ec0cd04f6cce262d'), ...
 '本课的变换约定尚未核对该模型版本。');
assert(isequal({r.cases.id},{'reference','factor'}),'实验分组身份不符。');
for k=1:2
 active=pmsm_check_switches(r.cases(k).configuration);
 if k==1,assert(isempty(active),'参考组存在附加因素。');
 else,assert(isequal(active,{'角度设置.bias_on'}),'角度组混入其他因素。');end
end
a=r.cases(1).configuration.rows;b=r.cases(2).configuration.rows;
assert(isequal({a.section},{b.section})&&isequal({a.key},{b.key}),'两组参数清单不对应。');
changed=~strcmp({a.value},{b.value});
assert(all(strcmp({a(changed).section},'角度设置')&ismember({a(changed).key},{'bias_on','bias_deg'})),'两组差异超出角度偏置。');
data=struct('schema',1,'kind','pmsm_coordinates_lesson_v1','folder',folder,'source_id',r.id, ...
 'source_record_sha256',teach_hash(fullfile(folder,'record.json')),'model_sha256',r.model_sha256, ...
 'bias_electrical_deg',r.factor_value,'sample_period_s',NaN,'cases',struct([]), ...
 'windows',struct([]),'dictionary',dictionary(),'source_files',struct('path',{},'sha256',{}));
for name={'record.json','plan.json','reference.mat','factor.mat'}
 data.source_files(end+1)=struct('path',name{1},'sha256',teach_hash(fullfile(folder,name{1})));
end
for k=1:2
 loaded=load(fullfile(folder,[r.cases(k).id '.mat']),'signals');s=loaded.signals;t=double(s.log_iabc_true.Time(:));
 assert(numel(t)>10&&all(isfinite(t))&&all(diff(t)>0),'时间轴必须有限且严格递增。');
 dt=median(diff(t));assert(max(abs(diff(t)-dt))<1e-11,'本课要求均匀采样记录。');
 same={'log_iabc_meas','obs_state','log_theta_true','log_theta_meas','log_theta_error','log_id','log_iq','obs_id_ref','log_iq_ref','log_speed','log_nref'};
 for name=same,assert(isequal(t,double(s.(name{1}).Time(:))),'信号时间轴不一致：%s',name{1});end
 abc=teach_values(s.log_iabc_true);measured=teach_values(s.log_iabc_meas);
 theta=teach_values(s.log_theta_true);control=teach_values(s.log_theta_meas);
 truth=pmsm_vector_transform(abc,theta);feedback=pmsm_vector_transform(measured,control);
 states=teach_values(s.obs_state);dqFeedback=[teach_values(s.log_id),teach_values(s.log_iq)];
 err=atan2(sin(control-theta),cos(control-theta));
 residual=struct('true_dq_A',max(abs(truth.dq_A-states(:,1:2)),[],'all'), ...
  'feedback_dq_A',max(abs(feedback.dq_A-dqFeedback),[],'all'), ...
  'clarke_roundtrip_A',max(abs(truth.abc_reconstructed_A-abc),[],'all'), ...
  'angle_error_rad',max(abs(err-teach_values(s.log_theta_error))), ...
  'configured_bias_rad',max(abs(err-(k-1)*r.factor_value*pi/180)));
 assert(all(structfun(@(x)x<1e-9,residual)),'变换结果与模型日志不一致，拒绝展示。');
 assert(all(isfinite(states),'all')&&all(isfinite(dqFeedback),'all'),'电流记录出现非有限值。');
 label='理想角度';if k==2,label=sprintf('角度偏置 %+g°',r.factor_value);end
 currentCase=struct('id',r.cases(k).id,'label',label,'time_s',t,'abc_A',abc, ...
  'alpha_beta_A',truth.alpha_beta_A,'zero_A',truth.zero_A,'dq_true_A',truth.dq_A, ...
  'dq_feedback_A',dqFeedback,'dq_reference_A',[teach_values(s.obs_id_ref),teach_values(s.log_iq_ref)], ...
  'theta_true_rad',theta,'theta_control_rad',control,'angle_error_deg',err*180/pi, ...
  'speed_rpm',teach_values(s.log_speed),'nref_rpm',teach_values(s.log_nref),'residual',residual);
 if k==1,data.cases=currentCase;else,data.cases(k)=currentCase;end
 if k==1,data.sample_period_s=dt;else,assert(isequal(data.cases(1).time_s,t),'两组采样时间不同。');end
end
% This window is predeclared by the source experiment, never selected for looks.
t=data.cases(1).time_s;tail=r.statistics_window_s;
windows={[max(t(1),tail(1)) min(t(end),tail(2))],[t(1) min(t(end),t(1)+.04)],[t(1) t(end)]};
names={'稳态','启动','全程'};
for j=1:3
 bounds=windows{j};idx=find(t>=bounds(1)-dt/100&t<=bounds(2)+dt/100);
 assert(numel(idx)>1,'观察区间样本不足。');abc=[];dq=[];refs=[];radii=[];checks=struct([]);
 for k=1:2
  c=data.cases(k);abc=[abc;c.abc_A(idx,:)];dq=[dq;c.dq_true_A(idx,:);c.dq_feedback_A(idx,:)];refs=[refs;c.dq_reference_A(idx,:)]; %#ok<AGROW>
  radii=[radii;hypot(c.alpha_beta_A(idx,1),c.alpha_beta_A(idx,2))]; %#ok<AGROW>
  speed=c.speed_rpm(idx);fit=polyfit(t(idx)-t(idx(1)),speed,1);
  currentCheck=struct('mean_speed_error_rpm',mean(speed-c.nref_rpm(idx)), ...
   'speed_span_rpm',max(speed)-min(speed),'speed_slope_rpm_s',fit(1));
  if k==1,checks=currentCheck;else,checks(k)=currentCheck;end
 end
 limits=struct('abc_A',pad(abc(:)),'xy_A',max(.5,max(radii)*1.32), ...
  'd_A',pad([dq(:,1);refs(:,1)]),'q_A',pad([dq(:,2);refs(:,2)]));
 if j==1
  passed=all(arrayfun(@(x)abs(x.mean_speed_error_rpm)<=30&&x.speed_span_rpm<=60&&abs(x.speed_slope_rpm_s)<=100,checks));
  if ~passed,names{j}='末段';end
 else,passed=false;end
 currentWindow=struct('name',names{j},'bounds_s',[t(idx(1)) t(idx(end))], ...
  'indices',idx,'limits',limits,'speed_plateau_passed',passed,'speed_checks',checks);
 if j==1,data.windows=currentWindow;else,data.windows(j)=currentWindow;end
end
end
function limits=pad(x)
lo=min(x);hi=max(x);gap=max(.05,(hi-lo)*.1);limits=[lo-gap hi+gap];
end
function t=dictionary()
name={'abc_A';'alpha_beta_A';'dq_true_A';'dq_feedback_A';'dq_reference_A';'theta_true_rad';'theta_control_rad';'angle_error_deg';'zero_A'};
unit={'A';'A';'A';'A';'A';'rad';'rad';'电角度 °';'A'};
frame={'ABC';'αβ';'真实转子dq';'控制器dq';'控制器dq';'真实电角';'控制电角';'最短电角差';'零序'};
origin={'log_iabc_true';'log_iabc_true → 幅值不变Clarke';'abc/真实角度 → Park；核对obs_state前两列'; ...
 'log_id / log_iq；核对测量abc/控制角度的Park';'obs_id_ref / log_iq_ref';'log_theta_true';'log_theta_meas'; ...
 'atan2(sin(控制角-真角),cos(控制角-真角))；核对log_theta_error';'sum(log_iabc_true,2)/3'};
t=table(name,unit,frame,origin,'VariableNames',{'signal','unit','coordinate','source'});
end
