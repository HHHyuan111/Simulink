function r=check_low_deadtime_reference
% The demo cache is mutable: reject a different operating point or stale MAT.
folder=fileparts(mfilename('fullpath'));root=fileparts(folder);addpath(fullfile(root,'teaching'));
record=jsondecode(fileread(fullfile(folder,'report_demo','record.json')));
assert(record.dead_us==2&&record.rpm==300&&record.load_Nm==.08&&record.stop_time_s==.14, ...
 '请先生成参考：run_deadtime_demo(2,300,.08,.14,struct(''comp_us'',2,''hysteresis_A'',.05))');
if isfield(record,'used_options'),assert(record.used_options.comp_us==2&&record.used_options.hysteresis_A==.05);else,assert(record.workspace.dead_comp_cfg(4)==.05);end
r=struct('dead_us',2,'comp_us',2,'hysteresis_A',.05,'rpm',300,'load_Nm',.08,'stop_time_s',.14,'historical_model_sha256',record.model_sha256);
for key={'dead','comp'}
 file=fullfile(root,'.build','deadtime_demo',[key{1} '.mat']);s=load(file,'o');a=deadtime_metrics(s.o);
 assert(abs(a.low_order_THD_percent-record.cases.(key{1}).low_order_THD_percent)<1e-9,'参考MAT与record.json不匹配');r.([key{1} '_mat_sha256'])=teach_hash(file);
end
end
