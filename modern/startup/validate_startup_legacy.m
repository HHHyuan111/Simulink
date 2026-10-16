function report=validate_startup_legacy
% Archived experiment 16: both 100ms cases with the new framework OFF.
here=fileparts(mfilename('fullpath'));root=fileparts(here);addpath(fullfile(root,'teaching'));
folder=fullfile(root,'teaching','experiments','runs','20261014_003504_216_speed_filter_dcfcd102');
pmsm_experiment_verify(folder);p=jsondecode(fileread(fullfile(folder,'plan.json')));
mdl='PMSM_FOC_R2026a';assert(~bdIsLoaded(mdl));load_system(fullfile(root,[mdl '.slx']));pmsm_reference('restore');before=teach_snapshot(mdl);
guard=onCleanup(@()restore(mdl));set_param([mdl '/时序设置'],'real_on','on');
pmsm_encoder_model('install');pmsm_encoder_speed_model('install');pmsm_speed_feedback_model('install');pmsm_speed_filter_model('install');
set_param([mdl '/角度设置/编码器'],'encoder_on','on');set_param([mdl '/速度反馈'],'feedback_on','on');pmsm_startup_model('install');
set_param([mdl '/启停'],'enabled','off');count=0;
for k=1:2
 in=Simulink.SimulationInput(mdl);in=in.setModelParameter('StopTime',num2str(p.duration_s,17));
 for c=p.cases(k).changes(:)',in=in.setBlockParameter([mdl '/' c.section],c.parameter,c.value);end
 cfgs={p.encoder_configurations(k),p.speed_configuration,p.feedback_configurations(k),p.filter_configurations(k)};
 paths={'角度设置/编码器','角度设置/编码器/测速','速度反馈','速度反馈/速度滤波'};
 for j=1:4,for key=fieldnames(cfgs{j})',in=in.setBlockParameter([mdl '/' paths{j}],key{1},cfgs{j}.(key{1}));end,end
 for c=p.logging_overrides(:)'
  logs=find_system(mdl,'LookUnderMasks','all','BlockType','ToWorkspace','VariableName',c.signal);assert(isscalar(logs));in=in.setBlockParameter(logs{1},c.parameter,c.value);
 end
 fprintf('STARTUP_LEGACY %s\n',p.cases(k).id);o=sim(in);x=load(fullfile(folder,[p.cases(k).id '.mat']),'signals');
 for name=fieldnames(x.signals)'
  a=x.signals.(name{1});b=o.get(name{1});assert(isequal(a.Time,b.Time)&&isequal(a.Data,b.Data),'Legacy mismatch: %s/%s',p.cases(k).id,name{1});count=count+1;
 end
end
clear guard;assert(isequaln(before,teach_snapshot(mdl)));
report=struct('passed',true,'legacy_folder',folder,'signal_count',count,'all_time_data_exact',true,'duration_each_s',p.duration_s,'structure_restored',true);
teach_writejson(fullfile(here,'legacy_validation.json'),report);close_system(mdl,0);fprintf('STARTUP_LEGACY_VALIDATED %d exact signals\n',count);
end
function restore(mdl)
if pmsm_startup_model('installed'),pmsm_startup_model('remove');end
if pmsm_encoder_model('installed'),pmsm_encoder_model('remove');end
pmsm_reference('restore');
end
