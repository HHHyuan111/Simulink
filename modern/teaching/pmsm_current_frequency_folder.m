function folder=pmsm_current_frequency_folder(folder)
% Resolve only a completed local archive; never substitute current workspace out.
here=fileparts(mfilename('fullpath'));
if nargin<1||isempty(folder)
 latest=fullfile(here,'frequency','current_loop','latest.json');
 assert(isfile(latest),'请先运行repeat_pmsm_current_frequency生成固定参考频响实验。');
 entry=jsondecode(fileread(latest));folder=entry.folder;
 if ~isfolder(folder),[~,name]=fileparts(folder);folder=fullfile(here,'frequency','current_loop','runs',name);end
 assert(strcmp(entry.record_sha256,teach_hash(fullfile(folder,'record.json'))),'最新频响档案已改变。');
end
assert(isfolder(folder),'频响档案目录不存在。');
end
