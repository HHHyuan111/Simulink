function result=pmsm_reference_geometry(action,folder,mdl)
% Fixed reference state, independent of the partial teaching presets.
% restore changes the loaded model only; it never saves the SLX or runs sim.
here=fullfile(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))),'teaching');root=fileparts(here);
if nargin<1,action='read';end
if nargin<2||isempty(folder),folder=fullfile(here,'reference_v1');end
if nargin<3,mdl='PMSM_FOC_R2026a';end
modelFile=fullfile(root,'PMSM_FOC_R2026a.slx');
switch action
 case 'verify'
  result=verify(folder,root,modelFile);return;
 case 'read'
  verify(folder,root,modelFile);result=jsondecode(fileread(fullfile(folder,'state.json')));return;
 case {'capture','restore','freeze'}
  if ~bdIsLoaded(mdl),load_system(modelFile);end
  assert(strcmp(get_param(mdl,'SimulationStatus'),'stopped'),'先停止仿真。');
  assert(strcmp(get_param(mdl,'FastRestart'),'off'),'先关闭Fast Restart再恢复或冻结参考。');
 otherwise,error('pmsm:ReferenceAction','未知参考操作。');
end
if strcmp(action,'capture'),result=capture(mdl);return;end
if strcmp(action,'freeze')
 assert(~isfolder(folder)&&~isfile(folder),'固定参考目录已经存在；请使用新的版本目录。');
 assert(strcmp(get_param(mdl,'Dirty'),'off'),'冻结参考前必须加载未编辑的主模型。');
 assert(strcmp(teach_hash(get_param(mdl,'FileName')),teach_hash(modelFile)),'只能从当前主模型的完整快照冻结。');
 set_param(mdl,'SimulationCommand','update');state=capture(mdl);
 for s=state.settings(:)',for q=s.parameters(:)',if endsWith(q.name,'_on'),assert(strcmp(q.value,'off'),'参考要求附加开关全部关闭。');end,end,end
 assert(strcmp(get_param([mdl '/解耦'],'enabled'),'on'),'本版参考固定启用dq解耦。');
 assert(strcmp(state.model_parameters.LoadInitialState,'off'),'本版参考不依赖外部初始状态文件。');
 assert(strcmp(state.model_parameters.LoadExternalInput,'off'),'本版参考不依赖外部输入文件。');
 mkdir(folder);teach_writejson(fullfile(folder,'state.json'),state);
 teach_writejson(fullfile(folder,'configuration.json'),state.configuration);
 teach_writejson(fullfile(folder,'switches.json'),pmsm_switch_catalog);
 manifest=struct('schema',1,'id','pmsm_reference_v1','created_at',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss Z')), ...
  'matlab_release',version('-release'),'matlab_version',version,'model','PMSM_FOC_R2026a.slx','model_sha256',teach_hash(modelFile), ...
  'scope','教学与算法研究的固定理想参考；未完成实板校准', ...
  'parameter_count',numel(state.configuration.rows),'switch_count',numel(pmsm_switch_catalog),'files',struct('path',{},'sha256',{}),'source_files',struct('path',{},'sha256',{}));
 for name={'state.json','configuration.json','switches.json'},manifest.files(end+1)=struct('path',name{1},'sha256',teach_hash(fullfile(folder,name{1})));end
 for dirName={'teaching','control','timing','deadtime'}
  files=dir(fullfile(root,dirName{1},'*.m'));[~,ix]=sort({files.name});files=files(ix);
  for f=files(:)',relative=[dirName{1} '/' f.name];manifest.source_files(end+1)=struct('path',relative,'sha256',teach_hash(fullfile(root,relative)));end
 end
 manifest.invariant_sha256=invariant(mdl,state);
 teach_writejson(fullfile(folder,'manifest.json'),manifest);result=verify(folder,root,modelFile);return;
end
manifest=verify(folder,root,modelFile);target=jsondecode(fileread(fullfile(folder,'state.json')));
assert(strcmp(teach_hash(get_param(mdl,'FileName')),teach_hash(modelFile)),'当前打开的模型文件不匹配参考来源。');
% Validate every target before changing any model values.
checkShape(mdl,target);
assert(strcmp(invariant(mdl,target),manifest.invariant_sha256),'未保存的连接、算法或布局已改变；参数恢复不能替代模型版本恢复。');
before=capture(mdl);dirty=get_param(mdl,'Dirty');
backupDir=fullfile(root,'.build','reference_backups');if ~isfolder(backupDir),mkdir(backupDir);end
backupFile=fullfile(backupDir,[char(datetime('now','Format','yyyyMMdd_HHmmss_SSS')) '.json']);teach_writejson(backupFile,before);
try
 applyState(mdl,target,false);
 result=capture(mdl);assert(isequaln(result,target),'恢复后状态与固定参考不一致。');
catch err
 try,applyState(mdl,before,false);set_param(mdl,'Dirty',dirty);catch rollbackErr,err=addCause(err,rollbackErr);end
 rethrow(err);
end
fprintf('REFERENCE_RESTORED (未保存SLX)；旧设置：%s\n',backupFile);
end

function s=capture(mdl)
mw=get_param(mdl,'ModelWorkspace');
assert(strcmp(mw.DataSource,'MATLAB Code'),'本版参考仅支持嵌入MATLAB Code工作区。');
s=struct('schema',1,'model',mdl,'workspace_code',mw.MATLABCode,'workspace_values',struct('name',{},'class',{},'size',{},'value',{}), ...
 'workspace_metadata',struct('name',{},'class',{},'value',{}),'model_parameters',struct,'settings',teach_settings(mdl),'configuration',pmsm_config('read',[],mdl),'block_parameters',struct('path',{},'parameter',{},'value',{}));
vars=whos(mw);[~,ix]=sort({vars.name});vars=vars(ix);
for v=vars(:)'
 x=getVariable(mw,v.name);
 if isnumeric(x)||islogical(x)
  assert(isreal(x)&&all(isfinite(x),'all'),'工作区包含不支持的非有限或复数状态。');
  s.workspace_values(end+1)=struct('name',v.name,'class',class(x),'size',size(x),'value',{x(:)'});
 else
  assert(isstruct(x)||ischar(x)||isstring(x),'不支持的工作区对象：%s',v.name);
  s.workspace_metadata(end+1)=struct('name',v.name,'class',class(x),'value',{x});
 end
end
keys={'StartTime','StopTime','SolverType','Solver','FixedStep','RelTol','AbsTol','LoadInitialState','InitialState', ...
 'LoadExternalInput','ExternalInput','SaveFinalState','SaveOperatingPoint','FinalStateName','SaveState','StateSaveName', ...
 'SaveTime','TimeSaveName','SaveOutput','OutputSaveName','SignalLogging','SignalLoggingName','ReturnWorkspaceOutputs','SimulationMode'};
% Some supported configuration aliases (notably Solver) are absent from
% ObjectParameters; query the configuration directly rather than filtering it.
for key=keys
 try,s.model_parameters.(key{1})=get_param(mdl,key{1});catch err
  error('pmsm:ReferenceConfig','无法记录必要仿真设置%s：%s',key{1},err.message);
 end
end
paths=sort(find_system(mdl,'LookUnderMasks','all','FollowLinks','off','Type','Block'));
for k=1:numel(paths)
 b=paths{k};p=get_param(b,'DialogParameters');if isempty(p),continue;end
 names=sort(fieldnames(p));keep=names(startsWith(names,'Initial')|strcmp(names,'X0'));
 if ismember(get_param(b,'BlockType'),{'Constant','Step','RandomNumber','BandLimitedWhiteNoise','ChirpSignal','ToWorkspace'}),keep=names;end
 if strcmp(b,[mdl '/解耦']),keep=unique([keep;{'enabled'}]);end
 for j=1:numel(keep),s.block_parameters(end+1)=struct('path',b,'parameter',keep{j},'value',get_param(b,keep{j}));end
end
% Use JSON's canonical array orientation both before and after persistence.
s=jsondecode(jsonencode(s));
end

function checkShape(mdl,s)
assert(s.schema==1&&strcmp(s.model,mdl),'参考模型或档案版本不匹配。');
current=capture(mdl);
assert(isequal({current.workspace_values.name},{s.workspace_values.name}),'工作区结构已改变。');
assert(isequal({current.block_parameters.path},{s.block_parameters.path})&&isequal({current.block_parameters.parameter},{s.block_parameters.parameter}),'块或初值结构已改变。');
assert(isequal({current.settings.block},{s.settings.block}),'开关分区结构已改变。');
for k=1:numel(s.settings),assert(isequal({current.settings(k).parameters.name},{s.settings(k).parameters.name}),'开关参数结构已改变。');end
end

function applyState(mdl,s,update)
mw=get_param(mdl,'ModelWorkspace');clear(mw);mw.MATLABCode=s.workspace_code;reload(mw);
for v=s.workspace_values(:)',assignin(mw,v.name,cast(reshape(v.value,v.size(:)'),v.class));end
for v=s.workspace_metadata(:)'
 x=v.value;if strcmp(v.class,'string'),x=string(x);elseif strcmp(v.class,'char'),x=char(x);end
 assignin(mw,v.name,x);
end
for section=s.settings(:)',for p=section.parameters(:)',set_param([mdl '/' section.block],p.name,p.value);end,end
for p=s.block_parameters(:)',if ~isequaln(get_param(p.path,p.parameter),p.value),set_param(p.path,p.parameter,p.value);end,end
keys=fieldnames(s.model_parameters);
% Solver type must be restored before its dependent solver and step settings.
keys=[{'SolverType';'Solver'};setdiff(keys,{'SolverType','Solver'},'stable')];
for k=1:numel(keys),key=keys{k};if ~isequaln(get_param(mdl,key),s.model_parameters.(key)),set_param(mdl,key,s.model_parameters.(key));end,end
if update,set_param(mdl,'SimulationCommand','update');end
end

function h=invariant(mdl,state)
% Reject edits outside the declared experiment settings before restoring them.
s=teach_snapshot(mdl);s.config=struct;
for k=1:numel(s.blocks)
 b=s.blocks(k);ix=strcmp({state.block_parameters.path},b.path);allowed={state.block_parameters(ix).parameter};
 si=find(strcmp({state.settings.block},erase(b.path,[mdl '/'])));
 if isscalar(si),allowed=[allowed {state.settings(si).parameters.name}];end
 for key=allowed,if isfield(b.params,key{1}),b.params=rmfield(b.params,key{1});end,end
 if any(ismember(b.mask.MaskNames,allowed)),b.mask.MaskValues={};end
 s.blocks(k)=b;
end
md=java.security.MessageDigest.getInstance('SHA-256');md.update(unicode2native(jsonencode(s),'UTF-8'));
h=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
end

function m=verify(folder,root,modelFile)
assert(isfile(fullfile(folder,'manifest.json')),'尚无固定参考；先完成参考冻结。');
m=jsondecode(fileread(fullfile(folder,'manifest.json')));
assert(m.schema==1&&strcmp(m.matlab_release,version('-release')),'参考版本或MATLAB发行版不匹配。');
assert(strcmp(m.model_sha256,teach_hash(modelFile)),'主模型文件与参考版本不同；请建立新基线，不要混用。');
for f=m.files(:)',assert(strcmp(teach_hash(fullfile(folder,f.path)),f.sha256),'固定参考文件被修改：%s',f.path);end
for f=m.source_files(:)',assert(strcmp(teach_hash(fullfile(root,f.path)),f.sha256),'脚本版本已改变：%s；需重新验证并建立新基线。',f.path);end
end
