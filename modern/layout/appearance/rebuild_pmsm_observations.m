function report=rebuild_pmsm_observations
% Refresh only owned view blocks, including a session from an older script.
% Does not close/reload the model, restore parameters, or save its SLX.
mdl='PMSM_FOC_R2026a';here=fileparts(mfilename('fullpath'));root=fileparts(fileparts(here));
addpath(root,here,fullfile(root,'teaching'));
assert(bdIsLoaded(mdl)&&strcmp(get_param(mdl,'SimulationStatus'),'stopped'));
cfg=pmsm_config('read');file=get_param(mdl,'FileName');mw=get_param(mdl,'ModelWorkspace');code=mw.MATLABCode;
hadChain=pmsm_signal_chain_view('installed');if hadChain,pmsm_signal_chain_view('remove');end
hadDeadtime=pmsm_deadtime_scope('installed');deadtimeMode=pmsm_deadtime_scope('mode');if hadDeadtime,pmsm_deadtime_scope('remove');end
if pmsm_observation_view('installed'),pmsm_observation_view('remove');end
tags={'PMSMNativeCurrentSamplingScope','PMSMNativePWMScope','PMSMNativeElectricalScope','PMSMNativeControlScope'};
hadSampling=~isempty(find_system(mdl,'LookUnderMasks','all','Tag',tags{1}));
removed=0;
for tag=tags
 owned=find_system(mdl,'LookUnderMasks','all','FollowLinks','off','Type','Block','Tag',tag{1});
 [~,order]=sort(cellfun(@numel,owned),'descend');owned=owned(order);
 for name=owned(:)'
  path=name{1};if getSimulinkBlockHandle(path)<0,continue;end
  if strcmp(get_param(path,'BlockType'),'Scope'),close_system(path);drawnow;end
  ph=get_param(path,'PortHandles');parent=get_param(path,'Parent');
  for p=ph.Inport(:)'
   line=get_param(p,'Line');if line>=0
    src=get_param(line,'SrcPortHandle');if src>=0,delete_line(parent,src,p);else,delete_line(line);end
   end
  end
  for p=ph.Outport(:)',line=get_param(p,'Line');if line>=0,delete_line(line);end,end
  delete_block(path);removed=removed+1;
 end
end
defaults=jsondecode(fileread(fullfile(here,'observation_parent_defaults.json')));
for p=defaults(:)',set_param([mdl '/' p.name],'MaskDisplay',p.mask_display,'OpenFcn',p.open_fcn);end
clear pmsm_native_scope pmsm_electrical_scope pmsm_pwm_scope pmsm_current_sampling_scope
if pmsm_presentation('installed'),pmsm_presentation('remove');end
pmsm_presentation('apply');pmsm_native_scope('install');pmsm_electrical_scope('install');pmsm_pwm_scope('install');
if hadSampling,pmsm_current_sampling_scope('install');end
report=pmsm_observation_view('install');report.removed_owned_blocks=removed;
if hadDeadtime,pmsm_deadtime_scope('install',mdl,deadtimeMode);end
if hadChain,pmsm_signal_chain_view('apply');end
report.user_configuration_preserved=isequaln(cfg,pmsm_config('read'));assert(report.user_configuration_preserved);
assert(strcmp(file,get_param(mdl,'FileName'))&&strcmp(code,mw.MATLABCode));
report.same_model_and_workspace_code=true;
end
