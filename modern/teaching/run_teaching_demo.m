function [outputs,record]=run_teaching_demo(lesson)
% Repeatable A/B examples. Saved model settings and all PI gains are retained.
% run_teaching_demo('timing' | 'noise_filter' | 'offset' | 'angle')
if nargin==0,lesson='timing';end
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);mdl='PMSM_FOC_R2026a';
if ~bdIsLoaded(mdl),load_system(fullfile(root,[mdl '.slx']));end
initial=teach_settings(mdl);
mw=get_param(mdl,'ModelWorkspace');initialVariables=workspaceValues(mw);
connection=Simulink.data.connect(get_param(mdl,'FileName'));
workspaceWasDirty=hasUnsavedChanges(connection);
cleanup=onCleanup(@()restoreWorkspace(mw,initialVariables,workspaceWasDirty));
switch char(lesson)
 case 'timing'
  labels={'Reference','Speed task: divider 20','Output delay: one cycle'};
  configs={{};{'时序设置','speed_on','on';'时序设置','speed_divider','20'};{'时序设置','pwm_on','on';'时序设置','pwm_cycles','1'}};
 case 'noise_filter'
  labels={'Reference','Sampled current noise','Noise + digital low-pass'};
  configs={{};{'采样设置','noise_on','on'};{'采样设置','noise_on','on';'采样设置','filter_on','on'}};
 case 'offset'
  labels={'Reference','Current offset'};configs={{};{'采样设置','bias_on','on'}};
 case 'angle'
  labels={'Reference','Angle bias','Angle delay: two cycles'};
  configs={{};{'角度设置','bias_on','on'};{'角度设置','delay_on','on';'角度设置','delay_cycles','2'}};
 otherwise
  error('Unknown lesson. Choose timing, noise_filter, offset or angle.');
end
outputs=cell(1,numel(configs));cases=struct('label',{},'settings',{},'speed_final_rpm',{},'peak_iq_A',{});
for k=1:numel(configs)
 input=Simulink.SimulationInput(mdl);input=setModelParameter(input,'StopTime','0.12');
 actual=initial;
 % Explicitly disable every effect before applying each lesson's selection.
 for j=1:numel(initial)
  for q=1:numel(initial(j).parameters)
   p=initial(j).parameters(q);
   if endsWith(p.name,'_on')
    input=setBlockParameter(input,[mdl '/' initial(j).block],p.name,'off');actual(j).parameters(q).value='off';
   end
  end
 end
 cfg=configs{k};
 for j=1:size(cfg,1)
  input=setBlockParameter(input,[mdl '/' cfg{j,1}],cfg{j,2},cfg{j,3});
  index=find(strcmp({actual.block},cfg{j,1}));pindex=find(strcmp({actual(index).parameters.name},cfg{j,2}));
  actual(index).parameters(pindex).value=cfg{j,3};
 end
 fprintf('TEACH_DEMO %s %s\n',lesson,labels{k});outputs{k}=sim(input);o=outputs{k};
 cases(end+1)=struct('label',labels{k},'settings',actual, ...
  'speed_final_rpm',double(o.log_speed.Data(end)),'peak_iq_A',max(abs(double(o.log_iq.Data(:))))); %#ok<AGROW>
end
assert(isequaln(initial,teach_settings(mdl)),'Simulation changed the selected mask values.');
restoreWorkspace(mw,initialVariables,workspaceWasDirty);
assert(isequaln(initialVariables,workspaceValues(mw)),'Simulation changed the original model-workspace values.');
assert(hasUnsavedChanges(connection)==workspaceWasDirty,'Simulation changed the workspace dirty state.');
clear cleanup
record=struct('lesson',char(lesson),'matlab',version,'saved_model_sha256',teach_hash(fullfile(root,[mdl '.slx'])), ...
 'stop_time_s',0.12,'parameters_are_demonstration_values',true,'pi_gains_unchanged',true, ...
 'model_workspace_parameters',initialVariables,'cases',cases);
save(fullfile(folder,['demo_' char(lesson) '.mat']),'outputs','record','-v7');
teach_writejson(fullfile(folder,['demo_' char(lesson) '.json']),record);
makePlot(outputs,labels,char(lesson),folder);
fprintf('TEACH_DEMO_SAVED %s\n',fullfile(folder,['demo_' char(lesson) '.png']));
end

function makePlot(outputs,labels,lesson,folder)
f=figure('Visible','off','Color','white','Position',[50 50 1300 850]);tiledlayout(2,2,'TileSpacing','compact');
nexttile;hold on;for k=1:numel(outputs),o=outputs{k};plot(o.log_speed.Time,o.log_speed.Data);end
grid on;xlabel('Time (s)');ylabel('Speed (rpm)');title('Speed; identical PI gains');legend(labels,'Location','best');
nexttile;hold on;for k=1:numel(outputs),o=outputs{k};plot(o.log_iq.Time,o.log_iq.Data);end
grid on;xlabel('Time (s)');ylabel('Measured iq (A)');title('Current feedback');
nexttile;hold on;
if strcmp(lesson,'timing')
 o=outputs{end};requested=teach_values(o.log_Tcm_requested);applied=teach_values(o.log_Tcm_applied);
 stairs(o.log_Tcm_requested.Time,requested(:,1)*1e6);
 stairs(o.log_Tcm_applied.Time,applied(:,1)*1e6);xlim([0.08 0.081]);
 ylabel('Threshold (us)');title('Cycle-level output delay');legend('Requested','Applied');
else
 for k=2:numel(outputs)
  o=outputs{k};plot(o.log_iabc_meas.Time,o.log_iabc_meas.Data(:,1)-o.log_iabc_true.Data(:,1));
 end
 xlim([0.08 0.09]);ylabel('Measured - true phase A (A)');title('Measurement error, including filter lag');legend(labels(2:end));
end
grid on;xlabel('Time (s)');
nexttile;hold on;
if strcmp(lesson,'angle')
 for k=2:numel(outputs),o=outputs{k};plot(o.log_theta_error.Time,o.log_theta_error.Data*180/pi);end
 ylabel('Electrical angle error (deg)');title('Wrapped angle error');legend(labels(2:end));
elseif strcmp(lesson,'timing')
 for k=1:2,o=outputs{k};stairs(o.log_iq_ref.Time,o.log_iq_ref.Data);end
 xlim([0.028 0.04]);ylabel('iq reference (A)');title('Outer-loop command hold');legend(labels(1:2));
else
 o=outputs{end};plot(o.log_iabc_true.Time,o.log_iabc_true.Data(:,1));plot(o.log_iabc_meas.Time,o.log_iabc_meas.Data(:,1));
 xlim([0.08 0.09]);ylabel('Phase A current (A)');title('Last case: true and measured');legend('True','Measured');
end
grid on;xlabel('Time (s)');sgtitle(['Teaching / ' strrep(lesson,'_',' ') ' / Demonstration parameters']);
exportgraphics(f,fullfile(folder,['demo_' lesson '.png']),'Resolution',130);close(f);
end
function restoreWorkspace(mw,values,wasDirty)
% InitFcn writes three derived values outside SimulationInput's override layer.
% Reload only an initially clean workspace; preserve all user overrides otherwise.
if ~wasDirty
 reload(mw);
else
 names={'teaching_Ts_speed','teach_pwm_on','teach_pwm_cycles'};
 for k=1:numel(names)
  name=names{k};
  if ~isequaln(getVariable(mw,name),values.(name)),assignin(mw,name,values.(name));end
 end
end
end
function values=workspaceValues(mw)
variables=whos(mw);values=struct;
for k=1:numel(variables)
 value=getVariable(mw,variables(k).name);
 if isnumeric(value)||islogical(value)||ischar(value),values.(variables(k).name)=value;end
end
end
