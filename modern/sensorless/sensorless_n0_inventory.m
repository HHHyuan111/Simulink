function sensorless_n0_inventory
% N0 only: inspect and run the existing model; no observer is installed.
here=fileparts(mfilename('fullpath'));root=fileparts(here);mdl='PMSM_FOC_R2026a';
assert(~bdIsLoaded(mdl),'请在独立MATLAB进程执行N0，避免覆盖已有会话。');
for section={'','teaching','control','timing','deadtime','hardware','framework','startup','signal_chain','layout/appearance'}
 addpath(fullfile(root,section{1}));
end
work=fullfile(here,'.build');if ~isfolder(work),mkdir(work);end
Simulink.fileGenControl('set','CacheFolder',fullfile(work,'cache'),'CodeGenFolder',fullfile(work,'codegen'),'createDir',true);
folder=fullfile(here,'runs','N0_baseline');if ~isfolder(folder),mkdir(folder);end
inventory=struct('schema',1,'node','N0','status','running','matlab_version',version,...
 'release',version('-release'),'computer',computer,'duration_s',.1,'observer_installed',false);
teach_writejson(fullfile(here,'baseline','n0_inventory.json'),inventory);
modelFile=fullfile(root,[mdl '.slx']);beforeHash=teach_hash(modelFile);
cleanup=onCleanup(@()close_system(mdl,0));
try
 inventory.reference=pmsm_reference('verify');
 load_system(modelFile);pmsm_reference('restore');
 state=pmsm_reference('capture');beforeSnapshot=teach_snapshot(mdl);
 teach_writejson(fullfile(here,'baseline','reference_state.json'),state);
 inventory.loaded_file=get_param(mdl,'FileName');
 assert(strcmpi(strrep(inventory.loaded_file,'\','/'),strrep(modelFile,'\','/')),'加载的不是dev工作树模型。');
 inventory.solver=state.model_parameters;
 ws=get_param(mdl,'ModelWorkspace');keys={'Rs','Ld','Lq','p','phis','Vdc','dt','Ts','Ts_speed','Iq_limit','timing_on','timing_h'};
 for j=1:numel(keys),inventory.motor_and_tasks.(keys{j})=getVariable(ws,keys{j});end
 inventory.pi_gains=struct;
 for key={'kp_w','ki_w','ks_w','kp_id','ki_id','ks_id','kp_iq','ki_iq','ks_iq'}
  inventory.pi_gains.(key{1})=getVariable(ws,key{1});
 end
 assert(inventory.motor_and_tasks.dt==50e-6&&inventory.motor_and_tasks.Ts_speed==100e-6);
 assert(inventory.motor_and_tasks.Ld==inventory.motor_and_tasks.Lq);
 set_param(mdl,'SimulationCommand','update');
 feval(mdl,[],[],[],'compile');
 paths=sort(find_system(mdl,'LookUnderMasks','all','FollowLinks','off','Type','Block'));
 rates=struct('path',{},'sid',{},'type',{},'sample_time',{});
 for j=1:numel(paths)
  rates(end+1)=struct('path',paths{j},'sid',Simulink.ID.getSID(paths{j}),...
   'type',get_param(paths{j},'BlockType'),'sample_time',{get_param(paths{j},'CompiledSampleTime')}); %#ok<AGROW>
 end
 feval(mdl,[],[],[],'term');
 teach_writejson(fullfile(here,'baseline','compiled_rates.json'),rates);
 tags=struct('path',{},'type',{},'tag',{});
 for j=1:numel(paths)
  type=get_param(paths{j},'BlockType');
  if ismember(type,{'Goto','From'})
   tags(end+1)=struct('path',paths{j},'type',type,'tag',get_param(paths{j},'GotoTag')); %#ok<AGROW>
  end
 end
 teach_writejson(fullfile(here,'baseline','signal_tags.json'),tags);
 in=Simulink.SimulationInput(mdl);in=in.setModelParameter('StopTime','.1');
 fprintf('N0_BASELINE_SIMULATION_BEGIN duration=.1s observer=absent\n');
 o=sim(in);signals=struct;schema=struct('name',{},'class',{},'shape',{},'samples',{},'time_start_s',{},'time_end_s',{},'max_step_s',{},'min_step_s',{});
 for name=o.who'
  x=o.get(name{1});if ~isa(x,'timeseries'),continue;end
  assert(all(isfinite(x.Data),'all')&&all(isfinite(x.Time),'all'),'基线含非有限数据：%s',name{1});
  assert(all(diff(x.Time)>=0),'基线时间逆序：%s',name{1});
  signals.(name{1})=x;step=diff(x.Time);
  schema(end+1)=struct('name',name{1},'class',class(x.Data),'shape',size(x.Data),...
   'samples',numel(x.Time),'time_start_s',x.Time(1),'time_end_s',x.Time(end),'max_step_s',max(step),'min_step_s',min(step)); %#ok<AGROW>
 end
 assert(~isempty(schema),'未发现timeseries基线日志。');
 teach_writejson(fullfile(here,'baseline','log_schema.json'),schema);
 save(fullfile(folder,'signals.mat'),'signals','-v7.3');
 inventory.raw_data_sha256=teach_hash(fullfile(folder,'signals.mat'));
 inventory.raw_data_relative='runs/N0_baseline/signals.mat';inventory.log_count=numel(schema);
 inventory.block_count=numel(paths);inventory.compiled_rate_count=numel(rates);
 inventory.reference_state_restored=isequaln(state,pmsm_reference('capture'));
 inventory.structure_unchanged=isequaln(beforeSnapshot,teach_snapshot(mdl));
 inventory.model_sha256_before=beforeHash;inventory.model_sha256_after=teach_hash(modelFile);
 assert(inventory.reference_state_restored&&inventory.structure_unchanged&&strcmp(beforeHash,inventory.model_sha256_after));
 inventory.status='passed';inventory.scope='100ms既有参考运行与接口盘点；不代表SMO/PLL实现或性能验收';
 teach_writejson(fullfile(here,'baseline','n0_inventory.json'),inventory);
 fprintf('N0_BASELINE_PASSED logs=%d blocks=%d\n',inventory.log_count,inventory.block_count);
catch err
 try,feval(mdl,[],[],[],'term');catch,end
 inventory.status='failed';inventory.error=err.message;
 teach_writejson(fullfile(here,'baseline','n0_inventory.json'),inventory);rethrow(err);
end
end
