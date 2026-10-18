function report=probe_sensorless_r2_accelerated_reference_logging(folder)
% Code generation is restricted to the copied diagnostic child model.
here=fileparts(mfilename('fullpath'));base=fileparts(fileparts(here));modern=fileparts(base);addpath(fullfile(modern,'teaching'));
assert(~isfolder(folder));mkdir(folder);parent='r2_single_log_parent';child='r2_single_log_child';cleanup=onCleanup(@()close_private(parent,child));
origin=fullfile(base,'runs/N3R2_single_reference_logging_once');old=jsondecode(fileread(fullfile(origin,'report.json')));assert(old.all_passed);
report=struct('kind','accelerated_reference_logging','phase','copy','all_passed',false,'process_id',matlabProcessID,...
 'matlab_version',version,'normal_parent_starts',0,'child_target_builds',0,'R2_passed',false,'main_model_loaded',false);
source=[mfilename('fullpath') '.m'];copyfile(source,fullfile(folder,'probe_source.m.txt'));report.probe_sha256=teach_hash(source);
contract=fullfile(base,'contracts/nonideal_r2_accelerated_reference_logging_probe.json');copyfile(contract,fullfile(folder,'contract.json'));report.contract_sha256=teach_hash(contract);
try
 assert(~bdIsLoaded(parent)&&~bdIsLoaded(child));
 parentSource=fullfile(origin,[parent '.slx']);childSource=fullfile(origin,[child '.slx']);
 assert(strcmp(teach_hash(parentSource),old.parent_file_sha256)&&strcmp(teach_hash(childSource),old.child_file_sha256));
 parentFile=fullfile(folder,[parent '.slx']);childFile=fullfile(folder,[child '.slx']);copyfile(parentSource,parentFile);copyfile(childSource,childFile);addpath(folder);
 load_system(childFile);load_system(parentFile);assert(strcmp(get_param([parent '/Observer'],'SimulationMode'),'Normal'));
 set_param([parent '/Observer'],'SimulationMode','Accelerator');save_system(parent,parentFile);
 report.parent_adapted_sha256=teach_hash(parentFile);report.child_unchanged_sha256=teach_hash(childFile);assert(strcmp(report.child_unchanged_sha256,old.child_file_sha256));
 refs=find_system(parent,'BlockType','ModelReference','ModelName',child);assert(numel(refs)==1&&strcmp(get_param(child,'ModelReferenceNumInstancesAllowed'),'Single'));
 report.actual_references=1;report.allowed_references='Single';report.child_mode=get_param(refs{1},'SimulationMode');
 generation=fullfile(base,'.build','accelerated_reference_logging',char(java.util.UUID.randomUUID));
 Simulink.fileGenControl('set','CacheFolder',fullfile(generation,'c'),'CodeGenFolder',fullfile(generation,'g'),'createDir',true);
 report.child_target_builds=1;stage('build_child_sim_target_once');slbuild(child,'ModelReferenceSimTarget');
 files=dir(fullfile(generation,'**','*.mexw64'));assert(~isempty(files));entries=struct('file',{},'sha256',{});
 for k=1:numel(files),p=fullfile(files(k).folder,files(k).name);entries(end+1)=struct('file',p,'sha256',teach_hash(p));end %#ok<AGROW>
 report.generated_targets=entries;
 report.normal_parent_starts=1;stage('normal_parent_accelerated_child_once');out=sim(parent,'SimulationMode','normal');
 save(fullfile(folder,'signals.mat'),'out','-v7.3');report.raw_sha256=teach_hash(fullfile(folder,'signals.mat'));assert(isempty(out.ErrorMessage));
 assert(strcmp(teach_hash(fullfile(origin,'normal_raw.mat')),old.normal_raw_sha256));loaded=load(fullfile(origin,'normal_raw.mat'),'normal');expected=loaded.normal;
 names=sort(out.who);other=sort(expected.who);assert(isequal(names,other)&&numel(names)==3);rows=struct;
 for k=1:numel(names)
  name=names{k};a=expected.get(name);b=out.get(name);assert(isa(a,'timeseries')&&isa(b,'timeseries'));
  rows.(name)=struct('Time_equal',isequal(a.Time,b.Time),'Data_equal',isequal(a.Data,b.Data),...
   'class_equal',strcmp(class(a.Data),class(b.Data)),'dimensions_equal',isequal(size(a.Data),size(b.Data)),...
   'finite',all(isfinite([a.Time(:);a.Data(:);b.Time(:);b.Data(:)])));
 end
 report.comparison=rows;native=out.get('child_native');jeos=out.get('child_jeos');
 report.native_rows=numel(native.Time);report.JEOS_rows=numel(jeos.Time);report.native_and_JEOS_ticks=isequal(round(native.Time/62.5e-9),(0:320000)')&&isequal(round(jeos.Time/62.5e-9),(462:800:320000)');
 report.source_files_unchanged=strcmp(teach_hash(parentSource),old.parent_file_sha256)&&strcmp(teach_hash(childSource),old.child_file_sha256);
 report.owned_files_unchanged_by_execution=strcmp(teach_hash(parentFile),report.parent_adapted_sha256)&&strcmp(teach_hash(childFile),old.child_file_sha256);
 report.all_passed=all(structfun(@(x)all(structfun(@(v)v,x)),rows))&&report.native_and_JEOS_ticks&&report.source_files_unchanged&&report.owned_files_unchanged_by_execution;
 assert(report.all_passed);stage('completed');
catch err
 report.phase_at_error=report.phase;report.phase='failed';report.error_identifier=err.identifier;teach_writejson(fullfile(folder,'report.json'),report);rethrow(err);
end
 function stage(label),report.phase=label;teach_writejson(fullfile(folder,'report.json'),report);fprintf('ACCELERATED_REFERENCE_LOGGING %s\n',label);end
end
function close_private(parent,child)
if bdIsLoaded(parent),close_system(parent,0);end
if bdIsLoaded(child),close_system(child,0);end
end
