function config=pmsm_config(action,payload,mdl)
% Read/preset/apply a complete parameter profile. Apply is transactional.
if nargin<1,action='read';end
if nargin<2,payload=[];end
if nargin<3,mdl='PMSM_FOC_R2026a';end
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);
if ~bdIsLoaded(mdl),load_system(fullfile(root,[mdl '.slx']));end
assert(strcmp(get_param(mdl,'SimulationStatus'),'stopped'),'先停止仿真。');
config=readConfig(mdl);
switch action
 case 'read',return;
 case 'preset'
  assert(ismember(payload,{'reference','teaching','board'}));
  for k=1:numel(config.rows)
   r=config.rows(k);
   if endsWith(r.key,'_on'),config.rows(k).value='off';end
  end
  if ~strcmp(payload,'reference')
   config=setValue(config,'时序设置','real_on','on');config=setValue(config,'功率设置','gate_on','on');
   config=setValue(config,'功率设置','gate_us','0.5');config=setValue(config,'功率设置','comp_us','0.5');
  end
  if strcmp(payload,'teaching')
   config=setValue(config,'功率设置','gate_us','2');config=setValue(config,'功率设置','comp_us','2');
  end
  config.role=payload;
  for k=1:numel(config.rows)
   if strcmp(config.rows(k).section,'功率设置')&&ismember(config.rows(k).key,{'gate_us','comp_us'})
    config.rows(k).source=['预设 ' payload '；非实测'];config.rows(k).status='未实测';
   end
  end
  return;
 case 'apply'
  assert(isstruct(payload)&&payload.schema==1&&numel(payload.rows)==numel(config.rows));
 otherwise,error('Unknown action.');
end
pmsm_check_switches(payload);
mw=get_param(mdl,'ModelWorkspace');oldCode=mw.MATLABCode;oldDirty=get_param(mdl,'Dirty');oldValues=struct;
rawSettings=teach_settings(mdl);rawLoad=cellfun(@(key)get_param([mdl '/T_load1'],key),{'Before','After','Time'},'UniformOutput',false);
for v=whos(mw)',oldValues.(v.name)=getVariable(mw,v.name);end
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));backup=fullfile(root,'.build','parameter_backups');if ~isfolder(backup),mkdir(backup);end
save(fullfile(backup,[stamp '.mat']),'config','oldCode','oldValues','rawSettings','rawLoad');
numeric=struct;
% Check every key/type before mutating anything; numeric text is never eval'ed.
for k=1:numel(config.rows)
 a=config.rows(k);b=payload.rows(k);assert(strcmp(a.section,b.section)&&strcmp(a.key,b.key),'档案结构不匹配。');
 if strcmp(a.kind,'number')
  value=parseNumber(b.value);assert(isequal(size(value),size(parseNumber(a.value))),'数值维数不匹配。');
  payload.rows(k).value=mat2str(value,17);
  if ~ismember(a.key,{'bias_A','bias_deg','n','Before','After'}),assert(all(value>=0),'参数不能为负。');end
  if ismember(a.key,{'phase_gain','filter_hz','analog_hz'}),assert(all(value>0));end
  if strcmp(a.key,'adc_bits'),assert(isscalar(value)&&value==round(value)&&value>=1&&value<=24);end
  if strcmp(a.key,'adc_span'),assert(value>0);end
  if ismember(a.key,{'speed_divider','pwm_cycles','delay_cycles','noise_seed','grid_divider'}),assert(all(value==round(value)));end
  if strcmp(a.section,'电机与工况'),numeric.(a.key)=value;end
 elseif strcmp(a.kind,'switch'),assert(ismember(b.value,{'on','off'}),'开关只能填写on/off。');
 elseif strcmp(a.kind,'enum'),assert(ismember(b.value,{'峰谷双更新（RCR=0）','仅谷底（对照）'}));
 end
end
for key={'Rs','Ld','Lq','phis','p','J','Vdc','Iq_limit','fc','Ts_speed'},assert(numeric.(key{1})>0,'参数必须为正。');end
assert(numeric.F>=0&&numeric.p==round(numeric.p));
try
 for k=1:numel(payload.rows)
  r=payload.rows(k);if strcmp(r.section,'电机与工况')||strcmp(r.value,config.rows(k).value),continue;end
  if strcmp(r.section,'负载'),set_param([mdl '/T_load1'],r.key,r.value);
  else,set_param([mdl '/' r.section],r.key,r.value);end
 end
 if any(cellfun(@(key)~isequaln(numeric.(key),oldValues.(key)),fieldnames(numeric)))
  base=oldCode;pos=strfind(base,'%__PARAMETER_PROVENANCE__');if ~isempty(pos),base=base(1:pos(1)-1);end
  marker='%__USER_PARAMETER_OVERRIDES__';pos=strfind(base,marker);if ~isempty(pos),base=base(1:pos(1)-1);end
  code=[base newline marker newline];
  for key=fieldnames(numeric)',code=[code sprintf('%s=%s;\n',key{1},mat2str(numeric.(key{1}),17))];end %#ok<AGROW>
  code=[code sprintf(['Ls=Ld; Kt=1.5*p*phis; Ts=1/fc; dt=Ts; teaching_Ts_speed=Ts_speed;\n' ...
   'fN=p*n/60; wN=2*pi*fN; uplimit_w=Kt*Iq_limit; downlimit_w=-uplimit_w;\n' ...
   'uplimit_id=Vdc/sqrt(3); downlimit_id=-uplimit_id; uplimit_iq=uplimit_id; downlimit_iq=-uplimit_iq;\n'])];
  mw.MATLABCode=code;reload(mw);
 end
 set_param(mdl,'SimulationCommand','update');
catch err
 mw.MATLABCode=oldCode;reload(mw);for key=fieldnames(oldValues)',assignin(mw,key{1},oldValues.(key{1}));end
 for s=rawSettings,for q=s.parameters,set_param([mdl '/' s.block],q.name,q.value);end,end
 keys={'Before','After','Time'};for k=1:3,set_param([mdl '/T_load1'],keys{k},rawLoad{k});end
 set_param(mdl,'Dirty',oldDirty);rethrow(err);
end
marker='%__PARAMETER_PROVENANCE__';code=mw.MATLABCode;pos=strfind(code,marker);if ~isempty(pos),code=code(1:pos(1)-1);end
encoded=strrep(jsonencode(payload),'''','''''');mw.MATLABCode=[code newline marker newline 'ParameterCalibration=jsondecode(''' encoded ''');' newline];
reload(mw);config=readConfig(mdl);
end
function c=readConfig(mdl)
c=struct('schema',1,'role','custom','rows',struct('section',{},'key',{},'label',{},'kind',{},'unit',{},'value',{},'source',{},'status',{},'measurement',{}));
ignore={'control_period','numerical_step','real_mode','pwm_period'};
for s=teach_settings(mdl)
 mask=Simulink.Mask.get([mdl '/' s.block]);
 for q=s.parameters
  if ismember(q.name,ignore),continue;end
  p=mask.getParameter(q.name);kind='number';if endsWith(q.name,'_on'),kind='switch';elseif strcmp(q.name,'update_mode'),kind='enum';end
  c=addRow(c,s.block,q.name,p.Prompt,kind,q.value);
 end
end
mw=get_param(mdl,'ModelWorkspace');
for key={'Vdc','n','fc','Ts_speed','Rs','Ld','Lq','phis','p','J','F','Iq_limit'},c=addRow(c,'电机与工况',key{1},key{1},'number',mat2str(getVariable(mw,key{1}),17));end
for key={'Before','After','Time'},c=addRow(c,'负载',key{1},key{1},'number',get_param([mdl '/T_load1'],key{1}));end
stored=[];if hasVariable(mw,'ParameterCalibration'),stored=getVariable(mw,'ParameterCalibration');end
if isstruct(stored)&&isfield(stored,'schema')&&stored.schema==1
 c.role=stored.role;
 for k=1:numel(c.rows)
  ix=find(strcmp({stored.rows.section},c.rows(k).section)&strcmp({stored.rows.key},c.rows(k).key));
  if isscalar(ix)&&strcmp(stored.rows(ix).value,c.rows(k).value),c.rows(k).source=stored.rows(ix).source;c.rows(k).status=stored.rows(ix).status;end
 end
end
end
function c=addRow(c,section,key,label,kind,value)
[unit,source,measure]=pmsm_parameter_info(section,key);
% Clarify the editor without modifying legacy mask labels or the SLX.
if strcmp(section,'采样设置')&&strcmp(key,'adc_span'),label='电流全跨度 [A]';end
if strcmp(section,'时序设置')&&strcmp(key,'grid_divider'),label='事件网格细分（数值设置）';end
% Step blocks originally contain workspace expressions. Resolve the known defaults.
if strcmp(section,'负载')
 value=num2str(slResolve(value,[bdroot '/T_load1']),17);
end
if strcmp(kind,'number'),value=mat2str(parseNumber(value),17);end
c.rows(end+1)=struct('section',section,'key',key,'label',label,'kind',kind,'unit',unit,'value',value,'source',source,'status','未实测','measurement',measure);
end
function c=setValue(c,section,key,value)
ix=find(strcmp({c.rows.section},section)&strcmp({c.rows.key},key));assert(isscalar(ix));c.rows(ix).value=value;
end
function x=parseNumber(value)
assert(ischar(value)||isstring(value));s=char(value);assert(~isempty(regexp(s,'^\s*\[?\s*[-+0-9.eE,;\s]+\]?\s*$','once')),'请填写有限数值或一行向量，不填写表达式。');
s=regexprep(s,'[\[\],;]',' ');tokens=regexp(strtrim(s),'\s+','split');x=str2double(tokens);assert(~isempty(x)&&all(isfinite(x)));
end
