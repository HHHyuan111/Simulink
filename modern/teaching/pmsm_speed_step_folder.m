function folder=pmsm_speed_step_folder(folder)
here=fileparts(mfilename('fullpath'));
if nargin<1||isempty(folder)
 path=fullfile(here,'frequency','speed_loop','latest.json');assert(isfile(path),'请先运行repeat_pmsm_speed_step。');
 entry=jsondecode(fileread(path));folder=entry.folder;
 assert(strcmp(entry.record_sha256,teach_hash(fullfile(folder,'record.json'))),'实验档案已改变。');
end
assert(isfolder(folder),'实验目录不存在。');
end
