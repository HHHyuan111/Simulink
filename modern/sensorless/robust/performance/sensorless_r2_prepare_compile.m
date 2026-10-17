function [backup,record]=sensorless_r2_prepare_compile(mdl,folder)
% Move idempotent diagram writes out of compilation. Numerical InitFcn code
% and original SLX stay unchanged; restore the exact original callback.
assert(strcmp(get_param(mdl,'SimulationStatus'),'stopped'));
backup=struct('init',get_param(mdl,'InitFcn'),'fixedstep',get_param(mdl,'FixedStep'));
commands={"set_param(tim_m,'FixedStep','timing_h');","set_param(dead_m,'FixedStep','timing_h');"};
safe=backup.init;
for k=1:numel(commands)
 assert(count(string(safe),commands{k})==1,'sensorless:R2Initialization','Unexpected original callback; do not rewrite unknown code.');
 safe=strrep(safe,char(commands{k}),'');
end
set_param(mdl,'FixedStep','timing_h','InitFcn',safe);
write_text(fullfile(folder,'original_init.m'),backup.init);write_text(fullfile(folder,'safe_init.m'),safe);
record=struct('kind','move_only_two_idempotent_fixedstep_writes_outside_compile','removed_writes',2,...
 'original_sha256',teach_hash(fullfile(folder,'original_init.m')),'compile_callback_sha256',teach_hash(fullfile(folder,'safe_init.m')),...
 'numerical_initialization_code_unchanged',true,'root_cause_confirmed',false);
end
function write_text(path,value)
fid=fopen(path,'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));fprintf(fid,'%s',value);
end
