function [outputs,record]=run_observation_demo(lesson)
% Run with the selected PI gains; do not save or silently alter GUI settings.
% overview | analog | power | firmware_io
if nargin==0,lesson='overview';end
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);mdl='PMSM_FOC_R2026a';
if ~bdIsLoaded(mdl),load_system(fullfile(root,[mdl '.slx']));end
settings=teach_settings(mdl);mw=get_param(mdl,'ModelWorkspace');initial=workspaceValues(mw);
connection=Simulink.data.connect(get_param(mdl,'FileName'));wasDirty=hasUnsavedChanges(connection);
cleanup=onCleanup(@()restore(mw,initial,wasDirty));
switch char(lesson)
 case 'overview'
  labels={'参考'};configs={{}};
 case 'analog'
  labels={'参考','模拟低通 5 kHz','模拟 5 kHz + 数字 500 Hz'};
  configs={{};{'采样设置','analog_on','on'};{'采样设置','analog_on','on';'采样设置','filter_on','on'}};
 case 'power'
  labels={'参考','死区平均压降 0.5 μs','导通压降','两项组合'};
  configs={{};{'功率设置','dead_on','on'};{'功率设置','drop_on','on'};{'功率设置','dead_on','on';'功率设置','drop_on','on'}};
 case 'firmware_io'
  assert(abs(initial.dt-50e-6)<1e-12&&abs(initial.Ts-50e-6)<1e-12, ...
   'This firmware preset expects 20kHz current/PWM timing; align timing explicitly first.');
  labels={'参考','固件频率与 ADC 量程','再加死区平均压降'};
  io={'时序设置','speed_on','on';'时序设置','speed_divider','2';'采样设置','adc_on','on';'采样设置','adc_bits','12';'采样设置','adc_span','82.5'};
  configs={{};io;[io;{'功率设置','dead_on','on';'功率设置','dead_us','0.5'}]};
 otherwise,error('Choose overview, analog, power or firmware_io.');
end
outputs=cell(1,numel(labels));cases=struct('label',{},'settings',{},'timing',{},'metrics',{});
outdir=fullfile(folder,['report_' char(lesson)]);if ~isfolder(outdir),mkdir(outdir);end
for k=1:numel(labels)
 input=Simulink.SimulationInput(mdl);input=setModelParameter(input,'StopTime','0.12');actual=settings;
 for j=1:numel(settings)
  for q=1:numel(settings(j).parameters)
   p=settings(j).parameters(q);if endsWith(p.name,'_on')
    input=setBlockParameter(input,[mdl '/' settings(j).block],p.name,'off');actual(j).parameters(q).value='off';
   end
  end
 end
 cfg=configs{k};for j=1:size(cfg,1)
  input=setBlockParameter(input,[mdl '/' cfg{j,1}],cfg{j,2},cfg{j,3});
  bi=find(strcmp({actual.block},cfg{j,1}));pi=find(strcmp({actual(bi).parameters.name},cfg{j,2}));actual(bi).parameters(pi).value=cfg{j,3};
 end
 fprintf('OBS_DEMO %s %d\n',lesson,k);o=sim(input);outputs{k}=o;
 caseDir=fullfile(outdir,sprintf('case_%02d',k));metrics=plot_observation_report(o,labels{k},caseDir);
 cases(end+1)=struct('label',labels{k},'settings',actual,'timing',observation_timing(initial,actual),'metrics',metrics); %#ok<AGROW>
end
restore(mw,initial,wasDirty);assert(isequaln(settings,teach_settings(mdl)));assert(isequaln(initial,workspaceValues(mw)));
assert(hasUnsavedChanges(connection)==wasDirty);clear cleanup;
record=struct('lesson',char(lesson),'model_sha256',teach_hash(get_param(mdl,'FileName')), ...
 'firmware_repository','https://github.com/HHHyuan111/AxDr_L','firmware_ref','dev', ...
 'firmware_commit','48d6e86814ac6657b1313b4c92ef24c88f492e07','pi_gains_unchanged',true, ...
 'model_workspace_values',initial,'cases',cases,'complete_board_emulation',false, ...
 'notes',{{'Motor parameters and base timing follow the active model workspace; PI gains and controller architecture remain the teaching implementation. See model_workspace_values for the active motor profile.', ...
 'Midrail ADC offset is assumed; analog RC, Ron, Vf and current blend are demonstration values.', ...
 'The average power error follows the structure of mc_deadtime_comp.c but is not a transistor switching model.'}});
teach_writejson(fullfile(outdir,'record.json'),record);save(fullfile(outdir,'runs.mat'),'outputs','record','-v7.3');
if numel(outputs)>1,comparison(outputs,labels,outdir);end
fprintf('OBS_DEMO_SAVED %s\n',outdir);
end

function comparison(outputs,labels,folder)
f=figure('Visible','off','Color','white','Position',[50 50 1400 900]);set(f,'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei');
tiledlayout(2,2,'TileSpacing','compact');
for panel=1:4
 nexttile;hold on;
 for k=1:numel(outputs)
  o=outputs{k};t=o.log_speed.Time;
  switch panel
   case 1,y=teach_values(o.log_speed);unit='rpm';label='转速：PI 参数相同';
   case 2,y=teach_values(o.log_iq);unit='A';label='q 轴控制器反馈';
   case 3,m=teach_values(o.log_iabc_meas);r=teach_values(o.log_iabc_true);y=m(:,1)-r(:,1);unit='A';label='A 相测量误差（含滤波滞后）';
   case 4,d=teach_values(o.obs_power_drop);y=d(:,1);unit='V';label='A 相平均功率级压降';
  end
  plot(t,y);
 end
 grid on;xlabel('时间 [s]');ylabel(unit);title(label);legend(labels,'Location','best');if panel>=3,xlim([0.1 0.12]);end
end
sgtitle('单项 → 组合对照 | 参数来源与局限见 record.json','FontName','Microsoft YaHei');exportgraphics(f,fullfile(folder,'comparison.png'),'Resolution',130);close(f);
end
function restore(mw,initial,wasDirty)
if ~wasDirty,reload(mw);else
 for n={'teaching_Ts_speed','teach_pwm_on','teach_pwm_cycles'}
  if ~isequaln(getVariable(mw,n{1}),initial.(n{1})),assignin(mw,n{1},initial.(n{1}));end
 end
end
end
function values=workspaceValues(mw)
values=struct;for variable=whos(mw)'
 v=getVariable(mw,variable.name);if isnumeric(v)||islogical(v)||ischar(v),values.(variable.name)=v;end
end
end
