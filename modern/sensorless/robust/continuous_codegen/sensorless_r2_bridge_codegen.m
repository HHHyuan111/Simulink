function result=sensorless_r2_bridge_codegen(action,mdl,backup)
% Owned-copy-only activation adapter for the original stateless bridge.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);
file=char(java.io.File(get_param(mdl,'FileName')).getCanonicalPath);
owned=char(java.io.File(fullfile(base,'runs')).getCanonicalPath);
assert(startsWith(lower(file),[lower(owned) filesep]),'R2:NotOwnedModel','Bridge adapter requires an owned run copy.');
rt=sfroot;c=rt.find('-isa','Stateflow.EMChart','Path',[mdl '/Universal Bridge/续流']);assert(isscalar(c));
kernel=fileread(fullfile(modern,'deadtime','bridge_freewheel.m'));
assert(strcmp(strrep(c.Script,sprintf('\r\n'),sprintf('\n')),strrep(kernel,sprintf('\r\n'),sprintf('\n'))));
assert(~contains(kernel,'persistent')&&~contains(kernel,'global'));
switch action
 case 'apply'
  assert(strcmp(c.ChartUpdate,'CONTINUOUS'));
  result=struct('path',c.Path,'original_update',c.ChartUpdate,'original_sample_time',c.SampleTime,'original_script',c.Script,...
   'kernel_sha256',teach_hash(fullfile(modern,'deadtime','bridge_freewheel.m')));
  c.ChartUpdate='INHERITED';result.adapted_update=c.ChartUpdate;result.adapted_sample_time=c.SampleTime;
  assert(strcmp(c.Script,result.original_script));
 case 'verify'
  result=strcmp(c.ChartUpdate,backup.adapted_update)&&strcmp(c.SampleTime,backup.adapted_sample_time)&&strcmp(c.Script,backup.original_script);
 case 'restore'
  assert(strcmp(c.ChartUpdate,backup.adapted_update)&&strcmp(c.Script,backup.original_script));
  c.ChartUpdate=backup.original_update;
  if ~strcmp(c.SampleTime,backup.original_sample_time),c.SampleTime=backup.original_sample_time;end
  result=strcmp(c.ChartUpdate,backup.original_update)&&strcmp(c.SampleTime,backup.original_sample_time)&&strcmp(c.Script,backup.original_script);
 otherwise
  error('R2:UnknownBridgeAction','Unknown bridge adaptation action.');
end
end
