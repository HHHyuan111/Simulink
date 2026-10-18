function report=probe_sensorless_r2_workspace_persistence(folder)
% Saved-model handoff controls; no original main or simulation involved.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));addpath(fullfile(fileparts(base),'teaching'));
assert(~isfolder(folder));mkdir(folder);names={'slr2_ws_code','slr2_ws_file'};cleanup=onCleanup(@()close_private(names));
for k=1:2,assert(~bdIsLoaded(names{k}));end
report=struct('kind','saved_workspace_roundtrip','phase','prepare','all_passed',false,...
 'process_id',matlabProcessID,'matlab_version',version,'simulation_starts',0,'compile_requested',false,'original_model_loaded',false);
copyfile([mfilename('fullpath') '.m'],fullfile(folder,'probe_source.m.txt'));report.probe_sha256=teach_hash([mfilename('fullpath') '.m']);
contract=fullfile(base,'contracts/nonideal_r2_workspace_persistence_probe.json');copyfile(contract,fullfile(folder,'contract.json'));report.contract_sha256=teach_hash(contract);
frozenFile=fullfile(base,'milestones/N3R2/final_candidate.json');frozen=jsondecode(fileread(frozenFile));report.frozen_candidate_sha256=teach_hash(frozenFile);
wanted=struct('base',2,'observer',reshape(frozen.nominal_observer_config,[],1),'frontend',reshape(frozen.nominal_frontend_config,1,[]));
backup=struct('version',1,'callback','owned-source-placeholder','external_blocks',{{'owned/tap'}},'config',wanted.frontend);
save(fullfile(folder,'expected.mat'),'wanted','backup','-v7.3');report.expected_sha256=teach_hash(fullfile(folder,'expected.mat'));
try
 for k=1:2
  mdl=names{k};report.fixture=k;stage('create');new_system(mdl);ws=get_param(mdl,'ModelWorkspace');
  block=[mdl '/Backup'];add_block('built-in/SubSystem',block);assert(strcmp(get_param(block,'UserDataPersistent'),'off'));
  if k==1,ws.DataSource='MATLAB Code';ws.MATLABCode='base=1;';reload(ws);else,ws.DataSource='Model File';set_param(block,'UserDataPersistent','on');end
  assignin(ws,'base',wanted.base);assignin(ws,'observer_cfg',wanted.observer);assignin(ws,'frontend_cfg',wanted.frontend);set_param(block,'UserData',backup);
  before=values(ws);file=fullfile(folder,[mdl '.slx']);stage('save');save_system(mdl,file);digest=teach_hash(file);close_system(mdl,0);
  stage('reopen');load_system(file);ws=get_param(mdl,'ModelWorkspace');after=values(ws);actualBackup=get_param(block,'UserData');
  item=struct('file',file,'file_sha256',digest,'data_source',ws.DataSource,'before',{before},'after',{after},'backup',actualBackup,...
   'saved_file_unchanged',strcmp(teach_hash(file),digest),'backup_equal',isequaln(backup,actualBackup));
  if k==1
   item.code_base_reset=getVariable(ws,'base')==1;item.runtime_configs_absent=~hasVariable(ws,'observer_cfg')&&~hasVariable(ws,'frontend_cfg');item.transient_backup_absent=isempty(actualBackup);
   item.expected_loss_observed=item.code_base_reset&&item.runtime_configs_absent&&item.transient_backup_absent;report.negative_control=item;
  else
   item.values_classes_dimensions_equal=isequaln(getVariable(ws,'base'),wanted.base)&&isequaln(getVariable(ws,'observer_cfg'),wanted.observer)&&isequaln(getVariable(ws,'frontend_cfg'),wanted.frontend);
   item.complete_roundtrip=item.values_classes_dimensions_equal&&item.backup_equal&&item.saved_file_unchanged;report.positive_control=item;
  end
  close_system(mdl,0);stage('fixture_completed');
 end
 report.all_passed=report.negative_control.expected_loss_observed&&report.positive_control.complete_roundtrip;stage('completed');
catch err
 report.phase_at_error=report.phase;report.phase='failed';report.error_identifier=err.identifier;teach_writejson(fullfile(folder,'report.json'),report);rethrow(err);
end
 function stage(label),report.phase=label;teach_writejson(fullfile(folder,'report.json'),report);fprintf('WORKSPACE_ROUNDTRIP %d %s\n',report.fixture,label);end
end
function result=values(ws)
entries=whos(ws);names=sort({entries.name});result=repmat(struct('name','','value',[],'class','','size',[]),numel(names),1);
for k=1:numel(names),x=getVariable(ws,names{k});result(k)=struct('name',names{k},'value',x,'class',class(x),'size',size(x));end
end
function close_private(names)
for k=1:numel(names),if bdIsLoaded(names{k}),close_system(names{k},0);end,end
end
